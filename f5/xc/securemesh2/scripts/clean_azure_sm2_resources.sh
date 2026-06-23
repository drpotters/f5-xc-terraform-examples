#!/bin/bash

# Azure Orphan Resource Cleanup Script
#
# Cleans:
#   - Virtual Machines
#   - Managed Disks
#   - Network Interfaces
#   - Public IP Addresses
#
# Handles:
#   - Normal VM dependency cleanup
#   - Orphan/Stale resources without VMs
#
# Usage:
#   ./azure-cleanup.sh <region> <resource-pattern>
#
# Example:
#   ./azure-cleanup.sh eastus test-cluster

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <region> <resource-pattern>"
    exit 1
fi

REGION="$1"
PATTERN="$2"

echo "===================================================="
echo "Azure Cleanup"
echo "Region          : $REGION"
echo "Resource Pattern: $PATTERN"
echo "===================================================="
echo

# =========================================================
# STEP 1 - DELETE VMs
# =========================================================

VM_LIST=$(az vm list \
    --query "[?location=='$REGION' && contains(name, '$PATTERN')].[name,resourceGroup]" \
    -o tsv)

if [[ -n "$VM_LIST" ]]; then

    echo "Matched VMs:"
    echo "----------------------------------------------------"

    while read -r VM_NAME RG; do
        echo "VM: $VM_NAME    RG: $RG"
    done <<< "$VM_LIST"

    echo "----------------------------------------------------"
    echo

    read -rp "Proceed with deletion? (yes/no): " CONFIRM

    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi

    while read -r VM_NAME RG; do

        echo
        echo "===================================================="
        echo "Processing VM : $VM_NAME"
        echo "Resource Group: $RG"
        echo "===================================================="

        # Collect dependencies BEFORE deleting VM

        NIC_IDS=$(az vm show \
            -g "$RG" \
            -n "$VM_NAME" \
            --query "networkProfile.networkInterfaces[].id" \
            -o tsv)

        OS_DISK=$(az vm show \
            -g "$RG" \
            -n "$VM_NAME" \
            --query "storageProfile.osDisk.name" \
            -o tsv)

        DATA_DISKS=$(az vm show \
            -g "$RG" \
            -n "$VM_NAME" \
            --query "storageProfile.dataDisks[].name" \
            -o tsv)

        # Delete VM
        echo
        echo "[VM] Deleting VM..."

        az vm delete \
            -g "$RG" \
            -n "$VM_NAME" \
            --yes

        echo "VM deleted."

        # Delete NICs + associated Public IPs
        if [[ -n "$NIC_IDS" ]]; then

            while read -r NIC_ID; do

                [[ -z "$NIC_ID" ]] && continue

                NIC_NAME=$(basename "$NIC_ID")

                echo
                echo "[NIC] Processing NIC: $NIC_NAME"

                PUBLIC_IP_IDS=$(az network nic show \
                    --ids "$NIC_ID" \
                    --query "ipConfigurations[].publicIPAddress.id" \
                    -o tsv 2>/dev/null || true)

                az network nic delete \
                    --ids "$NIC_ID"

                echo "NIC deleted."

                # Delete Public IPs
                if [[ -n "$PUBLIC_IP_IDS" ]]; then

                    while read -r PIP_ID; do

                        [[ -z "$PIP_ID" ]] && continue

                        PIP_NAME=$(basename "$PIP_ID")

                        echo "[PIP] Deleting Public IP: $PIP_NAME"

                        az network public-ip delete \
                            --ids "$PIP_ID"

                        echo "Public IP deleted."

                    done <<< "$PUBLIC_IP_IDS"
                fi

            done <<< "$NIC_IDS"
        fi

        # Delete OS Disk
        if [[ -n "$OS_DISK" ]]; then

            echo
            echo "[DISK] Deleting OS Disk: $OS_DISK"

            az disk delete \
                -g "$RG" \
                -n "$OS_DISK" \
                --yes

            echo "OS Disk deleted."
        fi

        # Delete Data Disks
        if [[ -n "$DATA_DISKS" ]]; then

            while read -r DISK; do

                [[ -z "$DISK" ]] && continue

                echo "[DISK] Deleting Data Disk: $DISK"

                az disk delete \
                    -g "$RG" \
                    -n "$DISK" \
                    --yes

                echo "Data Disk deleted."

            done <<< "$DATA_DISKS"
        fi

    done <<< "$VM_LIST"

else
    echo "No matching VMs found."
fi

echo
echo "===================================================="
echo "STEP 2 - Cleaning Orphan Resources"
echo "===================================================="

# =========================================================
# STEP 2 - DELETE ORPHAN DISKS
# =========================================================

echo
echo "Searching for orphan disks..."

ORPHAN_DISKS=$(az disk list \
    --query "[?location=='$REGION' && contains(name, '$PATTERN') && managedBy==null].[name,resourceGroup]" \
    -o tsv)

if [[ -n "$ORPHAN_DISKS" ]]; then

    while read -r DISK_NAME RG; do

        [[ -z "$DISK_NAME" ]] && continue

        echo "[ORPHAN DISK] Deleting: $DISK_NAME"

        az disk delete \
            -g "$RG" \
            -n "$DISK_NAME" \
            --yes

    done <<< "$ORPHAN_DISKS"

else
    echo "No orphan disks found."
fi

# =========================================================
# STEP 3 - DELETE ORPHAN NICS
# =========================================================

echo
echo "Searching for orphan NICs..."

ORPHAN_NICS=$(az network nic list \
    --query "[?location=='$REGION' && contains(name, '$PATTERN') && virtualMachine==null].[name,resourceGroup,id]" \
    -o tsv)

if [[ -n "$ORPHAN_NICS" ]]; then

    while read -r NIC_NAME RG NIC_ID; do

        [[ -z "$NIC_NAME" ]] && continue

        echo
        echo "[ORPHAN NIC] Processing: $NIC_NAME"

        PUBLIC_IP_IDS=$(az network nic show \
            --ids "$NIC_ID" \
            --query "ipConfigurations[].publicIPAddress.id" \
            -o tsv 2>/dev/null || true)

        az network nic delete \
            --ids "$NIC_ID"

        echo "NIC deleted."

        # Delete attached Public IPs
        if [[ -n "$PUBLIC_IP_IDS" ]]; then

            while read -r PIP_ID; do

                [[ -z "$PIP_ID" ]] && continue

                PIP_NAME=$(basename "$PIP_ID")

                echo "[PIP] Deleting attached Public IP: $PIP_NAME"

                az network public-ip delete \
                    --ids "$PIP_ID"

            done <<< "$PUBLIC_IP_IDS"
        fi

    done <<< "$ORPHAN_NICS"

else
    echo "No orphan NICs found."
fi

# =========================================================
# STEP 4 - DELETE UNASSOCIATED PUBLIC IPS
# =========================================================

echo
echo "Searching for orphan Public IPs..."

ORPHAN_PIPS=$(az network public-ip list \
    --query "[?location=='$REGION' && contains(name, '$PATTERN') && ipConfiguration==null].[name,resourceGroup]" \
    -o tsv)

if [[ -n "$ORPHAN_PIPS" ]]; then

    while read -r PIP_NAME RG; do

        [[ -z "$PIP_NAME" ]] && continue

        echo "[ORPHAN PIP] Deleting: $PIP_NAME"

        az network public-ip delete \
            -g "$RG" \
            -n "$PIP_NAME"

    done <<< "$ORPHAN_PIPS"

else
    echo "No orphan Public IPs found."
fi

echo
echo "===================================================="
echo "Cleanup completed successfully."
echo "===================================================="
