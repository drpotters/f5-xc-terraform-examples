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

# Function to display usage
usage() {
cat <<EOF
Usage help()

single node site:
Usage(): bash $0  <ce_name> <ver_type>
E.g. $0 single  auto-test-smv2-kvm

multi nodes site:
E.g. $0 multi  auto-test-smv2-kvm 


--help   Show this help message and exit.
EOF
exit 1
}

IMG_DIR=/var/lib/libvirt/images # Dir where qcow2 images are saved on the host


destroy_vm()
{

    vm_nodes=${2}
    vmname=${1}
    # This depends on the VM host used creating VMs


    for (( i=0; i < ${vm_nodes}; i++ ))
    do
        vm=${vmname}-${i}
        sudo virsh destroy ${vm}
        sudo virsh undefine ${vm}
        sudo rm -f ${IMG_DIR}/${vm}.qcow2
    done
}


# Check if help is requested
if [ "$1" == "--help" ]; then
   usage
fi

if [ $# -lt 2 ]; then
  usage
fi

# Variables
ver_type=${1}
ce_name=${2}



case $ver_type in
   single) 
      vm_nodes=1
      destroy_vm ${ce_name} ${vm_nodes}
      ;;
   multi)
      vm_nodes=3
      destroy_vm ${ce_name} ${vm_nodes}
      ;;
   *)
      usage
      ;;
esac
