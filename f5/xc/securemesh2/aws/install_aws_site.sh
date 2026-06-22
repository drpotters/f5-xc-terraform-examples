#!/bin/bash

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
local action="${1}"
if [ "${action}" == "install" ];then
cat <<EOF
    Usage help for '${action}'

    if action == install:-
    Usage(): bash $0 install <ami_image_name> <ver-type> <region> <token>
    
    E.g.,
    * install  f5xc-ce-9.2024.22-20240807192140  single|multi  us-west-1|us-west-2  <jwt-token> - Installs the infrastructure in the selected region in the aws cloud
EOF
exit 1
elif [ "${action}" == "destroy" ];then
cat <<EOF
    Usage help for '${action}'
    Usage(): bash $0 destroy
    
    E.g.,
    * destroy - destroys the infrastructure in the selected region in the aws cloud
EOF
exit 1
else
cat <<EOF
    Usage Help:

    if action == install:-
    Usage(): bash $0 install <ami_image_name> <ver-type> <region> <token>

    if action == destroy:-
    Usage(): bash $0 destroy

    * install  f5xc-ce-9.2024.22-20240807192140  single|multi  us-west-1|us-west-2  <jwt-token> - Installs the infrastructure in the selected region in the aws cloud
    * destroy - Destroys the infrastructure in the selected region in the aws cloud
EOF
exit 1
fi
}

CheckBasicRequirements() {
    Logger INFO "Reviewing the setup of basic tools and their compatibility viz., terraform"
    if [ `echo $(terraform version) | head -1 | cut -d " " -f1` == "Terraform" ]; then
        tf_version=$(echo $(terraform version) | head -1 | cut -d " " -f2 | tr -d "v")
        trim_tf_version=$(echo $tf_version | sed -e 's/\.//g')
        trim_tf_min_version=$(echo $tf_min_version | sed -e 's/\.//g')
        if [ $trim_tf_version -lt $trim_tf_min_version ]; then
            ExitCall ERROR "Terraform version v$tf_version is NOT compatible"
        else
            Logger INFO "Terraform installed version v$tf_version is compatible. Proceeding.."
        fi
    else
        ExitCall ERROR "Terraform has NOT been found. Please install the Terraform version > ${tf_min_version} and proceed, exiting.."
    fi
    
    Logger INFO "Checking if the required terraform files are cloned to the current directory $PWD"
    [ ! -f ${install_dir}/main.tf ] && ExitCall ERROR "'${install_dir}' has NO valid terraform files found, exiting.."

}

CheckPlatformDir(){
    if [ ! -d ${install_dir} ];then
        ExitCall ERROR "There is no platform directory '${install_dir}' exists. Please check the platform and try again"
    fi
}

GenerateTFVars() {

cat <<EOF > ${install_dir}/terraform.tfvars
prefix                     = "${project_prefix}"
ec2_instances_count        = "${vm_nodes}"
ec2_azs                    = $av_zones
region                     = "${region}"
ami_name                   = "${ami_name}"
cluster_token              = "${token}"
env                        = "${environment}"
user_email                 = "${user_email}"
user_costcenter            = "${user_costcenter}"
user_manager               = "${user_manager}"
user_team                  = "${user_team}"
client_ec2_instances_count = "${clients}"
server_ec2_instances_count = "${servers}"
EOF

}

CreateSMInfrastructure() {
    CheckPlatformDir
    CheckBasicRequirements
    GenerateTFVars
    Logger INFO "Selected Platform is : ${platform}"
    Logger INFO "Requested number of CE nodes ${vm_nodes} will be created in the ${region} region with the AMI image ${ami_name}"
    if [ ${clients} -gt 0 ]; then
        Logger INFO "Client VM's count: ${clients}"
        Logger INFO "Server VM's count: ${servers}"
    fi
    cd ${install_dir}
    rm -rf .terraform .terraform.lock.hcl .terraform.tfstate.lock.info terraform.tfstate.backup terraform.tfstate *.plan
    terraform init
    terraform plan -out $$_terraform.plan
    terraform apply -auto-approve $$_terraform.plan -compact-warnings
    if [ `echo $?` -eq 0 ];then
        Logger INFO "Terraform execution has been successfully completed"
    else
        Logger ERROR "Error creating the instances, cleaning up the stale resources"
        DestroySMInfrastructure skipcheck
        ExitCall ERROR "Terraform execution failed to create the instances."
    fi
}

DestroySMInfrastructure() {
    local checkcall=$1
    CheckPlatformDir
    [ -z ${checkcall} ] && CheckBasicRequirements
    Logger INFO "Destroying the infra from the local statefile"
    cd ${install_dir}
    terraform destroy -auto-approve
    if [ `echo $?` -eq 0 ];then
        Logger INFO "Infra has been destroyed successfully. Cleaning up the .tf files"
        rm -rf .terraform .terraform.lock.hcl .terraform.tfstate.lock.info terraform.tfstate.backup terraform.tfstate *.plan
    else
        rm -rf .terraform .terraform.lock.hcl .terraform.tfstate.lock.info terraform.tfstate.backup terraform.tfstate *.plan
        ExitCall ERROR "Error deleting the Infra. Cleanup the resources manually in the ${platform} platform."
    fi
}

tf_min_version="1.9.0"
install_dir=$(dirname "$(realpath "$0")")
action=$1
ami_name=$2
ver_type=$3
region=$4
token=$5
#default value for clients is set to 0, if --clientserver flag is not passed in the input. This will create only CE instances as part of the infrastructure.
clients=0 
servers=0

if [ "$6" == "--clientserver" ]; then
    if [[ "$7" =~ ^[1-3]$ ]]; then
        clients="$7"
        servers="$7"
    else
        ExitCall ERROR " --clientserver must be followed by 1, 2, or 3"
    fi
fi

platform="aws"
shelluser=$(whoami)
if [ "${shelluser}" != "jenkins" ] && [ "${shelluser}" != "root" ];then
    project_prefix=$(whoami | tr -cd '[:alnum:]')
    user_email="${shelluser}@f5.com"
    user_costcenter="7929"
    user_manager="${shelluser}@f5.com"
    user_team="XC Dev/Test"
else
    project_prefix="qa-sm2"
    user_email="prdf5xc-qa@f5.com"
    user_costcenter="7929"
    user_manager="prdf5xc-qa@f5.com"
    user_team="XC QA"
fi

#Extracting target environment from JWT token input to this script
jwt_payload=$(echo $token | cut -d "." -f2)
environment=$(echo $jwt_payload | tr '_-' '/+' | sed 's/[^=]$/&===/' | base64 --decode 2>/dev/null | jq '.registration_url' | tr -d '"' | awk -F '.' '{print $1}')

if [ ! -z ${install_dir}/regions.json ];then
    av_zones_raw=$(jq --arg platform "$platform" --arg region "$region" --arg key "$key" '.cloud[$platform].regions[$region].av_zones' ${install_dir}/regions.json)
    av_zones=$(echo "$av_zones_raw" | tr -d '[:space:]')
fi

GetClusterEnv() {
case $ver_type in
    multi)
        vm_nodes="3"
        ;;
    single)
        vm_nodes="1"
        ;;
    *)
        ExitCall ERROR "Invalid ver_type. Input either single or multi"
        ;;
esac
}

case $action in
    install)
        if [ $# -lt 5 ];then
           Usage install
        fi
        GetClusterEnv
        CreateSMInfrastructure
        ;;
    destroy)
        if [ $# -lt 1 ];then
           Usage destroy
        fi
        DestroySMInfrastructure
        ;;
    *)
        Usage
        ;;
esac