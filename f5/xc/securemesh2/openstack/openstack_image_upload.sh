#!/bin/bash

Logger() {
    local logLevel=$1
    local logMessage=$2
    fullDate=$(date +'%Y-%m-%d %M:%H:%S %Z')
    printf "${fullDate} | ${logLevel} | ${logMessage}\n"
}

ExitCall() {
    local exitLevel=$1
    local exitMessage=$2
    fullDate=$(date +'%Y-%m-%d %M:%H:%S %Z')
    printf "${fullDate} | ${exitLevel} | ${exitMessage}\n"
    exit 1
}


Usage() {
cat <<EOF
Usage(): $0 <image_src_url> <site_name>
    
E.g.,
$0   https://vesio.blob.core.windows.net/releases/rhel/9/x86_64/images/securemeshV2/f5xc-ce-crt-20250701-0107-9.2025.39-20250707054846.qcow2   <hyd | sjc>
* full image_url should be entered. 
EOF
exit 1
}


GetOpenStackAuth() {

#Expecting OS_USERNAME and OS_PASSWORD are set on the shell level
if [[ -z $OS_USERNAME && -z $OS_PASSWORD ]]; then
	ExitCall ERROR "export openstack username 'OS_USERNAME' and password 'OS_PASSWORD' variables" 
fi

#Looking for openstack cli
isOpenStackCliWorks=$(openstack --version >> /dev/null 2>&1; echo $?)
if [ "$isOpenStackCliWorks" -ne 0 ];then
    ExitCall ERROR "openstack cli is not installed. 'pip install python-openstackclient' and proceed"
fi

#Generating the openstack token based on the ENV variables set above
OS_TOKEN=$(openstack --insecure token issue -f value -c id)

#Creating the clouds.yaml and secure.yaml files to feed to terraform
mkdir -p ${HOME}/.config/openstack

cat <<EOF > ${HOME}/.config/openstack/clouds.yaml
clouds:
  os-xc-$site:
    auth:
      auth_url: ${OS_AUTH_URL}/v3
      project_domain_name: ${OS_PROJECT_DOMAIN_NAME}
      project_name: ${OS_PROJECT_NAME}
    indentity_api_version: "${OS_IDENTITY_API_VERSION}"
    verify: false
EOF

cat <<EOF > ${HOME}/.config/openstack/secure.yaml
clouds:
  os-xc-$site:
    auth:
      token: ${OS_TOKEN}
    auth_type: token
EOF
}

GetOpenStackEnv() {
case $site in
    hyd)
        export OS_AUTH_URL=http://hyd-xc-openstack.pdhyd.f5net.com:5000
        export OS_PROJECT_NAME="f5xc-automation-testing"
        export OS_PROJECT_DOMAIN_NAME="olympus"
        export OS_IDENTITY_API_VERSION=3
        export OS_PROJECT_DOMAIN_ID="6b150b090f6944dd8120cfe7ba1a8af2"
        export OS_USER_DOMAIN_ID="6b150b090f6944dd8120cfe7ba1a8af2"
        ;;
    sjc)
        export OS_AUTH_URL=https://sjc-xc-openstack.pdsjc.f5net.com:5000
        export OS_PROJECT_NAME="f5xc-automation-testing"
        export OS_PROJECT_DOMAIN_NAME="olympus"
        export OS_IDENTITY_API_VERSION=3
        export OS_PROJECT_DOMAIN_ID="909b362b3cc34e4da573e3a41c68b03f"
        export OS_USER_DOMAIN_ID="909b362b3cc34e4da573e3a41c68b03f"
        ;;
    *) 
        ExitCall ERROR "Invalid site '$site'. Allowed values are 'hyd' or 'sjc'."
        ;;
esac
}

UploadImageInOpenStack() {
  if openstack image show "$image_name" >/dev/null 2>&1; then
    ExitCall INFO "Image $image_name already exists in the $site instance"
  else
    Logger INFO "Image $image_name does not exist in the $site instance, downloading first....."

    # Get image size from content-length
    content_length=$(curl -sI "$image_url" | awk '/Content-Length/ {print $2}' | tr -d '\r')

    if [[ -z "$content_length" || "$content_length" -le 0 ]]; then
      ExitCall ERROR "Unable to determine remote image size"
    fi

    # Create a temp file
    temp_file=$(mktemp)

    Logger INFO "Downloading image (~$((content_length / 1024 / 1024)) MB)..."

    #Looking for pv utility
    isPvBinaryExist=$(pv --version >> /dev/null 2>&1; echo $?)
    if [ "$isPvBinaryExist" -ne 0 ];then
      ExitCall ERROR "Install pv utility ----> Linux: sudo apt install pv || Mac: brew install pv"
    fi

    # Show progress using pv while downloading
    curl -sL "$image_url" | pv -s "$content_length" > "$temp_file"
    download_result=$?

    if [ "$download_result" -ne 0 ]; then
      Logger ERROR "Download failed"
      rm -f "$temp_file"
      return 1
    fi

    Logger INFO "Uploading image $image_name to $site...."
    
    # Spinner while uploading
    (
      openstack image create \
        --insecure \
        --disk-format qcow2 \
        --container-format bare \
        --private \
        --file "$temp_file" \
        "${image_name}"
    ) &

    upload_pid=$!

    spin() {
      local spin='|/-\'
      local i=0
      while kill -0 "$upload_pid" 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\r[%c] Uploading...\n" "${spin:$i:1}"
        sleep 0.2
      done
      wait "$upload_pid"
      result=$?
      if [ "$result" -eq 0 ]; then
        printf "\r[✔] Upload complete.         \n"
        Logger INFO "Image ${image_name} uploaded successfully to $site"
      else
        printf "\r[✘] Upload failed.           \n"
        ExitCall ERROR "Image ${image_name} upload failed on $site"
      fi
    }

    spin

    # Clean up
    rm -f "$temp_file"
  fi
}

image_url=$1
site=$2
image_name=$(basename "$image_url" .qcow2)

if [ $# -lt 2 ]; then
  Usage
fi

GetOpenStackEnv
GetOpenStackAuth
UploadImageInOpenStack