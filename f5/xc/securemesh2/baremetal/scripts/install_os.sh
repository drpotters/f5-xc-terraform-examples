#!/bin/bash
DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$DIR")
INV_FILE="${PARENT_DIR}/config/server.inv"
PLAYBOOK="${PARENT_DIR}/playbooks/bm_main.yaml"
CONFIG_DIR="${PARENT_DIR}/config"
CONTROLLER_HOST=$(hostname -i | awk '{print $1}')
CLUSTER_SIZE=${1}
IMAGE_NAME=${2}
DOWNLOAD_IMAGE=${3}

Usage() {
cat <<EOF
==> Usage without downloading the image: 
$0 <cluster_size> <image_name>
E.g., $0 single|multi f5xc-ce-9.2025.17-securemeshv2-20250523-0731.iso
    
==> Usage with downloading the image:
$0 <cluster_size> <image_name> --download
E.g., $0 single|multi f5xc-ce-9.2025.17-securemeshv2-20250523-0731.iso --download
EOF
exit 1
}

if [ $# -lt 2 ];then
   Usage
fi

case $CLUSTER_SIZE in
    multi)
        sed -i '/10.218/s/^#//g' ${INV_FILE}
        ;;
    single)
        echo "" #Do nothing but keep it for any conditions
        ;;
    *)
        Usage
        ;;
esac

if [ "${DOWNLOAD_IMAGE}" == "--download" ];then
   sed -i 's/^[[:space:]]*#//' ${PLAYBOOK}
fi

IMAGE_SRC_URL="https://downloads.volterra.io/releases/rhel/9/x86_64/images/securemeshV2/${IMAGE_NAME}"
export ANSIBLE_CONFIG="${CONFIG_DIR}/ansible.cfg"
if [ ! -z ${ROOT_PASS} ]; then
  # 'ROOT_PASS' variable is parameter set in jenkins to read the default root password to become a super user
  #  While testing locally, must set both 'ROOT_PASS' shell variable before executing this script
  source /var/lib/jenkins/bm-automation/bin/activate #This path creates python3 venv in the jenkins-slave
  ansible-playbook -i $INV_FILE $PLAYBOOK --extra-vars "ansible_become_pass=$ROOT_PASS config_dir=$CONFIG_DIR  image_src_url=$IMAGE_SRC_URL image_name=$IMAGE_NAME ansible_controller_host=$CONTROLLER_HOST" -vvv
  status=$(echo $?)
  deactivate
  sleep 20
  if [ $status -eq 0 ];then
    echo "OS Installation has been successful. Checking for nodes if they are pingable..."
    nodes=$(awk '/^\[idrac_ce_nodes\]/ { in_section = 1; next }/^\[/ { in_section = 0 } in_section && !/^#/ { for (i = 1; i <= NF; i++) { if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) print $i } }' $INV_FILE | sort -u)
    echo -e "CE Nodes are::\n$nodes"
    all_nodes_pingable=false
    for i in $(seq 0 20); do
      all_nodes_pingable=true #Assuming all nodes are available before checking
      for ip in ${nodes}; do
        ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "$ip" #Clearing the persisted host fingerprints
        if ! ping -c 1 -W 1 "$ip" &> /dev/null; then
          all_nodes_pingable=false #If any node is not pingable then set to false and break
          break 
        fi
      done

      if [ $all_nodes_pingable == true ]; then
        echo "All CE nodes are pingable now..exiting.."
        break
      fi

      echo "Attempt $i: Not all CE nodes are pingable.. Retrying"
      sleep 30
    done
  else
    echo "OS Installation failed"
    exit 1
  fi
else
  echo "Set ROOT_PASS variable and re-run again"
fi
