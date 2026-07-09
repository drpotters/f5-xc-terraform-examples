#!/bin/bash -x

Usage() {
cat <<EOF
    Usage args:
    $0 <cluster_size> <token>

    Example: $0 single|multi jwt-token-key
EOF
exit 1
}

cluster_size=${1}
token=${2}

if [ $# -lt 2 ]; then
    Usage
fi

DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$DIR")
INV_FILE="${PARENT_DIR}/config/server.inv"
PLAYBOOK="${PARENT_DIR}/playbooks/prepare_vpm_config.yaml"
TEMPLATES_DIR="${PARENT_DIR}/templates"
export ANSIBLE_CONFIG="${PARENT_DIR}/config/ansible.cfg"

case $cluster_size in
    multi)
        sed -i '/10.218.90/s/^#//g' ${INV_FILE}
        sed -i '/192.168.10/s/^#//g' ${INV_FILE}
        ;;
    single)
        echo "" #Do nothing but keep it for any conditions
        ;;
    *)
        echo "Invalid CLUSTER_SIZE, input either single or multi"
        ;;
esac

nodes=$(awk '/^\[idrac_ce_nodes\]/ { in_section = 1; next }/^\[/ { in_section = 0 } in_section && !/^#/ { for (i = 1; i <= NF; i++) { if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) print $i } }' $INV_FILE | sort -u)
echo "CE Nodes are ==> $nodes"
for ip in ${nodes}; do
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "$ip" #Clearing the persisted host fingerprints
done

echo "Running ==> ansible-playbook -i $INV_FILE $PLAYBOOK --extra-vars 'token=${token} templates_dir=$TEMPLATES_DIR'"
source /var/lib/jenkins/bm-automation/bin/activate #This path creates python3 venv in the jenkins-slave
ansible-playbook -i $INV_FILE $PLAYBOOK --extra-vars "token=$token templates_dir=$TEMPLATES_DIR"
status=$(echo $?)
deactivate
if [ $status -eq 0 ];then
    echo "CE Installation successful"
else
    echo "CE setup failed"
    exit 1
fi
