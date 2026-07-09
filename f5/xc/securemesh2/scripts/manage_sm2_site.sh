#/bin/bash

[ -z "${XC_API_TOKEN}" ] && ExitCall ERROR "XC_API_TOKEN is required"
[ -z "${XC_API_URL}" ] && ExitCall ERROR "XC_API_URL is required"
[ -z "${XC_TENANT_ID}" ] && ExitCall ERROR "XC_TENANT_ID is required"

Logger() {
    local logLevel="${1}"
    local logMessage="${2}"
    fullDate=$(date +'%Y-%m-%d %H:%M:%S %Z')
    printf "%s | %s | %s\n" "$fullDate" "$logLevel" "$logMessage" >&2
}

ExitCall() {
    local exitLevel="${1}"
    local exitMessage="${2}"
    fullDate=$(date +'%Y-%m-%d %H:%M:%S %Z')
    printf "%s | %s | %s\n" "$fullDate" "$exitLevel" "$exitMessage" >&2
    exit 1
}

Usage() {
local action="${1}"
if [ "${action}" == "create" ];then
cat <<EOF
    Usage(): $0 create <site_name> <env> <provider> <ver_type>
    
    E.g.,
    * $0  create  site-name  production  aws|azure|gcp  single|multi
EOF
exit 1
elif [ "${action}" == "delete" ];then
cat <<EOF
    Usage(): $0 delete <site_name> <env>

    E.g.,
    * $0  delete  site-name  production
EOF
exit 1
elif [ "${action}" == "status" ];then
cat <<EOF
    Usage(): $0 status <site_name> <env>

    E.g.,
    * $0  status  site-name  production
EOF
exit 1
elif [ "${action}" == "token" ];then
cat <<EOF
    Usage(): $0 token <site_name> <env>

    E.g.,
    * $0  token  site-name  production
EOF
exit 1
elif [ "${action}" == "deletetoken" ];then
cat <<EOF
    Usage(): $0 deletetoken <site_name> <env>

    E.g.,
    * $0  deletetoken  site-name  production
EOF
exit 1
else
cat <<EOF
    Usage(): bash $0 <action> <site_name> <env> <provider> <ver_type>

    E.g.,
    * To create a site object  ==> $0  create       site-name  production  aws|azure|gcp  single|multi
    * To delete a site object  ==> $0  delete       site-name  production
    * To check the site status ==> $0  status       site-name  production
    * To get the site token    ==> $0  token        site-name  production
    * To delete the site token ==> $0  deletetoken  site-name  production
EOF
exit 1
fi
}

GetEnvDetails() {
  case $env in
    production)
      api_url="${XC_API_URL}"
      tenant_id="${XC_TENANT_ID}"
      ;;
    *)
      ExitCall ERROR "Invalid environment. Enter production"
      ;;
  esac
}


CreateSM2SiteObject() {
    GetEnvDetails
    Logger INFO "Creating the site object ${site_name}"

    local ha_type=$([ "$ver_type" = "multi" ] && echo "enable_ha" || echo "disable_ha")

    sed -e "s/CLUSTER_NAME/$site_name/g" \
        -e "s/PROVIDER_NAME/$provider/g" \
        -e "s/HA_TYPE/$ha_type/g" \
        "${templates_dir}/site.json" > "${platform_dir}/create_site.json"

    sed -e "s/CLUSTER_NAME/$site_name/g" \
        "${templates_dir}/token.json" > "${platform_dir}/site_token.json"

    response=$(curl -sS -w "\n%{http_code}" -X POST \
      "https://${api_url}/api/config/namespaces/system/securemesh_site_v2s" \
      -H 'accept: application/json' \
      -H 'Authorization: APIToken '"$XC_API_TOKEN" \
      -H 'x-volterra-apigw-tenant: '"$tenant_id" \
      --data @"${platform_dir}/create_site.json")

    body=$(printf '%s' "$response" | sed '$d')
    http_code=$(printf '%s' "$response" | tail -n1)

    Logger INFO "Response body: ${body}"
    Logger INFO "HTTP status: ${http_code}"

    case "$http_code" in
      200|201|202|204)
        Logger INFO "Create site request completed (HTTP ${http_code}) for ${site_name}"
        return 0
        ;;
    esac

    if printf '%s' "$body" | jq -e . >/dev/null 2>&1; then
      api_code=$(printf '%s' "$body" | jq -r '.code // empty')
      api_msg=$(printf '%s' "$body" | jq -r '.message // .error // empty')
      ExitCall ERROR "Unable to create the site object ${site_name}. HTTP ${http_code}. API code: ${api_code}. Message: ${api_msg}"
    fi

    ExitCall ERROR "Unable to create the site object ${site_name}. HTTP ${http_code}. Response: ${body}"
}


