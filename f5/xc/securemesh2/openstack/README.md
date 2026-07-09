# SM v2.0 Infra Setup in Openstack

## Pre-requisites
This script requires below softwares in order to run the automation

`terraform ~> 1.5.0`

`jq ~> 1.6`

## Usage

- To install the infrastructure in openstack either in **hyd** or **sjc** cloud, run:

`install_openstack_ce.sh install <image_name> <ver-type> <site> <token>`

- To teardown the infrastructure in openstack:

`install_openstack_ce.sh destroy`

- **image_name**: Latest qcow2 image downloaded and uploaded to the openstack platform. This image should be availale before running the script
- **ver-type**: single, multi
- **site**: hyd or sjc
- **token**: Jwt site token

**E.g.,**

- To install an openstack cloud infrastructure with a single or multi node for CE deployment and testing run below:

  `./install_openstack_ce.sh install f5xc-ce-9.2025.17-20250422074005 single hyd eyJhbGciO............oeqoPFAF8zSCxr-cop7zrhReXQv8G41nzZ_g`
- To destroy and cleanup the single or multi node infra in openstack and resources created for testing.

  `install_openstack_ce.sh destroy`

---

## Setting up the credentials for openstack
This script works assuming the openstack credentials (olympus) are set on the shell level. 

```
export OS_USERNAME='dummy'
export OS_PASSWORD='dummy'
```

Once script is executed, it creates two files at `~/.config/openstack`

```
~/.config/openstack/clouds.yaml
~/.config/openstack/secure.yaml
```

- `clouds.yaml` - Contains the list of Openstack cloud providers and their spec
- `secure.yaml` - Contains the auth token generated for the session

**E.g.,**
```
$ cat ~/.config/openstack/clouds.yaml
clouds:
  os-xc-$site:
    auth:
      auth_url: https://hyd-cloud-keystone.hyd.pd.f5net.com:5000/v3
      project_domain_name: olympus
      project_name: f5xc-automation-testing
    indentity_api_version: "3"
    verify: false
```
**---**
```
$ cat ~/.config/openstack/secure.yaml
clouds:
  os-xc-$site:
    auth:
      token: gAAAAABmtF1BLgNniI9v1m5KDxEZpxOVGv9W3............RrUxCOGCNvZIAnwC3dROneDWeRYiJWGhWisjBfOTMBG5_A
    auth_type: token
```

## Customization of specs in Openstack

`terraform.tfvars` contains the default settings of a site as shown below:

```
$ cat terraform.tfvars
networks_list = ["Adminnetwork", "f5-xc-sli"]
cluster_count = 3
instance_flavor = "m1.xlarge"
image_name = "f5xc-ce-9.2025.17-20250422074005"
```

These default values for `networks_list` and `instance_flavor` can be customized according to the type of networks you would like to attach to your ce nodes along with the type of flavor respectively.

## Image uploads to OpenStack Hyd and SJC Instances:

**Instance URLs:**
  * HYD: https://hyd-xc-openstack.pdhyd.f5net.com
  * SJC: https://sjc-xc-openstack.pdsjc.f5net.com

**Pre-requisites to run the script:**

* OpenStack Cli  
    * Linux: 
    `pip3 install python-openstackclient`
    * Mac: 
    `brew install openstackclient`

* pv utility
    * Linux: 
    `apt install pv`
    * Mac: 
    `brew install pv`

**Script Usage:**

First set the OpenStack username and password variables as shown below. Make sure these credentials are working on Hyd and Sjc OpenStack instance.

```
export OS_USERNAME=service-user
export OS_PASSWORD='somepassword'
```

Go to XC Console, filter `OpenStack` CEs, `Copy Image Name` from the CE site options. It will copy the Image URL.

```
bash openstack_image_upload.sh <paste_image_url> <select openstack instance hyd or sjc>
```

E.g.,

```
bash  openstack_image_upload.sh  \
https://vesio.blob.core.windows.net/releases/rhel/9/x86_64/images/securemeshV2/f5xc-ce-crt-20250701-0107-9.2025.39-20250707054846.qcow2  \
sjc
```

**Sample Output**

```
2025-07-23 30:04:48 UTC | INFO | Image f5xc-ce-crt-20250701-0107-9.2025.39-20250707054846 does not exist in the sjc instance, downloading first.....
2025-07-23 30:04:48 UTC | INFO | Downloading image (~8300 MB)...
8.11GiB 0:05:22 [25.8MiB/s] [=====================================================================================================================================================================================================>] 100%
2025-07-23 36:04:11 UTC | INFO | Uploading image f5xc-ce-crt-20250701-0107-9.2025.39-20250707054846 to sjc....
[/] Uploading...
+------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Field            | Value                                                                                                                                                                                  |
+------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| container_format | bare                                                                                                                                                                                   |
| created_at       | 2025-07-23T04:36:13Z                                                                                                                                                                   |
| disk_format      | qcow2                                                                                                                                                                                  |
| file             | /v2/images/a5e8cae4-52b3-443d-b1c3-0acc0a449e40/file                                                                                                                                   |
| id               | a5e8cae4-52b3-443d-b1c3-0acc0a449e40                                                                                                                                                   |
| min_disk         | 0                                                                                                                                                                                      |
| min_ram          | 0                                                                                                                                                                                      |
| name             | f5xc-ce-crt-20250701-0107-9.2025.39-20250707054846                                                                                                                                     |
| owner            | 169b74dc979846308f79e2aa598bf4c4                                                                                                                                                       |
| properties       | os_hidden='False', owner_specified.openstack.md5='', owner_specified.openstack.object='images/f5xc-ce-crt-20250701-0107-9.2025.39-20250707054846', owner_specified.openstack.sha256='' |
| protected        | False                                                                                                                                                                                  |
| schema           | /v2/schemas/image                                                                                                                                                                      |
| status           | queued                                                                                                                                                                                 |
| tags             |                                                                                                                                                                                        |
| updated_at       | 2025-07-23T04:36:13Z                                                                                                                                                                   |
| visibility       | private                                                                                                                                                                                |
+------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
[✔] Upload complete.
2025-07-23 36:04:55 UTC | INFO | Image f5xc-ce-crt-20250701-0107-9.2025.39-20250707054846 uploaded successfully to sjc
```

**If Image already exists**

```
2025-07-23 39:38:12 UTC | INFO "Image f5xc-ce-crt-20250701-0107-9.2025.39-20250707054846 already exists in the sjc instance"
```

- Note: This script will first download the image to a fifo pipe and then upload to the remote instance.