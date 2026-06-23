#-----------------------------------------------------------------------------------#
# This cleanup job helps cleaning up the stale sm2 aws resources created            #
# through the automated jobs in jenkins and by any means they are aborted           #
# manually or due to some jenkins agents issues                                     #
# Version : v1.0                                                                    #
# author : Deviprasad Tummidi (d.tummidi@f5.com)                                    #
#-----------------------------------------------------------------------------------#

#!/bin/bash

AWS_REGION="${1}"
PATTERN="${2}"

if [ $# -lt 2 ];then
  echo "Expected two args - $0 <aws_region> <ec2_resource_pattern>"
  exit 1
fi

echo "Deleting EC2 instances matching pattern: $PATTERN in region: $AWS_REGION"
INSTANCE_IDS=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=*${PATTERN}*" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text \
    --no-paginate)

if [ -z "$INSTANCE_IDS" ]; then
    echo "No EC2 instances found matching pattern: $PATTERN"
else
    echo "Terminating EC2 instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region "$AWS_REGION" --no-cli-pager
    # Wait for instances to terminate
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region "$AWS_REGION"
    sleep 120
fi

echo "Deleting network interfaces matching pattern: $PATTERN in region: $AWS_REGION"
NETWORK_INTERFACE_IDS=$(aws ec2 describe-network-interfaces \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=*${PATTERN}*" \
    --query "NetworkInterfaces[].NetworkInterfaceId" \
    --output text)

if [ -z "$NETWORK_INTERFACE_IDS" ]; then
    echo "No network interfaces found matching pattern: $PATTERN"
else
    for ni in $NETWORK_INTERFACE_IDS; do
        echo "Deleting network interface: $ni"
        aws ec2 delete-network-interface --network-interface-id "$ni" --region "$AWS_REGION" --no-paginate
    done
    sleep 120
fi

echo "Deleting VPCs matching pattern: $PATTERN in region: $AWS_REGION"
VPC_IDS=$(aws ec2 describe-vpcs \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=*${PATTERN}*" \
    --query "Vpcs[].VpcId" \
    --output text)

if [ -z "$VPC_IDS" ]; then
    echo "No VPCs found matching pattern: $PATTERN"
else
    for vpc in $VPC_IDS; do
        echo "Deleting VPC: $vpc"
        SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" --query "Subnets[].SubnetId" --output text --region "$AWS_REGION")
        if [ ! -z "$SUBNET_IDS" ]; then
            for subnet in $SUBNET_IDS; do
                echo "Deleting subnet: $subnet"
                aws ec2 delete-subnet --subnet-id "$subnet" --region "$AWS_REGION" --no-paginate
            done
        fi
        IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc" --query "InternetGateways[].InternetGatewayId" --output text --region "$AWS_REGION")
        if [ ! -z "$IGW_ID" ]; then
            echo "Detaching and deleting internet gateway: $IGW_ID"
            aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$vpc" --region "$AWS_REGION"
            aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region "$AWS_REGION"
            sleep 120
        fi
        aws ec2 delete-vpc --vpc-id "$vpc" --region "$AWS_REGION"
    done
fi

echo "Cleanup completed in region: $AWS_REGION"