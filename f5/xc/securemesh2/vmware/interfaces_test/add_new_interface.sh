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

# Function to display help
show_help() {
cat <<EOF
Usage help()

Usage(): bash $0 <ver-type> <ce_name> <port_group> <esxiserver_ip>
E.g., *  single|multi  test-smv2-vmware <port_group on esxi, example "VM Network2"> <ip of the vmware esxi> - Destroys the infrastructure in vmware

Environment Variables:

PASSWORD_ESXISERVER        The SSH password for the ESXI host. This must be set in the environment.

UserName has been set to USERNAME_ESXISERVER='root'

Options(): 

--help   Show this help message and exit.
EOF
exit 1
}

AddInterface() {
    local cluster_type=${1}
    # Prepare commands based on single or multi-node setup
    commands=()
    if [ "$cluster_type" == "single" ]; then
      commands+=("vim-cmd vmsvc/devices.createnic ${vm_ids[0]} vmxnet3 '${port_group}'")
    elif [ "$cluster_type" == "multi" ]; then
      commands+=("vim-cmd vmsvc/devices.createnic ${vm_ids[0]} vmxnet3 '${port_group}'")
      commands+=("vim-cmd vmsvc/devices.createnic ${vm_ids[1]} vmxnet3 '${port_group}'")
      commands+=("vim-cmd vmsvc/devices.createnic ${vm_ids[2]} vmxnet3 '${port_group}'")
    fi

    # Run commands over SSH
    for cmd in "${commands[@]}"; do
      Logger INFO "Adding the interface"
      output=$(timeout "$timeout" sshpass -p "$password_esxiserver" ssh -o StrictHostKeyChecking=no "$user_esxiserver"@${esxiserver_ip} "$cmd")
      exit_status=$?

      if [[ $exit_status -eq 0 ]]; then
        Logger INFO "Adding interface successful. Output >>>>"
        echo -e "$output"
      else
        echo -e "$output"
        ExitCall ERROR "Adding interface failed."
      fi
    done
}

GetVmID() {
    local cluster_type=${1}
    # Prepare commands based on single or multi-node setup
    commands=()
    if [ "$cluster_type" == "single" ]; then
      commands+=("vim-cmd vmsvc/getallvms | grep ${ce_name} | cut -d ' ' -f 1")
    elif [ "$cluster_type" == "multi" ]; then
      commands+=("vim-cmd vmsvc/getallvms | grep ${ce_name}1 | cut -d ' ' -f 1")
      commands+=("vim-cmd vmsvc/getallvms | grep ${ce_name}2 | cut -d ' ' -f 1")
      commands+=("vim-cmd vmsvc/getallvms | grep ${ce_name}3 | cut -d ' ' -f 1")
    fi

    # Run commands over SSH
    for cmd in "${commands[@]}"; do
      Logger INFO "VM ID is >>"
      output=$(timeout "$timeout" sshpass -p "$password_esxiserver" ssh -o StrictHostKeyChecking=no "$user_esxiserver"@${esxiserver_ip} "$cmd")
      vm_ids+=("$output")
      exit_status=$?

      if [[ $exit_status -eq 0 ]]; then
        Logger INFO "VM ID fetch success. Output >>>>"
        echo -e "\n$output\n"
      else
        echo -e "$output"
        ExitCall ERROR "VM ID fetch fail."
      fi
    done
}

GetCredentialVariables() {
if [ -z "$password_esxiserver" ]; then
cat <<EOF
Export below variables on the shell level before proceeding.
export PASSWORD_ESXISERVER='some_pass'

UserName has been set to USERNAME_ESXISERVER='root'

EOF
ExitCall ERROR "Necessary variables are missing on the shell level. Exiting.."
fi
}

# Check if help is requested
if [ "$1" == "--help" ]; then
    show_help
fi

# Variables
ver_type=${1}
ce_name=${2}
port_group=${3}
esxiserver_ip=${4}
timeout=30

# Read username and password from environment variables
user_esxiserver="root"
password_esxiserver="${PASSWORD_ESXISERVER}"

vm_ids=()

if [ $# -lt 4 ]; then
    show_help
fi

case $ver_type in
   single)
      GetCredentialVariables
      GetVmID single
      AddInterface single
      ;;
   multi)
      GetCredentialVariables
      GetVmID multi
      AddInterface multi
      ;;
   *)
      show_help
      ;;
esac
