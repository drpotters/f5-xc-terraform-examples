#!/bin/bash

PATTERN="${1}" 
RESOURCE_GROUP="${2}"
SUBSCRIPTION_ID="${3}"

if [ $# -lt 3 ];then
    echo "Usage(): $0 <resource-pattern> <resource-group> <subscription-id>"
    echo ""
    echo "XC Subscription IDs for your reference:"
    echo "-----------------------------------------------------------------------------"
    echo "|          Subscription ID              |            Name                   |"
    echo "-----------------------------------------------------------------------------"
    echo "|  b07ce22b-a877-4fb7-8b91-412af79e32ea | VES DevTest Manual - Sponsored    |"
    echo "|  f68d94a5-1db7-4954-9a79-02b5711cb0a1 | VES DevTest Automated - Sponsored |"
    echo "-----------------------------------------------------------------------------"
    exit 1
fi

auth_az() {
    if [ -n "$ARM_CLIENT_ID" ] && [ -n "$ARM_CLIENT_SECRET" ] && [ -n "$ARM_TENANT_ID" ] ; then
        az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
        az account set --subscription $SUBSCRIPTION_ID
    else
        echo "Unable to fetch ARM variables to authenticate to Azure"
    fi
}

delete_resources() {
    echo "Deleting resources matching pattern: $PATTERN in resource group: $RESOURCE_GROUP and subscription: $SUBSCRIPTION_ID"

    echo "Deleting Virtual Machines..."
    VMS=$(az vm list --resource-group $RESOURCE_GROUP --query "[?contains(name, '$PATTERN')].name" -o tsv)
    for VM in $VMS; do
        echo "Deleting VM: $VM"
        az vm delete --resource-group $RESOURCE_GROUP --name $VM --yes --no-wait
    done

    echo "Waiting for Virtual Machines to be deleted..."
    for VM in $VMS; do
        az vm wait --deleted --timeout 600 --resource-group $RESOURCE_GROUP --name $VM
    done

    echo "Deleting Network Interfaces..."
    NICS=$(az network nic list --resource-group $RESOURCE_GROUP --query "[?contains(name, '$PATTERN')].name" -o tsv)
    for NIC in $NICS; do
        echo "Deleting NIC: $NIC"
        az network nic delete --resource-group $RESOURCE_GROUP --name $NIC
    done

    echo "Deleting Public IPs..."
    PUBLIC_IPS=$(az network public-ip list --resource-group $RESOURCE_GROUP --query "[?contains(name, '$PATTERN')].name" -o tsv)
    for PIP in $PUBLIC_IPS; do
        echo "Deleting Public IP: $PIP"
        az network public-ip delete --resource-group $RESOURCE_GROUP --name $PIP
    done

    echo "Deleting Disks..."
    DISKS=$(az disk list --resource-group $RESOURCE_GROUP --query "[?contains(name, '$PATTERN')].name" -o tsv)
    for DISK in $DISKS; do
        echo "Deleting Disk: $DISK"
        az disk delete --resource-group $RESOURCE_GROUP --name $DISK --yes --no-wait
    done

    echo "All resources matching pattern '$PATTERN' have been deleted."
}

auth_az
delete_resources