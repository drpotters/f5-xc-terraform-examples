#!/bin/bash

script_dir="$(dirname "$(realpath "$0")")"
site_name_filter=$(grep ^project_prefix ${script_dir}/terraform.tfvars | cut -d\" -f2)
f5xc_api_url=$(grep ^f5xc_api_url ${script_dir}/terraform.tfvars | cut -d\" -f2)
f5xc_tenant=$(grep ^f5xc_tenant ${script_dir}/terraform.tfvars | cut -d\" -f2)
api_token=$(grep ^f5xc_api_token ${script_dir}/terraform.tfvars | cut -d\" -f2)
aws_region=$(grep ^aws_region ${script_dir}/terraform.tfvars | cut -d\" -f2)
aws_ami_name=$(grep ^aws_ami_name ${script_dir}/terraform.tfvars | cut -d\" -f2)
master_node_count=$(grep ^master_node_count ${script_dir}/terraform.tfvars | cut -d= -f2)
aws_site_count=$(grep ^aws_site_count ${script_dir}/terraform.tfvars | cut -d= -f2)

start_time=$(date -u)
SECONDS=0

echo "minutes,total,waiting_for_registration,provisioning,upgrading,online"

while true; do

  sites=$(curl -s -X 'GET' \
    "$f5xc_api_url/config/namespaces/system/sites?response_format=GET_RSP_FORMAT_DEFAULT" \
    -H 'accept: application/data' \
    -H 'Access-Control-Allow-Origin: *' \
    -H 'Authorization: APIToken '"$api_token" \
    -H 'x-volterra-apigw-tenant: '"$f5xc_tenant" | jq -r '.items[].name' | grep $site_name_filter)

  status_total=0
  status_online=0
  status_provisioning=0
  status_upgrading=0
  status_waiting_for_registration=0

  for site in $sites; do
    status=$(curl -s -X 'GET' \
      "$f5xc_api_url/config/namespaces/system/sites/$site?response_format=GET_RSP_FORMAT_DEFAULT" \
      -H 'accept: application/data' \
      -H 'Access-Control-Allow-Origin: *' \
      -H 'Authorization: APIToken '"$api_token" \
      -H 'x-volterra-apigw-tenant: '"$f5xc_tenant" | jq -r '.spec.site_state')

    ((status_total++))
    if [ "$status" == "ONLINE" ]; then ((status_online++)); fi
    if [ "$status" == "PROVISIONING" ]; then ((status_provisioning++)); fi
    if [ "$status" == "UPGRADING" ]; then ((status_upgrading++)); fi
    if [ "$status" == "WAITING_FOR_REGISTRATION" ]; then ((status_waiting_for_registration++)); fi
  done

  minutes=$(echo "scale=1; $SECONDS / 60" | bc)

  #Once the sites are scaled, this will only collect the status of the sites in given time (approx ~45min) 
  echo "$minutes,$status_total,$status_waiting_for_registration,$status_provisioning,$status_upgrading,$status_online"

  sleep 30
done
