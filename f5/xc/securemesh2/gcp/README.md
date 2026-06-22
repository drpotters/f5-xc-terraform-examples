# SMSv2 Site From Google Cloud Marketplace

This module deploys a product from Google Cloud Marketplace.

## Pre-requisites
This script requires the below software in order to run the automation.

`terraform ~> 1.9.0`

`jq ~> 1.6`

## Configure a Service Account
In order to execute this module you must have a Service Account with the following project roles. (Ignore this if you already have a valid service account in your project)

- `roles/compute.admin`
- `roles/iam.serviceAccountUser`

If you are using a shared VPC:

- `roles/compute.networkAdmin` is required on the Shared VPC host project.

## Enable API
In order to operate with the Service Account you must activate the following APIs on the project where the Service Account was created:

- Compute Engine API - `compute.googleapis.com`


## Auth Using Service Account

Go to `GCP Console` Dashboard -> Browse your `Service Account` under `IAM` section -> Go to `KEYS` tab -> Add a `JSON` key and download it to your local.

In your bash shell prompt enter like below before running this terraform module.

```
export GOOGLE_APPLICATION_CREDENTIALS="<FULL PATH OF YOUR JSON FILE>" 
```

## Usage
Create GCP site object in the respective environment's XC Console as the first step.

* HA Disabled => Single Node site
* HA Enabled => Multi Node site

The site's GCP infra can be created by executing:

```
./install_gcp_site.sh <action> <image_name> <cluster_type> <token>
```
----
if **action** - `install` 

- **image_name** - Get the latest gcp image name from the site object options in the console. E.g., `f5xc-ce-9.2024.44-20250102052432`
- **cluster_type** - Type of the cluster - either `single` or `multi`
- **token** - Site node token from the site object options in the console.

E.g., Usage for `install`

``
./install_gcp_site.sh install f5xc-ce-9.2024.44-20250102052432 single eyJhbGc...ddeiyheuggg
``

---

if **action** - `destroy`, no further params are needed.

E.g., Usage for `destroy`

``
./install_gcp_site.sh destroy
``

## Automation Resource Details in GCP:

- Project_ID      : `vesio-dev-cz`
- SLO VPC Name    : `securemeshv2-automation-slo`
- SLO SubnetName  : `smv2-slo`
- SLO Subnet CIDR : `10.1.10.0/24`
- SLI VPC Name    : `securemeshv2-automation-sli`
- SLI SubnetName  : `smv2-sli`
- SLI Subnet CIDR : `10.2.20.0/24`
- Service Account : `xc-test-automation@vesio-dev-cz.iam.gserviceaccount.com`
- Network Tag     : `smv2`
- Region          : `us-east1`

## Misc

- Site will always be created in the `us-east1` region by default. A single node of a single-node CE will be created in the `us-east1-b` region. Three nodes of a multi-node CE will be created in `us-east1-b`, and `us-east1-d` regions respectively, to facilitate high availability.
- Site Local Outside and Inside networks have already been created with subnets, which will be used in this automation to avoid creating networks every time while running this automation.