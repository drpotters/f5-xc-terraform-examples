#/bin/bash

Logger() {
    local logLevel="${1}"
    local logMessage="${2}"
    fullDate=$(date +'%Y-%m-%d %M:%H:%S %Z')
    printf "${fullDate} | ${logLevel} | ${logMessage}\n"
}

ExitCall() {
    local exitLevel="${1}"
    local exitMessage="${2}"
    fullDate=$(date +'%Y-%m-%d %M:%H:%S %Z')
    printf "${fullDate} | ${exitLevel} | ${exitMessage}\n"
    exit 1
}

Usage() {
cat <<EOF
    Usage Help:

    * create  - adds additional interfaces to each node
    * destroy - destroys all the interfaces created using this script only
EOF
exit 1
}

LookForRequiredCLI() {
    #Looking for the installed AWS CLI
    if command -v aws &> /dev/null; then
       awsCliVersion=$(aws --version | awk '{print $1}' | awk -F'/' '{print $2}')
       installedVersion=$(echo ${awsCliVersion} | awk -F'.' '{print $1$2}')
       requiredVersion=$(echo ${recommendAWSCliVersion} | awk -F'.' '{print $1$2}')
       if [ $installedVersion -lt $requiredVersion ];then
          ExitCall ERROR "AWS CLI version - ${awsCliVersion} is not compatible"
       else
          Logger INFO "Found compatible AWS CLI version"
       fi
    else
       ExitCall ERROR "AWS CLI not found. Exiting..."
    fi

    #Looking for jq binary
    isJqBinaryExist=$(jq --version >> /dev/null 2>&1; echo $?)
    if [ "$isJqBinaryExist" -ne 0 ];then
      ExitCall ERROR "The utility 'jq' not found. Install it before proceeding.."
    else 
      Logger INFO "Jq binary found"
    fi
}

ReadTFVars() {
Logger INFO "Reading the state file found at ${parent_dir}/terraform.tfstate"
region=$(cd ${parent_dir} && cat terraform.tfvars | grep region | tr -d ' ' | sed 's/region="\(.*\)"/\1/')
sm_security_group=$(cd ${parent_dir} && terraform state show aws_security_group.sm_sg | grep -w id |  tr -d ' ' | sed 's/id="\(.*\)"/\1/')
nodes="$(cd ${parent_dir} && terraform output sm_instance_ids | awk -F'"' '/"/ {print $2}')"
}

AddNewInterfaceToNodes() {
    if [ -f ${parent_dir}/terraform.tfstate ];then
        ReadTFVars
        for node in $nodes; do 
           Logger INFO "Working on the Node : ${node}"
           nodeSubnetId=$(aws ec2 describe-instances \
           --instance-ids ${node} \
           --region ${region} \
           --query "Reservations[].Instances[].SubnetId" \
           --output text)
           Logger INFO "Creating a new interface on the subnet - ${nodeSubnetId}"
           networkInterfaceeniId=$(aws ec2 create-network-interface \
           --subnet-id ${nodeSubnetId} \
           --groups ${sm_security_group} \
           --region ${region} | jq -r '.NetworkInterface.NetworkInterfaceId')
           echo ${networkInterfaceeniId} >> ${parent_dir}/.addInterfaces
           Logger INFO "Shutting down the instance ${node} before attaching the interface"
           aws ec2 stop-instances \
           --instance-ids  ${node} \
           --region ${region} \
           && aws ec2 wait instance-stopped \
           --instance-ids ${node} \
           --region ${region}
           Logger INFO "Attaching interface : ${networkInterfaceeniId} to the node ${node}"
           aws ec2 attach-network-interface \
           --network-interface-id ${networkInterfaceeniId} \
           --instance-id ${node} \
           --device-index 2 \
           --region ${region}
           status=$(echo $?)
           if [ $status -ne 0 ];then
              ExitCall ERROR "Failed to attach interface ${networkInterfaceeniId} to the node ${node}"
           else 
              Logger INFO "Successfully attached the interface ${networkInterfaceeniId} to the node ${node}"
              echo ' '
           fi
           Logger INFO "Starting ec2 node: ${node}"
           aws ec2 start-instances \
           --instance-ids ${node} \
           --region ${region}
        done
    else
        ExitCall ERROR "terraform statefile not found in the parent directory to add a new worker node"
    fi
}

DestroyAdditionalInterfaces() {
    ReadTFVars
    Logger INFO "Shutting down nodes before detaching interface"
    for node in $nodes; do 
      aws ec2 stop-instances \
      --instance-ids  ${node} \
      --region ${region} \
      && aws ec2 wait instance-stopped \
      --instance-ids ${node} \
      --region ${region}
    done
    Logger INFO "Removing the interfaces created using this script"
    for eniId in $(cat ${parent_dir}/.addInterfaces); do
       # Detach the network interface of stored ENI IDs
       AttachmentId=$(aws ec2 describe-network-interfaces \
       --network-interface-ids $eniId \
       --region ${region} \
       --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
       --output text)
       if [ ! -z "$AttachmentId" ]; then
          Logger INFO "Detaching network interface $eniId with attachment $AttachmentId..."
          aws ec2 detach-network-interface --region ${region} --attachment-id $AttachmentId
          Logger INFO "Waiting for detachment to complete..."
          while [[ "$(aws ec2 describe-network-interfaces --region ${region} --network-interface-ids $eniId --query    'NetworkInterfaces[0].Status' --output text)" == "in-use" ]]; do
            sleep 3
          done
          # Delete the network interface of stored ENI IDs
          Logger INFO "Deleting network interface $eniId..."
          aws ec2 delete-network-interface --region ${region} --network-interface-id $eniId
          Logger INFO "Network interface $eniId deleted."
       fi
    done
    Logger INFO "Starting nodes after detaching interface action completed"
    for node in $nodes; do 
      aws ec2 start-instances \
      --instance-ids ${node} \
      --region ${region}
    done
    rm -rf ${parent_dir}/.addInterfaces
}

install_dir=$(dirname "$(realpath "$0")") # ~/aws/add_worker directory
parent_dir=$(dirname "$install_dir") # ~/aws directory
recommendAWSCliVersion="2.15" # Suggested to have AWS CLI version > 2.15
action=${1}

if [ $# -lt 1 ];then
    Usage
fi

case $action in
    create)
        LookForRequiredCLI
        AddNewInterfaceToNodes
        ;;
    destroy)
        LookForRequiredCLI
        DestroyAdditionalInterfaces
        ;;
    *)
        Usage
        ;;
esac