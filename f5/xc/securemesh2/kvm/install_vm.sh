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

single-node site:

Usage(): bash $0 <kvm_image_name> <ver_type> <ce_name> <token>
E.g., f5xc-ce-9.2024.22-20240806132626.qcow2  single  auto-test-smv2-kvm <token>
E.g., f5xc-ce-9.2024.22-20240806132626.qcow2  multi  auto-test-smv2-kvm <token>


Options(): 

--help   Show this help message and exit.
EOF
exit 0
}

HOST_INT="eno1" # Host interface used for SLO
IP_PREFIX=$(ip addr show ${HOST_INT} | grep -o 'inet [0-9.]*' | awk '{print $2}' | awk -F. '{print $1"."$2}')
HOST_BR="br0" # Host interface used for SLI
IMG_DIR=/var/lib/libvirt/images # Dir where qcow2 images are saved on the host

SCR_DIR=$(dirname $0)
CLOUD_CONFIG=${SCR_DIR}/templates/cloud-config-base.tmpl
USER_DATA=${SCR_DIR}/user-data.txt
rm -f ${USER_DATA}


install_vm()
{

    #IMG=f5xc-ce-9.2024.22-20240806132626.qcow2
    IMG=${1}.qcow2
    vmname=${2}
    vm_nodes=${3}
    token=${4}
    # This depends on the VM host used creating VMs


    for (( i=0; i < ${vm_nodes}; i++ ))
    do
        sed -e "s/REPLACE_NODE_NAME/node-${i}/g" -e "s/REPLACE_TOKEN/${token}/g" ${CLOUD_CONFIG}  > ${USER_DATA}
        vm=${vmname}-${i}
        # remove stale VM 
        sudo virsh destroy ${vm}
        sudo virsh undefine ${vm}
        sudo rm -f ${IMG_DIR}/${vm}.qcow2
        sudo cp  ${IMG_DIR}/${IMG} ${IMG_DIR}/${vm}.qcow2
   

        sudo virt-install --name ${vm} \
        --ram 16384 \
        --vcpus=8 \
        --network type=direct,source=${HOST_INT},source.mode=bridge,model=virtio \
        --network bridge=${HOST_BR},model=virtio \
        --disk path=${IMG_DIR}/${vm}.qcow2,bus=virtio,format=qcow2  \
        --cloud-init user-data=${USER_DATA} \
        --accelerate \
        --os-variant rhl9 \
        --virt-type kvm \
        --noautoconsole \
        --import \
        --autostart \
        --graphics vnc \
        --channel unix,target_type=virtio,name=org.qemu.guest_agent.0

    done

    # Try to find VM IP. Wait up to 100 sec. for VM to boot
    for (( j=0; j < ${vm_nodes}; j++ ))
    do
        vm=${vmname}-${j}
        for (( i=0; i < 20; i++))
        do
            CE_IP=$(sudo ${SCR_DIR}/get_ce_ip.py ${vm} | grep ${IP_PREFIX})
            if  [ ! -z ${CE_IP} ]; then
                echo "VM ${vm} IP: $CE_IP"
                break
            else
                echo "VM does not have IP assinged yet, wiating 5 sec."
                sleep 5
            fi
        done
    done

    # set auto restart option explicitly
    for (( j=0; j < ${vm_nodes}; j++ ))
    do
        vm=${vmname}-${j}
        sudo virsh set-lifecycle-action ${vm} reboot restart
    done
}


# Check if help is requested
if [ "$1" == "--help" ]; then
   usage
fi

if [ $# -lt 4 ]; then
  usage
fi

# Variables
image_name=${1}
ver_type=${2}
ce_name=${3}
token=${4}



case $ver_type in
   single) 
      vm_nodes=1
      install_vm ${image_name} ${ce_name} ${vm_nodes} ${token}
      ;;
   multi)
      vm_nodes=3
      install_vm ${image_name} ${ce_name} ${vm_nodes} ${token}
      ;;
   *)
      usage
      ;;
esac
