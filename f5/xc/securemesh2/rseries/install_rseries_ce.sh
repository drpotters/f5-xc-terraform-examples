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

# Function to display help
show_help() {
cat <<EOF
Usage help()

single-node site:

Usage(): bash $0 <ce_name> <rseries_ce_image_name> <ver-type> <rseries_tenants_api_url> <token>
E.g., test-smv2-rseries f5xc-ce-9.2024.22-20240806132626.qcow2.9afecc51.tar.bundle single https://<rseries_box_ip>:8888/restconf/data/f5-tenants:tenants <token> - Installs the infrastructure in F5 rseries

multi-node site:

Usage(): bash $0 <ce_name> <rseries_ce_image_name> <ver-type> <rseries_tenants_api_url> <token>
E.g., test-smv2-rseries f5xc-ce-9.2024.22-20240806132626.qcow2.9afecc51.tar.bundle multi https://<rseries_box_ip>:8888/restconf/data/f5-tenants:tenants <token> - Installs the infrastructure in F5 rseries

Environment Variables:

PASSWORD_F5_RSERIES        The SSH password for the F5 rseries host. This must be set in the environment.

- Note : user is set to USERNAME_F5_RSERIES='admin'.

Options(): 

--help   Show this help message and exit.
EOF
exit 1
}

PrepareRseriesClusterInfraTemplate() {
    local tenant_name=${1}
    CheckPlatformDir

    Logger INFO "Initiating the preparation of rseries template"
    # Define the input file and output file
    if [[ $rseries_tenants_api_url == *"10.196"* ]]; then
        input_file="${install_dir}/templates/tenant-cn1.create.api.data_template_test_rseries.txt"
    else
        input_file="${install_dir}/templates/tenant-cn1.create.api.data_template.txt"
    fi
    output_file="${install_dir}/tenant-cn1.create.api.data.txt"

    if [ ! -e ${input_file} ];then
      ExitCall ERROR "There is no rseries template present. Please check and try again"
    fi    

    # Use sed to perform the replacements
    output=$(sed -e "s/\"name\": \"change\"/\"name\": \"$tenant_name\"/g" \
                 -e "s/\"image\": \"change\"/\"image\": \"$image_name\"/g" \
                 -e "s/\"token:change\"/\"token:$token\"/g" \
                 "$input_file" 2>&1)
    exit_status=$?

    if [[ $exit_status -eq 0 ]]; then
      echo "$output" > "$output_file"
      Logger INFO "Preparing rseries template completed successfully."
    else
      echo "Error output: $output"
      ExitCall ERROR "Preparing rseries template failed."
    fi
}

SpinClusterInfra() {
    CheckPlatformDir

    # Define the file path and the URL
    data_file="${install_dir}/tenant-cn1.create.api.data.txt"

    if [ ! -e ${data_file} ];then
      ExitCall ERROR "There is no rseries datafile present. Please check and try again"
    fi

    Logger INFO "Initiating the Infra Setup"
    output=$(curl -k -X POST -H "Content-Type: application/yang-data+json" --data-binary "@$data_file" -H "Accept: application/yang-data+json" -u admin:${password_f5_rseries} "$rseries_tenants_api_url")
    exit_status=$?

    if [[ $exit_status -eq 0 ]]; then
      Logger INFO "rseries infra setup completed successfully."
      echo -e "$output"
    else
      echo -e "$output"
      ExitCall ERROR "Installation failed."
    fi
}

GetCredentialVariables() {
if [ -z "$password_f5_rseries" ]; then
cat <<EOF
Export below variable on the shell level before proceeding.
export PASSWORD_F5_RSERIES='some_pass'

- Note : user is set to USERNAME_F5_RSERIES='admin'.
EOF
ExitCall ERROR "Necessary variables are missing on the shell level. Exiting.."
fi
}

CheckPlatformDir(){
    if [ ! -d ${install_dir} ];then
      ExitCall ERROR "There is no platform directory '${install_dir}' exists. Please check the platform and try again"
    fi
}

# Check if help is requested
if [ "$1" == "--help" ]; then
    show_help
fi

# Variables
install_dir=$(dirname "$(realpath "$0")")
ce_name=${1}
image_name=${2}
ver_type=${3}
rseries_tenants_api_url=${4}
token=${5}

# Read username and password from environment variables
user_f5_rseries="admin"  # hard-coded since this never change
password_f5_rseries="${PASSWORD_F5_RSERIES}"

if [ $# -lt 5 ]; then
  show_help
fi

case $ver_type in
   single) 
      GetCredentialVariables
      PrepareRseriesClusterInfraTemplate "$ce_name"
      SpinClusterInfra
      ;;
   multi)
      GetCredentialVariables
      for i in {1..3}; do
          PrepareRseriesClusterInfraTemplate "${ce_name}${i}"
          SpinClusterInfra
      done
      ;;
   *)
      show_help
      ;;
esac
