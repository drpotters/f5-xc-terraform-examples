# SM v2.0 Infra Setup in KVM

## Pre-requisites
This script requires to be run on a kvm host ( eg. seattle-slave-1 ) which achieves bringup of infra using qcow2 image
## To-Do
## This script has to be enabled such that it can be run from anywhere by having connectivity to a KVM host

## Usage

- To install the infrastructure in VMware:

`install_vmware_ce.sh <kvm_ova_image_name> <ver-type> <ce_name> <token>`

- To teardown the infrastructure in openstack:

`destroy_vmware_infra.sh destroy <ce_name> <ver-type>`

- **kvm_image_name**: Latest qcow2 image downloaded and uploaded to the KVM host ( Image name to be mentioned without the qcow2 extension ). This image should be availale before running the script
- **ver-type**: single, multi
- **ce_name**: ce site name
- **token**: Jwt site token

**E.g.,**

- To install an KVM infrastructure with a single or multi node for CE deployment and testing run below:

  `./install_vm.sh f5xc-ce-9.2024.44-20250102051113 test-sm2-kvm single eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzaXRlX25hbWUiOiJrdm0tdGVycmEtdGVzdCIsInRlbmFudF9uYW1lIjoiYXV0b21hdGlvbi1ybGxtYmJ1ZiIsInRva2VuX3V1aWQiOiIwYzEwOWIwNS01NzM3LTRlZjktOWY2YS1hZmIwYTcyOTRmNzkiLCJodHRwX3Byb3h5IjoiMTU5LjYwLjE0MC4xOTM6NDQzIiwicmVnaXN0cmF0aW9uX3VybCI6InN0YWdpbmcudm9sdGVycmEudXMiLCJpc3MiOiJGNSBYQyBTaXRlIE1hbmFnZXIiLCJzdWIiOiJGNSBYQyBTaXRlIFRva2VuIiwiZXhwIjoxNzIzMTIxNzk0LCJpYXQiOjE3MjMwMzUzOTR9.h-2oP6soeqoPFAF8zSCxr-cop7zrhReXQv8G41nzZ_g`
- To destroy and cleanup the single or multi node infra created for testing.

  `destroy_vmware_infra.sh single test-sm2-kvm`
