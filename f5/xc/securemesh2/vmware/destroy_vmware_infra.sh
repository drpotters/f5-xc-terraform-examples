#!/bin/bash

tput setaf 15 

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

GetEnvSetup() {

if [ -z "$VCENTER_USER" ] || [ -z "$VCENTER_PASSWORD" ]; then
cat <<EOF
Export below variables on the shell level before proceeding.
export VCENTER_USER='some_user@olympus' #make sure the domain name '@olympus' is added to the username
export VCENTER_PASSWORD='some_pass'
EOF
ExitCall ERROR "Necessary variables are missing on the shell level. Exiting.."
fi

# Get and Set environment variables
export GOVC_INSECURE='true'
export GOVC_URL="${vcenter_url}"
export GOVC_USERNAME="${VCENTER_USER}"
export GOVC_PASSWORD="${VCENTER_PASSWORD}"
export GOVC_DATACENTER="${datacenter}"
export GOVC_CLUSTER="${cluster}"
export GOVC_RESOURCE_POOL="${project}"

#Looking for govc cli
isGOVCCliWorks=$(govc version >> /dev/null 2>&1; echo $?)
if [ "$isGOVCCliWorks" -ne 0 ];then
    ExitCall ERROR "govc cli is not installed. Follow https://github.com/vmware/govmomi/releases documentation"
fi

}


DestroyVCenterVMs() {
GetEnvSetup
#Loop through the .vm_setup_file and delete the VMs
if [ -f "${install_dir}/.vm_setup_file" ]; then
  while IFS='' read -r vm; do
    if [ -n "$vm" ]; then
      Logger INFO "Powering off VM: $vm in folder $GOVC_RESOURCE_POOL"

      if ! govc vm.power -off "/$GOVC_DATACENTER//vm/$vm" 2>/dev/null; then
        Logger WARNING "VM might already be powered off or not found."
      fi

      Logger INFO "Deleting VM: $vm"

      if ! govc vm.destroy "/$GOVC_DATACENTER//vm/$vm" 2>/dev/null; then
        Logger ERROR "Failed to destroy VM: $vm"
      else
        Logger INFO "Deleted VM: $vm successfully."
      fi
    fi
  done < "${install_dir}/.vm_setup_file"

  Logger INFO "All VMs from ${install_dir}/.vm_setup_file have been processed."

else
  ExitCall ERROR "File ${install_dir}/.vm_setup_file not found."
fi
}

#========= main() ==========#
# Scripts default directory
install_dir=$(dirname "$(realpath "$0")")
if [ ! -f ${install_dir}/config.properties ] ;then
   ExitCall ERROR "${install_dir}/config.properties is missing"
else
   source ${install_dir}/config.properties
fi
DestroyVCenterVMs