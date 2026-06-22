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
    Usage(): bash $0 install <image_name> <ver-type> <site> <token>
    
    E.g.,
    * install  f5xc-ce-9.2025.17-20250422074005  single|multi  hyd|sjc  <token-uid> - Installs the infrastructure in the openstack cloud
EOF
exit 1
elif [ "${action}" == "destroy" ];then
cat <<EOF
    Usage help for '${action}'
    Usage(): bash $0 destroy
    
    E.g.,
    * destroy - destroys the infrastructure in the openstack cloud
EOF
exit 1
else
cat <<EOF
    Usage Help:

    if action == install:-
    Usage(): bash $0 install <image_name> <ver-type> <site> <token>

    if action == destroy:-
    Usage(): bash $0 destroy

    * install  f5xc-ce-9.2025.17-20250422074005  single|multi  hyd|sjc  <token-uid> - Installs the infrastructure in the openstack cloud
    * destroy - Destroys the infrastructure in the openstack cloud
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
node_prefix    = "${project_prefix}"
cloud_name     = "os-xc-${site}"
cluster_count  = "${vm_nodes}"
image_name     = "${image_name}"
cluster_token  = "${token}"
EOF

}

CreateSMInfrastructure() {
    CheckPlatformDir
    CheckBasicRequirements
    GenerateTFVars
    Logger INFO "Selected OpenStack Site is : $site - ${OS_AUTH_URL}"
    Logger INFO "Requested number of instances ${vm_nodes} will be created with the below specs in the ${platform}"
    cd ${install_dir}
    rm -rf .terraform .terraform.lock.hcl .terraform.tfstate.lock.info terraform.tfstate.backup terraform.tfstate *.plan
    terraform init
    terraform plan -out $$_terraform.plan
    terraform apply -parallelism=1 -auto-approve $$_terraform.plan -compact-warnings
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

GetOpenStackAuth() {

#Expecting OS_USERNAME and OS_PASSWORD are set on the shell level
if [[ -z $OS_USERNAME && -z $OS_PASSWORD ]]; then
	ExitCall ERROR "export openstack username 'OS_USERNAME' and password 'OS_PASSWORD' variables" 
fi

#Looking for openstack cli
isOpenStackCliWorks=$(openstack --version >> /dev/null 2>&1; echo $?)
if [ "$isOpenStackCliWorks" -ne 0 ];then
    ExitCall ERROR "openstack cli is not installed. 'pip install python-openstackclient' and proceed"
fi

#Generating the openstack token based on the ENV variables set above
OS_TOKEN=$(openstack --insecure token issue -f value -c id)

#Creating the clouds.yaml and secure.yaml files to feed to terraform
mkdir -p ${HOME}/.config/openstack

cat <<EOF > ${HOME}/.config/openstack/clouds.yaml
clouds:
  os-xc-$site:
    auth:
      auth_url: ${OS_AUTH_URL}/v3
      project_domain_name: ${OS_PROJECT_DOMAIN_NAME}
      project_name: ${OS_PROJECT_NAME}
    indentity_api_version: "${OS_IDENTITY_API_VERSION}"
    verify: false
EOF

cat <<EOF > ${HOME}/.config/openstack/secure.yaml
clouds:
  os-xc-$site:
    auth:
      token: ${OS_TOKEN}
    auth_type: token
EOF
}

tf_min_version="1.9.0"
install_dir=$(dirname "$(realpath "$0")")
action=$1
image_name=$2
ver_type=$3
site=$4
token=$5
platform="openstack"
shelluser=$(whoami | tr -cd '[:alnum:]')
if [ "${shelluser}" != "jenkins" ] && [ "${shelluser}" != "root" ];then
    project_prefix="${shelluser}"
else
    project_prefix="auto-os"
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

case $site in
    hyd)
        export OS_AUTH_URL=http://hyd-xc-openstack.pdhyd.f5net.com:5000
        export OS_PROJECT_NAME="f5xc-automation-testing"
        export OS_PROJECT_DOMAIN_NAME="olympus"
        export OS_IDENTITY_API_VERSION=3
        export OS_PROJECT_DOMAIN_ID="6b150b090f6944dd8120cfe7ba1a8af2"
        export OS_USER_DOMAIN_ID="6b150b090f6944dd8120cfe7ba1a8af2"
        ;;
    sjc)
        export OS_AUTH_URL=https://sjc-xc-openstack.pdsjc.f5net.com:5000
        export OS_PROJECT_NAME="f5xc-automation-testing"
        export OS_PROJECT_DOMAIN_NAME="olympus"
        export OS_IDENTITY_API_VERSION=3
        export OS_PROJECT_DOMAIN_ID="909b362b3cc34e4da573e3a41c68b03f"
        export OS_USER_DOMAIN_ID="909b362b3cc34e4da573e3a41c68b03f"
        ;;
    *) 
        ExitCall ERROR "Invalid site '$site'. Allowed values are 'hyd' or 'sjc'."
        ;;
esac
}

case $action in
    install)
        if [ $# -lt 5 ];then
           Usage install
        fi
        GetClusterEnv
        GetOpenStackAuth
        CreateSMInfrastructure
        ;;
    destroy)
        if [ $# -lt 1 ];then
           Usage destroy
        fi
        ver_type="single" #dummy value
        site=$(cat ${install_dir}/terraform.tfvars | grep cloud_name | cut -d '=' -f2 | sed 's/.*-//; s/"//g' | xargs)
        GetClusterEnv
        GetOpenStackAuth
        DestroySMInfrastructure
        ;;
    *)
        Usage
        ;;
esac