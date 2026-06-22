#!/bin/bash

set -euo pipefail

#####################################################################
# VMware ESXi Ubuntu Provisioner using govc
#
# Reads config.properties from same directory as script
#
# Required ENV:
#   GOVC_USERNAME
#   GOVC_PASSWORD
#   UBUNTU_USER
#   UBUNTU_PASSWORD
#####################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.properties"

# Validate config.properties
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config.properties not found in $SCRIPT_DIR"
    exit 1
fi

# Read config.properties
while IFS='=' read -r key value; do
    [[ -z "${key// }" ]] && continue
    [[ "$key" =~ ^# ]] && continue

    key="$(echo "$key" | xargs)"
    value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    value="${value%\"}"
    value="${value#\"}"

    export "$key=$value"
done < "$CONFIG_FILE"

# Validate ENV
required_env=(
    GOVC_USERNAME
    GOVC_PASSWORD
    UBUNTU_USER
    UBUNTU_PASSWORD
)

for v in "${required_env[@]}"; do
    [[ -z "${!v:-}" ]] && { echo "ERROR: Missing ENV: $v"; exit 1; }
done


# Validate required properties
required_props=(
    GOVC_URL
    DATASTORE
    SOURCE_IMAGE
    VM_NETWORK
    VM_CPU
    VM_RAM_MB
    VM_DISK_GB
    CLIENT_PACKAGES
    SERVER_PACKAGES
    NUM_CLIENTS
    NUM_SERVERS
)

for v in "${required_props[@]}"; do
    [[ -z "${!v:-}" ]] && { echo "ERROR: Missing property: $v"; exit 1; }
done

# govc env
export GOVC_URL
export GOVC_INSECURE="${GOVC_INSECURE:-1}"

# Globals
declare -A VM_IPS
declare -A VM_TYPES
declare -a VM_LIST

# SSH options
SSH_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o GlobalKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -o ConnectTimeout=5
)

# Helpers
random_id() {
    openssl rand -hex 3 | cut -c1-5
}

GROUP_ID="$(random_id)"

wait_for_ip() {
    local vm="$1"

    echo "Waiting for IP: $vm"

    for ((i=1; i<=90; i++)); do
        ip="$(govc vm.ip -wait=1m "$vm" 2>/dev/null || true)"

        if [[ -n "$ip" ]]; then
            VM_IPS["$vm"]="$ip"
            printf "%-35s %s\n" "$vm" "$ip"
            return 0
        fi

        sleep 10
    done

    VM_IPS["$vm"]="IP NOT FOUND"
    return 1
}

wait_for_ssh() {
    local ip="$1"

    for ((i=1; i<=60; i++)); do
        if sshpass -p "$UBUNTU_PASSWORD" ssh "${SSH_OPTS[@]}" \
            "$UBUNTU_USER@$ip" "echo ok" >/dev/null 2>&1; then
            return 0
        fi
        sleep 10
    done

    return 1
}

run_ssh() {
    local ip="$1"
    local cmd="$2"

    sshpass -p "$UBUNTU_PASSWORD" ssh "${SSH_OPTS[@]}" \
        "$UBUNTU_USER@$ip" "$cmd"
}

create_vm() {
    local vm="$1"

    echo "Creating VM: $vm"

    govc vm.create \
        -on=false \
        -ds="$DATASTORE" \
        -net="$VM_NETWORK" \
        -g=ubuntu64Guest \
        -m="$VM_RAM_MB" \
        -c="$VM_CPU" \
        -disk="${VM_DISK_GB}G" \
        "$vm"

    govc device.cdrom.add -vm "$vm" >/dev/null 2>&1 || true

    govc device.cdrom.insert \
        -vm "$vm" \
        "[${DATASTORE}] ${SOURCE_IMAGE}"

    govc vm.power -on "$vm"
}

deploy_group() {
    local prefix="$1"
    local count="$2"

    for ((n=1; n<=count; n++)); do
        vm="${prefix}-${GROUP_ID}-${n}"

        VM_TYPES["$vm"]="$prefix"
        VM_LIST+=("$vm")

        create_vm "$vm"
    done
}

add_secondary_nic() {
    local vm="$1"

    # optional network
    if [[ -z "${SECONDARY_NETWORK:-}" ]]; then
        return 0
    fi

    echo "Adding secondary NIC to $vm"

    govc vm.network.add \
        -vm "$vm" \
        -net "$SECONDARY_NETWORK"
}

set_hostname() {
    local vm="$1"
    local ip="$2"

    echo "Setting hostname on $vm"

    run_ssh "$ip" "
sudo hostnamectl set-hostname $vm
echo '$vm' | sudo tee /etc/hostname >/dev/null
grep -q '^127.0.1.1' /etc/hosts && \
sudo sed -i 's/^127.0.1.1.*/127.0.1.1 $vm/' /etc/hosts || \
echo '127.0.1.1 $vm' | sudo tee -a /etc/hosts >/dev/null
"
}

install_packages() {
    local vm="$1"
    local ip="$2"
    local type="$3"

    if [[ "$type" == "client" ]]; then
        pkgs="${CLIENT_PACKAGES//,/ }"
    else
        pkgs="${SERVER_PACKAGES//,/ }"
    fi

    echo "Installing packages on $vm: $pkgs"

    run_ssh "$ip" \
        "sudo apt update && sudo apt install -y $pkgs"
}

##########################################################
# Main
##########################################################
echo "=================================================="
echo "Starting ESXi VM creation"
echo "Group ID   : $GROUP_ID"
echo "GOVC_URL   : $GOVC_URL"
echo "Datastore  : $DATASTORE"
echo "ISO        : [$DATASTORE] $SOURCE_IMAGE"
echo "PrimaryNet : $VM_NETWORK"
echo "SecondNet  : ${SECONDARY_NETWORK:-<none>}"
echo "Clients    : $NUM_CLIENTS"
echo "Servers    : $NUM_SERVERS"
echo "=================================================="

deploy_group client "$NUM_CLIENTS"
deploy_group server "$NUM_SERVERS"

echo "=================================================="
echo "Waiting for VM IP addresses..."
echo "=================================================="

for vm in "${VM_LIST[@]}"; do
    wait_for_ip "$vm"
done

echo "=================================================="
echo "Waiting 10 minutes for Ubuntu install to finish..."
echo "=================================================="

sleep 600

for vm in "${VM_LIST[@]}"; do
    add_secondary_nic "$vm"
done

for vm in "${VM_LIST[@]}"; do
    ip="${VM_IPS[$vm]}"
    type="${VM_TYPES[$vm]}"

    [[ "$ip" == "IP NOT FOUND" ]] && continue

    echo "Waiting for SSH on $vm ($ip)..."

    if wait_for_ssh "$ip"; then
        set_hostname "$vm" "$ip"
        install_packages "$vm" "$ip" "$type"
    else
        echo "WARNING: SSH not ready on $vm ($ip)"
    fi
done

echo "=================================================="
echo "Provisioning complete for group: $GROUP_ID"
echo "=================================================="

for vm in "${VM_LIST[@]}"; do
    printf "%-35s %s\n" "$vm" "${VM_IPS[$vm]}"
done

echo "=================================================="