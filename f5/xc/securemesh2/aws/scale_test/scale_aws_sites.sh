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

cat <<EOF
    Usage():
    - scale: bash $0 scale <aws_scale_count> <ver_type> <aws_access_key> <aws_secret_key> <aws_region> <aws_ami_name> <environment>
    - destroy: bash $0 destroy
EOF
exit 1

}

GenerateTFVarsFile() {

cat <<EOF > ${script_dir}/terraform.tfvars

project_prefix     = "${project_prefix}"
ssh_public_key     = "${ssh_public_key}"

aws_site_count     = "${aws_site_count}"

master_node_count  = "${master_node_count}"
worker_node_count  = 0

# AWS
aws_access_key      = "${aws_access_key}"
aws_secret_key      = "${aws_secret_key}"
aws_owner_tag       = "${aws_owner_tag}"
aws_region          = "${aws_region}"
aws_vpc_cidr        = "10.0.0.0/16"
aws_availability_zones = [ "a", "b", "c"]
aws_slo_subnets     = [ "10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
aws_sli_subnets     = [ "10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

aws_ami_name        = "${aws_ami_name}"

f5xc_api_url         = "${f5xc_api_url}"
f5xc_api_token       = "${API_TOKEN}"
f5xc_tenant          = "${f5xc_tenant}"

EOF

}

RunScaleTest() {
	cd ${script_dir}
	rm -rf .terraform .terraform.lock.hcl .terraform.tfstate.lock.info terraform.tfstate.backup terraform.tfstate *.plan
	GenerateTFVarsFile
	terraform init
	terraform plan -out $$_terraform.plan
	terraform apply -auto-approve $$_terraform.plan -compact-warnings
    if [ `echo $?` -eq 0 ];then
        Logger INFO "Terraform execution has been successfully completed"
    else
        cd ${script_dir}
        terraform destroy -auto-approve
        rm -rf .terraform .terraform.lock.hcl .terraform.tfstate.lock.info terraform.tfstate.backup terraform.tfstate *.plan
        ExitCall ERROR "Error creating the instances, cleaning up the stale resources"
    fi
}

DestroyScaleInfra() {
	cd ${script_dir}
	terraform destroy -auto-approve
    if [ `echo $?` -eq 0 ];then
        Logger INFO "Infra has been destroyed successfully. Cleaning up the .tf files"
        rm -rf .terraform .terraform.lock.hcl .terraform.tfstate.lock.info terraform.tfstate.backup terraform.tfstate *.plan
    else
        rm -rf .terraform .terraform.lock.hcl .terraform.tfstate.lock.info terraform.tfstate.backup terraform.tfstate *.plan
        ExitCall ERROR "Error deleting the Infra. Cleanup the resources manually in the ${platform} platform."
    fi
}


GetEnvironment() {
case $cluster_type in
    multi)
        master_node_count="3"
        ;;
    single)
        master_node_count="1"
        ;;
    *)
        ExitCall ERROR "Invalid cluster_type. Input either single or multi"
        ;;
esac


case $environment in
    demo1)
      f5xc_api_url="https://testcorp.demo1.volterra.us/api"
      f5xc_tenant="testcorp-hagrmdbk"
      ;;
    crt)
      f5xc_api_url="https://customer1.crt.volterra.us/api"
      f5xc_tenant="customer1"
      ;;
    staging)
      f5xc_api_url="https://automation.staging.volterra.us/api"
      f5xc_tenant="automation-rllmbbuf"
      ;;
    production)
      f5xc_api_url="https://customer1.console.ves.volterra.io/api"
      f5xc_tenant="customer1"
      ;;
    *)
      ExitCall ERROR "Invalid environment. Enter demo1 | crt | staging | production"
      ;;
esac
}

#args
script_dir="$(dirname "$(realpath "$0")")"
random_string=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 3 | head -n 1 | awk '{print tolower($0)}')
project_prefix="autoscale-${random_string}"
ssh_public_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDaTEI7hgBratvOR0k3QnW4aeUT6djayqtPJvFk5dpwjXu/FPQu5gtv4mNdHiMlvu1E5jr9YlEpHve8fcEt/7YgfRQgw8vGIwAEd2H+cWpxFnWR7hoF32+2Zw1yEM0jIir/+7u7fa7axM6Vs1oB002jXyscafvEdd8H9gn0cZJegPLhyVde/6Ydcx7SwBspdI0HUKrqAcdNjWQF2Q+1n+RPDUp6I7REc/GvQKmUF0IxkVidXn3VY3/+HumhnPsxB0zbrL+SXQD85yyqmI/T3ormJZfHEECiLd1v4gBznivdn1A32G8sJopu4o9nlLHbHzWZuHEv51SxWEQi3JoGBuWjt/eyzZyB+jqmXT3sPpsu1Blvoxqtt97PYjTVEgOb/SFyCMEEYoOo1B0zAM1iV7EzIbTILNqbYk6Kdaaam6aoTvnZUsbK9NVOrfqaatiOyMK1zGMgFVw6k/F/ftkcaav6s5Ma8woIp/12iTMH9uTjT7kNdn9TV6k4zpYRqnUnrjE= d.tummidi@C02FFAVUMD6M"
aws_owner_tag="d.tummidi@f5.com"
action="${1}"
aws_site_count="${2}"
cluster_type="${3}"
aws_access_key="${4}"
aws_secret_key="${5}"
aws_region="${6}"
aws_ami_name="${7}"
environment="${8}"


if [ -z ${API_TOKEN} ];then
  ExitCall ERROR "Export the 'API_TOKEN' variable as a shell variable before running the script. export API_TOKEN='xxxxxxxx'"
fi

case $action in
    scale)
        if [ $# -lt 8 ];then
            Usage
        fi
        GetEnvironment
        RunScaleTest
        ;;
    destroy)
        if [ $# -lt 1 ];then
            Usage
        fi
        DestroyScaleInfra
        ;;
    *)
        ExitCall ERROR "Invalid action. Input either 'scale' or 'destroy'"
        ;;
esac