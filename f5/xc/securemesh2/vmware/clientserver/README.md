# VMware ESXi Ubuntu Client and Servers Auto Provisioning

## Overview

This automation script creates multiple Ubuntu virtual machines on a VMware ESXi host using `govc` and a prebuilt **silent/unattended Ubuntu installation ISO**.

The script performs the following:

* Creates Client and Server VMs on ESXi
* Boots VMs using unattended Ubuntu ISO
* Waits for IP assignment
* Waits for Ubuntu installation completion
* Adds a secondary NIC
* Updates Linux hostname to match VM name
* Installs packages defined in `config.properties`

---

# Prerequisites

## 1. Install Required Tools on the Machine Running Script

```bash
sudo apt install govc sshpass openssl
```

> `govc` must be available in PATH.

---

## 2. Prepare Ubuntu Silent Installation ISO

Create a custom unattended Ubuntu ISO (Autoinstall enabled).

Example:

```text
ubuntu-24.04-autoinstall.iso
```

Upload this ISO to a datastore path in ESXi.

Example datastore location:

```text
[hyper12-datastore] ubuntu/ubuntu-24.04-autoinstall.iso
```

This path must be used in:

```properties
SOURCE_IMAGE=ubuntu/ubuntu-24.04-autoinstall.iso
```

**Note:** such image is already available at `10.144.11.1:/var/lib/jenkins/vmware_images/ubuntu-24.04-autoinstall.iso` Upload this image to your ESXi server under `[DATASTORE]/path` and the same can be used in the `SOURCE_IMAGE` in `config.properties` file.

---

# Required Environment Variables

Export the following before running the script:

```bash
export GOVC_USERNAME=root
export GOVC_PASSWORD='your_esxi_password'

export UBUNTU_USER=ubuntu
export UBUNTU_PASSWORD='default12345'
```

Optional:

```bash
export GOVC_INSECURE=1
```

---

# config.properties

Place `config.properties` in the **same directory as the script**.

## Example

```properties
#ESXi details
GOVC_URL=https://10.146.58.28
DATASTORE=hyper12-datastore
SOURCE_IMAGE=ubuntu/ubuntu-24.04-autoinstall.iso

#VM Specification
VM_NETWORK=VM Network
VM_CPU=2
VM_RAM_MB=4096
VM_DISK_GB=30

#Secondary network to add for SLI 
SECONDARY_NETWORK=Test-VLAN-SLI

#Packages to be installed during the provisioning itself
CLIENT_PACKAGES=net-tools,curl,nginx
SERVER_PACKAGES=net-tools,curl,apache2

#Total number of instances to be provisioned.
NUM_CLIENTS=2
NUM_SERVERS=1
```

---

# Property Descriptions

| Property          | Description                              |
| ----------------- | ---------------------------------------- |
| GOVC_URL          | ESXi host URL                            |
| DATASTORE         | Datastore name where VMs will be created |
| SOURCE_IMAGE      | Datastore path of Ubuntu unattended ISO  |
| VM_NETWORK        | Primary NIC network                      |
| VM_CPU            | Number of vCPUs                          |
| VM_RAM_MB         | RAM in MB                                |
| VM_DISK_GB        | Disk size in GB                          |
| SECONDARY_NETWORK | (Optional) Secondary NIC network         |
| CLIENT_PACKAGES   | Packages installed on client VMs         |
| SERVER_PACKAGES   | Packages installed on server VMs         |
| NUM_CLIENTS       | Number of client VMs                     |
| NUM_SERVERS       | Number of server VMs                     |

---

# VM Naming Convention

Each run generates one Group ID.

Example:

```text
client-ab123-1
client-ab123-2
server-ab123-1
```

This helps identify all VMs created in the same batch.

---

# How to Run

```bash
chmod +x create_vmware_setup.sh
./create_vmware_setup.sh
```

---

# Post Provision Actions

After VM creation, the script automatically:

* Waits for Ubuntu installation to complete
* Adds secondary NIC
* Waits for SSH access
* Changes hostname to VM name
* Installs requested packages

---

# Notes

## Ubuntu ISO Must Support:

* Autoinstall
* DHCP Networking
* SSH Enabled
* User with sudo access

## Example Ubuntu Credentials:

```text
username: ubuntu
password: default12345
```

---

# Troubleshooting

## govc authentication failed

Verify:

```bash
echo $GOVC_USERNAME
echo $GOVC_PASSWORD
```

## SSH timeout

Check:

* VM boot completed
* Ubuntu install finished
* IP reachable
* Firewall rules

## ISO not found

Verify datastore path:

```text
[DATASTORE] folder/file.iso
```

---

# Recommended Workflow

1. Build unattended Ubuntu ISO once
2. Upload to ESXi datastore
3. Reuse same ISO for multiple environments
4. Run script with different client/server counts

---

# Output Example

```text
client-ab123-1   10.146.57.155
client-ab123-2   10.146.57.156
server-ab123-1   10.146.57.157
```

---