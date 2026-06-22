# SM v2.0 Infra Setup in Oracle Cloud Infrastructure

## Pre-requisites
This script requires below softwares in order to run the automation

`terraform ~> 1.9.0`

`jq ~> 1.6`

## Image Upload

- Once the SecureMesh_v2 site object is created in the respective environment, download image (qcow2 file) from the site options.
- A bucket named `f5-xc-images` has already been created in both `us-phoenix-1` and `us-ashburn-1` regions.
- Upload the downloaded XC qcow2 file under `f5-xc-images` bucket.
- Create a compute image based on the qcow2 file uploaded to the bucket.
- Use the image's display name to install the compute nodes in the OCI

## Usage

- To install the infrastructure in OCI:

`install_oci_site.sh install <image_name> <region> <site-type> <token>`

- To teardown the infrastructure in azure:

`install_oci_site.sh destroy`

- **image_name**: Name of the image created in the previous section `Image Uplload`
- **site-type**: single, multi
- **regions**: us-phoenix-1, us-ashburn-1
- **token**: Jwt site token

**E.g.,**

- To install OCI cloud infrastructure with a single or multi nodes for CE deployment and testing run below:

  `install_oci_site.sh   install  f5xc-ce-9.2024.44-20250102051113  single|multi   us-phoenix-1   eyJhbGci.............8xf760YslToDmHmsil_3aIs`
- To destroy and cleanup the single or multi node infra in OCI and resources created for testing.

  `install_oci_site.sh   destroy`

---
This script works assuming the service account `xc_qa_automation_programmatic_access` credentials are configured on the `DEFAULT` profile in the `~/.oci/config` file

Format of `~/.oci/config` credentials file. Terraform uses the `DEFAULT` profile in the `provider.tf` file.

```
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaawnamx5rw7pewjleuy3ygp7yv64ampijm6eeevr7neowdgqn2ndlq
fingerprint=6a:0c:39:1c:52:c2:1f:42:71:a4:69:8f:d9:86:a4:d4
tenancy=ocid1.tenancy.oc1..aaaaaaaayo45gxzijq3435wiv7w2sntpse6idynga3ezo57tgflvlzr632sa
region=us-phoenix-1
key_file=<path to the private-key> #TODO
```