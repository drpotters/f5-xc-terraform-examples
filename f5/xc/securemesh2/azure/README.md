# SM v2.0 Infra Setup in azure

## Pre-requisites
This script requires below softwares in order to run the automation

`terraform ~> 1.9.0`

`jq ~> 1.6`

## Usage

- To install the infrastructure in azure:

`install_azure_site.sh install <image_version> <ver-type> <region> <token>`

- To teardown the infrastructure in azure:

`install_azure_site.sh destroy`

- **image_version**: latest image version can be retrieved with the help of this command below
  ```
  az vm image list  --location eastus  --publisher f5-networks --offer f5xc_customer_edge --all --output table
  ```
- **ver-type**: single, multi
- **regions**: eastus, westus ..
- **token**: Jwt site token

**E.g.,**

- To install an azure cloud infrastructure with a single or multi node for CE deployment and testing run below:

  `install_azure_site.sh   install  20250701.0099.1  single|multi   eastus   eyJhbGci.............8xf760YslToDmHmsil_3aIs`
- To destroy and cleanup the single or multi node infra in azure and resources created for testing.

  `install_azure_site.sh   destroy`

---
This script works assuming the service account credentials of azure is called securely from vault or any secret management providers and set as environment variables.

**Setting up the credentials for azure:**

Install azure cli software in your mac or windows PC or linux vm where this automation is being executed.

Run `az login` and select the subscription to proceed. Terraform will use the `az login` context by default.