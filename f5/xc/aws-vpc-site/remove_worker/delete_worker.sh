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
Usage : bash $0 <action> <site_name> <env_name>

E.g.,
bash $0 status|delete myCESite production
EOF
exit 1
}

CheckBasicRequirement() {
    if [ -z ${API_TOKEN} ];then
      ExitCall ERROR "Export the 'API_TOKEN' variable as a shell variable before running the script. export API_TOKEN='xxxxxxxx'"
    fi
    
    isJqBinaryExist=$(jq --version >> /dev/null 2>&1; echo $?)

    if [ "$isJqBinaryExist" -ne 0 ];then
      ExitCall ERROR "The utility 'jq' not found. Install it before proceeding.."
    fi
}

GetEnvDetails() {
  case $env in
    production)
      api_url="customer1.console.ves.volterra.io"
      tenant_id="customer1"
      ;;
    *)
      ExitCall ERROR "Invalid environment. Enter production"
      ;;
  esac
}

CheckIfWorkersExist() {
  CheckBasicRequirement
  GetEnvDetails
  curl -s -X 'GET' \
    "https://${api_url}/api/config/namespaces/system/securemesh_site_v2s/${site_name}" \
    -H 'accept: application/data' \
    -H 'Access-Control-Allow-Origin: *' \
    -H 'Authorization: APIToken '"$API_TOKEN" \
    -H 'x-volterra-apigw-tenant: '"$tenant_id" > ${install_dir}/get_site_spec.json
    
    if [ `grep -c "does not exist" ${install_dir}/get_site_spec.json` -eq 1 ];then
       ExitCall ERROR "No such site '${site_name}' exist in the environment ${env}"
    fi
    
    # Extract the name of the provider of the site
    provider=$(jq -r '.spec | to_entries[] | select(.value | type == "object" and has("not_managed")) | .key' ${install_dir}/get_site_spec.json)

    if [ ! -z ${provider} ];then
       #this statement will check if the site has at least one worker node length > 
       doWorkersExist=$(jq ".spec[\"$provider\"].not_managed.node_list | map(select(.type == \"Worker\")) | length > 0" ${install_dir}/get_site_spec.json)
       echo "provider=${provider},workerNodes=${doWorkersExist}"
    fi
}

DeleteWorkerNode() {
    CheckBasicRequirement
    GetEnvDetails
    workerStatus=$(CheckIfWorkersExist)
    provider=$(echo ${workerStatus} | awk -F '[=,]' '{print $2}')
    Logger INFO "The provider type of the site '${site_name}' in the env '${env}' is : '${provider}'"
    if [ ! -z ${provider} ];then #proceeds only when provider is not empty
      # this statement will check if the site has at least one worker node length > 0
      doWorkersExist=$(echo ${workerStatus} | awk -F '[=,]' '{print $4}')
      if [ "${doWorkersExist}" = "true" ];then
        Logger INFO "Preparing a replace_site_spec.json file with no Worker nodes for the site '${site_name}' in the env '${env}'"
        #it will remove unwanted entries from the payload and keep necessary items
        jq '{metadata, spec}' ${install_dir}/get_site_spec.json \
        | jq 'del(.create_form, .deleted_referred_objects, .disabled_referred_objects, .metadata.annotations, .metadata.description, .metadata.disable, .metadata.labels, .referring_objects, .replace_form, .resource_version, .spec.admin_user_credentials)' \
        | jq ".spec[\"$provider\"].not_managed.node_list |= map(select(.type != \"Worker\"))" \
        > ${install_dir}/replace_site_spec.json
        Logger INFO "Replacing site '${site_name}' with no worker nodes"
        #finally, call the replace site api and removes all workers.
        curl -s -X 'PUT' \
        "https://${api_url}/api/config/namespaces/system/securemesh_site_v2s/${site_name}" \
        -H 'accept: application/data' \
        -H 'Access-Control-Allow-Origin: *' \
        -H 'Authorization: APIToken '"$API_TOKEN" \
        -H 'x-volterra-apigw-tenant: '"$tenant_id" \
        --data @${install_dir}/replace_site_spec.json
      else 
        ExitCall ERROR "The site '${site_name}' doesn't have any worker nodes in the environment '${env}'. Exiting.."
      fi
    else
      ExitCall ERROR "Unable to retrieve the provider info of the site '${site_name}'"
    fi
}

install_dir=$(dirname "$(realpath "$0")") # ~/aws/remove_worker directory
parent_dir=$(dirname "$install_dir") # ~/aws directory
action=${1}
site_name="${2}"
env="${3}"

if [ $# -lt 3 ];then
  Usage
fi

#Call for delete worker node
case $action in
  status)
      CheckIfWorkersExist
      ;;
  delete)
      DeleteWorkerNode
      ;;
  *)
      Usage
esac