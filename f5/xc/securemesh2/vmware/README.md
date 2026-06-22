# SM v2.0 Infra Setup in VCenter

## Prerequisites:

- **Instance Info**
Note that this automation has been designed to work with San Jose vCenter: https://sjc-xc-vcenter.pdsjc.f5net.com. Open a Service Now ticket to get the access to the below specs on the vCenter.

```
vCenter URL: 'sjc-xc-vcenter.pdsjc.f5net.com'
datacenter: 'XC-DC'
clustername: 'SJC-XC-Cluster'
resource pool: 'F5XC-Automation-Testing'
```

`config.properties` contains the list of all properties required to run the framework. It can be tweaked accordingly.

- **ovftool** 

Install script need `ovftool` software. Refer this documentation : https://developer.vmware.com/web/tool/ovf-tool and place the ovftool software at `/usr/lib` directory. In this framework, it is set to use `/usr/lib/ovftool_4.6`.

- **govc** 

To work with vCenter `govc` binary is needed to destroy the VMs. Follow this documentation https://github.com/vmware/govmomi/releases and download appropriate `govc` binary according to your platform.

- **credentials**

Before running thr scripts make sure to set the below variables on the shell level. The username is federated with @olympus domain hence it has be appended. E.g., `tummidi@olympus`

```
export VCENTER_USER="user@olympus"  #The vCenter user. Make sure the domain name '@olympus' is added
export VCENTER_PASSWORD="pass"      #The vCenter password
```

- This framework is designed to run from the jenkins slave machine : `jenkins@10.144.11.1`


## Usage

- To install the infrastructure in VMware:

`install_vmware_ce.sh <vmware_ova_image_name> <ver-type> <token>`

- **vmware_ova_image_name**: It will check if this image exists at `/var/lib/jenkins/vmware_images`. If not downloads the required image from the `download_source` defined in the `config.properties` file.
- **ver-type**: single, multi
- **token**: Jwt site token

- To teardown the infrastructure in openstack:

`destroy_vmware_infra.sh`

**E.g.,**

- To install an VMware cloud infrastructure with a single or multi node for CE deployment and testing run below:

  `./install_vmware_ce.sh f5xc-ce-9.2024.22-20240817055833.ova single eyJhbGciOiJIU....cop7zrhReXQv8G41nzZ_g`

  It will create and store the vm names in the scripts dir `.vm_setup_file` file

- To destroy and cleanup the single or multi node infra in openstack and resources created for testing. Reads the existing `.vm_setup_file` file and removes the VMs.

  `destroy_vmware_infra.sh`

---