# Baremetal CE automation for Securemesh v2.0

This automation has been specifically written keeping Hyd dell baremetal inventory in the scope for securemesh v2.0 type of deployments.

This automation performs below tasks

- Downloads the latest RHEL ISO from the given source as an argument to the `install_os.sh` script
- Installs OS on a single/multi nodes
- Makes changes to configure a single/multi-node CE
- Register and bring the CE Online
- When the CE is online, performs the necessary tests

## Details

- Jenkins Job : [link](https://jenkins-dev.volterra.us/view/SecureMesh%20V2/job/BasicSanityStatusTests/job/test-baremetal-sm2/)
- Inventory : [file](https://gitlab.com/f5/volterra/ves.io/test-automation-infra/-/blob/main/securemesh2/baremetal/config/server.inv)
- Controller Machine : `jenkins@10.218.201.128` / `vol......123`

## Prerequisites

- Ansbile > `2.16`
- Bash > `5.0`
- Python > `3.10`
- Linux VM with connectivity to the `Hyd Lab`
- Linux user `jenkins` with home dir `/var/lib/jenkins`
- Python virtual Environment named `bm-automation` at `/var/lib/jenkins`

Any other changes to the above details should be updated in the [common_vars.yaml](https://gitlab.com/f5/volterra/ves.io/test-automation-infra/-/blob/main/securemesh2/baremetal/playbooks/common_vars.yaml)

## Usage

#### OS Installation
By default, only one server is uncommented in the inventory file. All three nodes will be uncommented dynamically when the `cluster_size` passed as `multi` to the `install_os.sh` script.

The ansible main [playbook](https://gitlab.com/f5/volterra/ves.io/test-automation-infra/-/blob/main/securemesh2/baremetal/playbooks/bm_main.yaml) has the _download_ task commented by default. Jenkins job will uncomment when `Install OS` and `Download ISO` parameters are selected.

To run manually, fulfill the prerequisites and run below:

```
export ROOT_PASS=<sudo-pass-of-the-user>
```

**Usage without downloading the image**
```
~/securemesh2/baremetal/scripts/install_os.sh <cluster_size> <image_name>

E.g., ./install_os.sh single|multi f5xc-ce-9.2025.17-securemeshv2-20250523-0731.iso
```

**Usage with downloading the image from remote source**
```
~/securemesh2/baremetal/scripts/install_os.sh <cluster_size> <image_name> --download

E.g., ./install_os.sh single|multi f5xc-ce-9.2025.17-securemeshv2-20250523-0731.iso --download
```

#### CE Setup
After the OS installation is completed, generate Jwt one time token from the UI or REST API against the site object type "Baremetal"

```
~/securemesh2/baremetal/scripts/create_bm_ce.sh <cluster_size> <token>
```

E.g.,
`~/baremetal-hyd-ce/scripts/create_bm_ce.sh single|multi jwt_proxy_token`

- cluster_size - single or multi
- Token - Jwt node token


## Baremetal Inventory Details:

| iDRAC IP        |  MAC Address      | DHCP Fixed IP |
|:----------------|:-----------------:|--------------:|
| 10.218.31.151   | 20:3A:43:01:7B:50 | 10.218.55.196 |
| 10.218.31.152   | 20:3A:43:01:76:50 | 10.218.55.200 |
| 10.218.31.153   | 20:3A:43:01:76:58 | 10.218.55.197 |
| 10.218.31.154   | 20:3A:43:01:75:F8 | 10.218.55.198 |
| 10.218.31.155   | 20:3A:43:01:7B:60 | 10.218.55.199 |