#!/bin/bash

# Variables
COMPARTMENT_ID="ocid1.compartment.oc1..aaaaaaaasg3gcrrxqv2o7au7otkzxtzcggs7zlycf5zr7al6siq7qxizwirq"
#MATCHING_PATTERN="auto-sm2-oci"

MATCHING_PATTERN="${1}"
REGION="${2}"

if [ $# -ne 2 ]; then
    echo "expected usage is : $0 <matching-pattern-of-vm> <region>"
    exit 1
fi

# Fetch instances with matching pattern
OCI_INSTANCES=$(oci compute instance list --profile DEFAULT --compartment-id "$COMPARTMENT_ID" --region "$REGION" \
    --query "data[?\"display-name\" && contains(\"display-name\", '$MATCHING_PATTERN') && \"lifecycle-state\" == 'RUNNING'].id")

INSTANCES=$(echo "$OCI_INSTANCES" | jq -r '.[]')

# Check if any instances match the pattern
if [ -z "$INSTANCES" ]; then
    echo "No matching instances found."
    exit 1
fi

# Terminate matching instances
for INSTANCE_ID in $INSTANCES; do
    echo "Terminating instance: $INSTANCE_ID"
    oci compute instance terminate --profile DEFAULT --instance-id "$INSTANCE_ID" --force
    echo "Instance $INSTANCE_ID terminated."
done

echo "All matching instances have been terminated."