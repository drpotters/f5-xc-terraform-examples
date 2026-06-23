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

Usage() {
local action=${1}
if [ "${action}" == "install" ];then
cat <<EOF
    Usage help for '${action}'

    if action == install:-
    Usage(): bash $0 install <image_name> <region> <site_type> <token>
    
    E.g.,
    * install  f5xc-ce-9.2024.44-20250102051113   us-phoenix-1  single|multi   <jwt-token> - Installs the infrastructure in the selected region in the OCI cloud
EOF
exit 1
elif [ "${action}" == "destroy" ];then
cat <<EOF
    Usage help for '${action}'
    Usage(): bash $0 destroy
    
    E.g.,
    * destroy - destroys the infrastructure in the selected region in the OCI cloud
EOF
exit 1
else
cat <<EOF
    Usage Help:

    if action == install:-
    Usage(): bash $0 install <image_name> <region> <site_type> <token>

    if action == destroy:-
    Usage(): bash $0 destroy

    * install  f5xc-ce-9.2024.44-20250102051113   us-phoenix-1   single|multi   <jwt-token> - Installs the infrastructure in the selected region in the OCI cloud
    * destroy - Destroys the infrastructure in the selected region in the OCI cloud
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

GenerateTFVars() {

cat <<EOF > ${install_dir}/terraform.tfvars
project_prefix          = "${project_prefix}"
instance_count          = "${vm_nodes}"
node_token              = "${token}"
region                  = "${region}"
f5xc_image_display_name = "${image_name}"
EOF

}

CreateSMInfrastructure() {
    CheckBasicRequirements
    Logger INFO "Selected Platform is : ${platform}"
    Logger INFO "Requested number of instances ${vm_nodes} will be created with the below specs in the ${platform}"
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
        ExitCall ERROR "Terraform execution failed to create the instances. Inspect the cluster in the ${platform} and cleanup the stale resources"
    fi
}

DestroySMInfrastructure() {
    local checkcall=$1
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
image_name=$2
region=$3
site_type=$4
token=$5
platform="oci"
shelluser=$(whoami | tr -cd '[:alnum:]')
if [ "${shelluser}" != "jenkins" ] && [ "${shelluser}" != "root" ];then
    project_prefix="${shelluser}"
else
    project_prefix="auto-sm2-oci"
fi

GetClusterEnv() {
case ${site_type} in
    multi)
        vm_nodes="3"
        ;;
    single)
        vm_nodes="1"
        ;;
    *)
        ExitCall ERROR "Invalid site_type. Input either single or multi"
        ;;
esac
}

case $action in
    install)
        if [ $# -lt 5 ];then
           Usage install
        fi
        GetClusterEnv
        GenerateTFVars
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