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

Usage(): bash $0 <ce_name> <ver-type> <rseries_tenants_api_url>
E.g., test-smv2-rseries single https://<rseries_box_ip>:8888/restconf/data/f5-tenants:tenants - Destroys the infrastructure in F5 rseries

multi-node site:

Usage(): bash $0 <ce_name> <ver-type> <rseries_tenants_api_url>
E.g., test-smv2-rseries multi https://<rseries_box_ip>:8888/restconf/data/f5-tenants:tenants - Destroys the infrastructure in F5 rseries

Environment Variables:

PASSWORD_F5_RSERIES        The SSH password for the F5 rseries host. This must be set in the environment.

- Note : user is set to USERNAME_F5_RSERIES='admin'.

Options(): 

--help   Show this help message and exit.
EOF
exit 1
}

DestroyClusterInfra() {
    local tenant_name=${1}
    rseries_tenant_delete_api="${rseries_tenants_api_url}/tenant=${tenant_name}/"    

    Logger INFO "Initiating the Infra Destroy"
    output=$(curl -k -X DELETE "$rseries_tenant_delete_api" -H "Content-Type: application/yang-data+json" -H "Accept: application/yang-data+json" -u admin:${password_f5_rseries})    
    exit_status=$?

    if [[ $exit_status -eq 0 ]]; then
      Logger INFO "rseries infra destroy completed successfully."
      echo -e "$output"
    else
      echo -e "$output"
      ExitCall ERROR "Destroy failed."
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

# Check if help is requested
if [ "$1" == "--help" ]; then
    show_help
fi

# Variables
ce_name=${1}
ver_type=${2}
rseries_tenants_api_url=${3}

# Read username and password from environment variables
user_f5_rseries="admin"  # hard-coded since this never change
password_f5_rseries="${PASSWORD_F5_RSERIES}"

if [ $# -lt 3 ]; then
  show_help
fi

case $ver_type in
   single) 
      GetCredentialVariables
      DestroyClusterInfra "$ce_name" 
      ;;
   multi)
      GetCredentialVariables
      for i in {1..3}; do
          DestroyClusterInfra "${ce_name}${i}"
      done
      ;;
   *)
      show_help
      ;;
esac
