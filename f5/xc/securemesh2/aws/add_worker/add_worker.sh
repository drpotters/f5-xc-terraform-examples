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
local action="${1}"
if [ "${action}" == "install" ];then
cat <<EOF
    Usage help for '${action}'

    if action == install:-
    Usage(): bash $0 install <workers_count> <jwt_token>
    
    E.g.,
    * install 2 token - creates two worker ec2 to an existing site
EOF
exit 1
elif [ "${action}" == "destroy" ];then
cat <<EOF
    Usage help for '${action}'
    Usage(): bash $0 destroy
    
    E.g.,
    * destroy - destroys the workers created
EOF
exit 1
else
cat <<EOF
    Usage Help:

    if action == install:-
    Usage(): bash $0 install <workers_count> <jwt_token>

    if action == destroy:-
    Usage(): bash $0 destroy

    * install 2 token - creates two more worker ec2 to an existing site
    * destroy - destroys the workers created
EOF
exit 1
fi
}

GenerateWorkerNodeTFVars() {
Logger INFO "Reading the state file found at ${parent_dir}/terraform.tfstate"
cat <<EOF > ${install_dir}/terraform.tfvars
prefix              = "$(cd ${parent_dir} && cat terraform.tfvars | grep prefix | tr -d ' ' | sed 's/prefix="\(.*\)"/\1/')"
region              = "$(cd ${parent_dir} && cat terraform.tfvars | grep region | tr -d ' ' | sed 's/region="\(.*\)"/\1/')"
slo_subnet_id       = "$(cd ${parent_dir} && terraform state show aws_subnet.sm_public_subnet[0] | grep -w id | tr -d ' ' | sed 's/id="\(.*\)"/\1/')"
sli_subnet_id       = "$(cd ${parent_dir} && terraform state show aws_subnet.sm_private_subnet[0] | grep -w id | tr -d ' ' | sed 's/id="\(.*\)"/\1/')"
ec2_workers_count   = "${workers_count}"
sm_security_group   = "$(cd ${parent_dir} && terraform state show aws_security_group.sm_sg | grep -w id |  tr -d ' ' | sed 's/id="\(.*\)"/\1/')"
ami_name            = "$(cd ${parent_dir} && cat terraform.tfvars | grep ami_name | tr -d ' ' | sed 's/ami_name="\(.*\)"/\1/')"
cluster_token       = "${token}"
randomid            = "$(cd ${parent_dir} && terraform state show random_id.rand_id | grep hex | tr -d ' ' | sed 's/hex="\(.*\)"/\1/')"
env                 = "$(cd ${parent_dir} && cat terraform.tfvars | grep env | tr -d ' ' | sed 's/env="\(.*\)"/\1/')"
user_email          = "$(cd ${parent_dir} && cat terraform.tfvars | grep user_email | tr -d ' ' | sed 's/user_email="\(.*\)"/\1/')"
user_costcenter     = "$(cd ${parent_dir} && cat terraform.tfvars | grep user_costcenter | tr -d ' ' | sed 's/user_costcenter="\(.*\)"/\1/')"
user_manager        = "$(cd ${parent_dir} && cat terraform.tfvars | grep user_manager | tr -d ' ' | sed 's/user_manager="\(.*\)"/\1/')"
user_team           = "$(cd ${parent_dir} && cat terraform.tfvars | grep user_team | tr -d ' ' | sed 's/user_team="\(.*\)"/\1/')"
EOF
}

CreateWorkerNodes() {
    if [ -f ${parent_dir}/terraform.tfstate ];then
        GenerateWorkerNodeTFVars
        Logger INFO "Requested number of workers ${workers_count} will be created with the below specs in the ${platform}/add_worker"
        cd ${install_dir}
        rm -rf .terraform .terraform.lock.hcl .terraform.tfstate.lock.info terraform.tfstate.backup terraform.tfstate *.plan
        terraform init
        terraform plan -out $$_terraform.plan
        terraform apply -auto-approve $$_terraform.plan -compact-warnings
        if [ `echo $?` -eq 0 ];then
            Logger INFO "Terraform execution has been successfully completed"
        else
            Logger ERROR "Error creating the instances, cleaning up the stale resources"
            DestroyWorkerNodes
        fi
    else
        ExitCall ERROR "terraform statefile not found in the parent directory to add a new worker node"
    fi
}

DestroyWorkerNodes() {
    Logger INFO "Destroying the infra from the local statefile"
    cd ${install_dir}
    terraform destroy -auto-approve
    if [ `echo $?` -eq 0 ];then
        Logger INFO "Infra has been destroyed successfully. Cleaning up the .tf files"
        rm -rf .terraform .terraform.lock.hcl .terraform.tfstate.lock.info terraform.tfstate.backup terraform.tfstate *.plan
    else
        rm -rf .terraform .terraform.lock.hcl .terraform.tfstate.lock.info terraform.tfstate.backup terraform.tfstate *.plan
        ExitCall ERROR "Error deleting the Infra. Cleanup the resources manually in the ${platform}/add_worker platform."
    fi
}

install_dir=$(dirname "$(realpath "$0")") # ~/aws/add_worker directory
parent_dir=$(dirname "$install_dir") # ~/aws directory
platform="aws"
action=${1}
workers_count=${2}
token=${3}

case $action in
    install)
        if [ $# -lt 3 ];then
           Usage install
        fi
        CreateWorkerNodes
        ;;
    destroy)
        if [ $# -lt 1 ];then
           Usage destroy
        fi
        DestroyWorkerNodes
        ;;
    *)
        Usage
        ;;
esac