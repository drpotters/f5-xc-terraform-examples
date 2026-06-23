#!/bin/bash

# Get the api url of the user entered environment
GetEnvDetails() {
  case $env in
    production)
      api_url="customer1.console.ves.volterra.io"
      ;;
    *)
      echo "Invalid environment. Enter production"
      exit 1
      ;;
  esac
}

# Print and Delete sites function
ListAndDeleteSMSv2Sites() {

  # Get the api_url
  GetEnvDetails

  # Get all types of sites and filter their 'Name'
  listAllSites=$(curl -s -k -X GET \
  "https://${api_url}/api/config/namespaces/system/sites" \
  -H "Authorization: APIToken $API_TOKEN" \
  | jq -r '.items[] | .name')

  if [ "$action" == "--print" ];then
    printf "%-50s %-25s %-25s %-30s\n" "SiteName" "CRT Version" "Site Type" "SiteState"
    printf "%-50s %-25s %-25s %-30s\n" "--------" "-----------" "---------" "---------"
  fi

  for site in $listAllSites
  do
    siteSWAndState=$(curl -s -k -X GET \
    "https://${api_url}/api/config/namespaces/system/sites/${site}" \
    -H "Authorization: APIToken $API_TOKEN" \
    | jq -r '"\(.system_metadata.owner_view.kind) \(.spec.site_state) \(.spec.volterra_software_version)"')

    getSiteKind=$(echo $siteSWAndState | awk '{print $1}')
    getSiteState=$(echo $siteSWAndState | awk '{print $2}')
    getSiteCrtSWVersion=$(echo $siteSWAndState | awk '{print $3}')
    crtVersionConverted=$(echo $getSiteCrtSWVersion | sed 's/[^0-9]//g')

    # Statement to verify below conditions before deleting them
    # Site SW should be NULL
    # Site SW is older than the user input Benchmarked version 
    # Site is not in ONLINE state
    # If site satisfies the above conditions, it will be DELETED as per the logic
    if { [[ -z "$crtVersionConverted" ]] || (( crtVersionConverted < crtVersionBenchMarkConverted )); } \
   && [[ "$getSiteState" != "ONLINE" ]]; then
      case $action in
      # Safe statement to dry-run and verify the site details before calling the --delete
      --print)
          if [ "${getSiteKind}" != "null" ]; then
            printf "%-50s %-25s %-25s %-30s\n" "$site" "$getSiteCrtSWVersion" "$getSiteKind" "$getSiteState"
          fi
          ;;
      # Irreversible statement that removes the site from the environment
      --delete)
          echo -e "\nDeleting site ${site} with SW version '$getSiteCrtSWVersion' older than '$crtVersionBenchMark' \n"
          if [ "${getSiteKind}" != "null" ]; then
             curl -s -k -X DELETE \
             "https://${api_url}/api/config/namespaces/system/${getSiteKind}s/${site}" \
             -H "Authorization: APIToken $API_TOKEN"
          fi
          ;;
      *)
        echo "Invalid action. Action should be either '--print' or '--delete'"
        break
        exit 1
        ;;
      esac
    fi
  done

}

# API Token can be obtained in the XC Console --> Administration --> Credentials section
if [ -z ${API_TOKEN} ];then
  echo "export environment specific API_TOKEN before proceeding"
  exit 1
fi

# Script params
env=$1
crtVersionBenchMark=$2
action=$3

# This converts user input crt version to numeric version for comparison. crt-20241230-3083 ==> 202412303083
crtVersionBenchMarkConverted=$(echo $crtVersionBenchMark | sed 's/[^0-9]//g')

# Verify if three args are passed
if [ $# -lt 3 ];then
  echo -e "usage : $0 <env> <crt-version> <action>\n"
  echo -e "E.g., : $0 production crt-20241230-3083 --print"
  exit 1
fi

#List and delete sites with older CRT SW Version
ListAndDeleteSMSv2Sites