GetSiteToken() {
    local token_type=$1
    if [ "${token_type}" = "token_only" ];then
       token_file="${install_dir}/${site_name}_site_token.json"
    else
       token_file="${platform_dir}/site_token.json"
    fi
      
    
    token=$(curl -s -X 'POST' \
      "https://${api_url}/api/register/namespaces/system/tokens" \
      -H 'accept: application/data' \
      -H 'Access-Control-Allow-Origin: *' \
      -H 'Authorization: APIToken '"$XC_API_TOKEN" \
      -H 'x-volterra-apigw-tenant: '"$tenant_id" \
      --data @${token_file} | jq -r '.spec.content')
    
    if [ ! -z "${token}" ] && [ "${token}" != "null" ]; then
       if [ "${token_type}" = "token_only" ];then
          echo -e "${token}"
       else 
          Logger INFO "Generating the site-token for the site : ${site_name}"
          echo -e "\nTOKEN:${token}"
       fi
    fi
}

DeleteSM2SiteObject() {
    GetEnvDetails
    Logger INFO "Deleting the site object ${site_name} and its associated token"

    response=$(curl -s -w "\n%{http_code}" -X 'DELETE' \
      "https://${api_url}/api/config/namespaces/system/securemesh_site_v2s/${site_name}" \
      -H 'accept: application/json' \
      -H 'Authorization: APIToken '"$XC_API_TOKEN" \
      -H 'x-volterra-apigw-tenant: '"$tenant_id")

    body=$(printf '%s' "$response" | sed '$d')
    body_code=$(printf '%s' "$response" | tail -n1 | awk 'match($0, /"code":[0-9]+,/) { print substr($0, RSTART+7, RLENGTH-8) }')
    exit_code=$(printf '%s' "$response" | tail -n1 )

  Logger INFO "Response ${response}"

    # Treat already-deleted/not-found as success for idempotency
    if [ "$body_code" = "200" ] || [ "$body_code" = "202" ] || [ "$body_code" = "204" ] || [ "$body_code" = "404" ] || [ "$exit_code" = "200" ] || [ "$exit_code" = "202" ] || [ "$exit_code" = "204" ] || [ "$exit_code" = "404" ]; then
      DeleteSiteToken
      Logger INFO "Delete site request completed (HTTP ${body_code}) ${exit_code} for ${site_name}"
      return 0
    fi

    Logger ERROR "Delete failed for ${site_name} (HTTP ${body_code}:${exit_code}). Response: ${body}"
    ExitCall ERROR "Unable to delete the site : ${site_name}. Response: ${body}. Remove manually from UI or SIA"
}

