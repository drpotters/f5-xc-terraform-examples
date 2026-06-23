#!/bin/bash

GetOpenStackAuth() {
#Default hard-coded variables for XC-Hyd-OpenStack. 
#This function needs changes if there are multiple instances.

export OS_AUTH_URL=http://hyd-xc-openstack.pdhyd.f5net.com:5000
export OS_PROJECT_NAME="f5xc-automation-testing"
export OS_PROJECT_DOMAIN_NAME="olympus"
export OS_IDENTITY_API_VERSION=3
export OS_PROJECT_DOMAIN_ID="6b150b090f6944dd8120cfe7ba1a8af2"
export OS_USER_DOMAIN_ID="6b150b090f6944dd8120cfe7ba1a8af2"

#Expecting OS_USERNAME and OS_PASSWORD are set on the shell level
if [[ -z $OS_USERNAME && -z $OS_PASSWORD ]]; then
	echo "export openstack username 'OS_USERNAME' and password 'OS_PASSWORD' variables" 
	exit 1
fi

#Looking for openstack cli
isOpenStackCliWorks=$(openstack --version >> /dev/null 2>&1; echo $?)
if [ "$isOpenStackCliWorks" -ne 0 ];then
    echo "openstack cli is not installed. 'pip install python-openstackclient' and proceed"
fi

#Generating the openstack token based on the ENV variables set above
OS_TOKEN=$(openstack token issue -f value -c id)

#Creating the clouds.yaml and secure.yaml files to feed to terraform
mkdir -p ${HOME}/.config/openstack

cat <<EOF > ${HOME}/.config/openstack/clouds.yaml
clouds:
  os-xc-hyd:
    auth:
      auth_url: ${OS_AUTH_URL}/v3
      project_domain_name: ${OS_PROJECT_DOMAIN_NAME}
      project_name: ${OS_PROJECT_NAME}
    indentity_api_version: "${OS_IDENTITY_API_VERSION}"
    verify: false
EOF

cat <<EOF > ${HOME}/.config/openstack/secure.yaml
clouds:
  os-xc-hyd:
    auth:
      token: ${OS_TOKEN}
    auth_type: token
EOF
}

DeleteVMS() {

echo "Listing all the VMs that would be both deleted and retained..."

openstack server list -f value -c ID -c Name | while read -r id name; do
    json_output=$(openstack server show "$id" -f json 2>/dev/null)
    if [[ -z "$json_output" ]]; then
        echo "[ERROR] Could not retrieve metadata for $name ($id), skipping..."
        continue
    fi

    cleanup_tag=$(echo "$json_output" | jq -r '.properties.cleanup // empty' | xargs | tr '[:upper:]' '[:lower:]')

    #Removing VMs having no cleanup=skip key value pair added in its metadata
    #List prints both Name of the VM and its associated ID

    if [[ "$cleanup_tag" != "skip" ]]; then
        echo "[DELETING] VM: $name ($id) [No 'cleanup=skip' in metadata]"
        openstack server delete "$id"
    else
        echo "[RETAINING] VM: $name ($id) [cleanup=skip]"
    fi
done

}


#----------------#
#      main      #
#----------------#
#Calling auth and delete functions here.
GetOpenStackAuth
DeleteVMS