DeleteSiteToken() {
    Logger INFO "Deleting the site token"
    response=$(curl -s -X 'DELETE' \
      "https://${api_url}/api/register/namespaces/system/tokens/${site_name}" \
      -H 'accept: application/data' \
      -H 'Access-Control-Allow-Origin: *' \
      -H 'Authorization: APIToken '"$XC_API_TOKEN" \
      -H 'x-volterra-apigw-tenant: '"$tenant_id")
    
    body=$(printf '%s' "$response" | sed '$d')
    body_code=$(printf '%s' "$response" | tail -n1 | awk 'match($0, /"code":[0-9]+,/) { print substr($0, RSTART+7, RLENGTH-8) }')
    exit_code=$(printf '%s' "$response" | tail -n1 )

    # Treat already-deleted/not-found as success for idempotency
    if [ "$body_code" = "200" ] || [ "$body_code" = "202" ] || [ "$body_code" = "204" ] || [ "$body_code" = "404" ] || [ "$body_code" = "5" ] || [ "$exit_code" = "200" ] || [ "$exit_code" = "202" ] || [ "$exit_code" = "204" ] || [ "$exit_code" = "404" ] || [ "$exit_code" = "5" ]; then
      Logger INFO "Deleted site token with response (HTTP ${body_code}:${exit_code}) for ${site_name}"
      return 0
    fi

    Logger ERROR "Delete token failed for ${site_name} (HTTP ${code}). Response: ${body}"
    ExitCall ERROR "Unable to delete token for the site : ${site_name}. Remove it manually from UI or SIA"
}

GetSiteStatus() {
  GetEnvDetails # Retrieve the environment specific details before running the rest of the func() block
  max_attempts=5
  retry_delay=10
  attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    response=$(curl -s -X 'GET' \
        "https://${api_url}/api/config/namespaces/system/sites/${site_name}?response_format=GET_RSP_FORMAT_DEFAULT" \
        -H 'accept: application/data' \
        -H 'Access-Control-Allow-Origin: *' \
        -H 'Authorization: APIToken '"$XC_API_TOKEN" \
        -H 'x-volterra-apigw-tenant: '"$tenant_id")
    
    if [ -z "$response" ]; then
      Logger ERROR "Attempt $attempt/$max_attempts: Empty response received from API"
    elif ! printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
      Logger ERROR "Attempt $attempt/$max_attempts: Invalid JSON response: $response"
    else
      # Success - valid JSON response
      printf '%s' "$response" | jq -r '.spec.site_state'
      return 0
    fi
    
    # If we haven't returned yet, this attempt failed
    if [ $attempt -lt $max_attempts ]; then
      Logger INFO "Retrying in ${retry_delay} seconds..."
      sleep $retry_delay
    fi
    
    attempt=$((attempt + 1))
  done
  
  Logger ERROR "Failed to get site status after $max_attempts attempts"
  return 1
}

action=${1}
site_name=${2}
env=${3}
provider=${4}
ver_type=${5}
install_dir=$(dirname "$(realpath "$0")")
parent_dir=$(dirname "$install_dir")
platform_dir="${parent_dir}/${provider}"
templates_dir="${install_dir}/templates"

mkdir -p ${platform_dir}

if [ -z ${XC_API_TOKEN} ];then
  ExitCall ERROR "Export the 'XC_API_TOKEN' variable as a shell variable before running the script. export XC_API_TOKEN='xxxxxxxx'"
fi

case $action in
    create)
      if [ $# -lt 5 ];then
        Usage create
      fi
      CreateSM2SiteObject
      ;;
    delete)
      if [ $# -lt 3 ];then
        Usage delete
      fi
      DeleteSM2SiteObject
      ;;
    token)
      if [ $# -lt 3 ];then
        Usage token
      fi
      sed -e "s/CLUSTER_NAME/$site_name/g" ${templates_dir}/token.json > ${install_dir}/${site_name}_site_token.json
      GetEnvDetails
      DeleteSiteToken
      GetSiteToken token_only
      ;;
    deletetoken)
      if [ $# -lt 3 ];then
        Usage deletetoken
      fi
      GetEnvDetails
      DeleteSiteToken
      ;;
    status)
      if [ $# -lt 3 ];then
        Usage status
      fi
      GetSiteStatus
      ;;
    *)
      Usage
esac
