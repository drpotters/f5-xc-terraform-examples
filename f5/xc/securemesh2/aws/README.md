# SM v2.0 Infra Setup in AWS

## Pre-requisites
This script requires below softwares in order to run the automation

`terraform ~> 1.9.0`

`jq ~> 1.6`

## Usage to create a new site

- To install the infrastructure in aws:

`install_aws_site.sh install <ami_image_name> <ver-type> <region> <token>`

- To teardown the infrastructure in aws:

`install_aws_site.sh destroy`

- **ami_image_name**: ami image name in that specific region
- **ver-type**: single, multi
- **regions**: us-west-1, us-west-2, us-east-1, us-east-2 (us-east-4 incase of GCP)
- **token**: Jwt site token

**E.g.,**

- To install an aws cloud infrastructure with a single or multi node for CE deployment and testing run below:

  `install_aws_site.sh   install  f5xc-ce-9.2024.22-20240917135102  single|multi   us-west-1   eyJf760Ys...........lToDmHmsil_3aIs`
- To destroy and cleanup the single or multi node infra in aws and resources created for testing.

  `install_aws_site.sh   destroy`

---
This script works assuming the service account credentials of aws is called securely from vault or any secret management providers and set as environment variables.

**Setting up the credentials for aws:**

Use this [script](https://gitlab.com/f5/volterra/security/secops-engg/-/blob/main/aws-saml/aws-saml.py?ref_type=heads) to generate aws credentials using sso two factor authentication. Once creds are generated, edit this local file `~/.aws/credentials` to change the header that appears like `[AWS-Volterra-xxxxx]` to `[default]` as shown below.

```
cat ~/.aws/credentials

[default]
output = json
region = <region>
aws_access_key_id = *************************
aws_secret_access_key = **************************
```

## Usage to add a new worker(s) to an existing site

- Once the site (either HA enabled three node or HA disabled single node) is created, more worker nodes can be added to the existing site in a homogeneous way (same number of interfaces and other specs of other nodes)

- To add workers to the existing site:

```
cd ~/aws/add_worker
./add_worker.sh  <action>  <total number of workers>  <JWT node token>
```

- E.g., `bash add_worker.sh  install  2  eyJhbGciO............joiMmEzZT`

- **action** - install | destroy
- **workers** - numeric count of more workers to be added
- **JWT Token** - Node token generated against the site

- To destroy worker's infra:

`./add_worker.sh  <destroy>`

- **Note** : Please make to destroy the workers first before destroying the infra of the actual site.

- To remove workers from the site configuration:

```
cd ~/aws/remove_worker
./delete_worker.sh  <site_name>  <environment>
```

- **site_name** - Name of the existing site in the environment
- **environment** - Name of environment - demo1 | crt | staging | production

It handles three generic cases:
- Validates if the site exists
- If exists checks if that site has worker nodes
- If site and workers both exist then, delete workers from the site

## Optional client server setup

- In order to create the client - server setup, run with optional parameter `--clientserver count`
- Max clients and servers count has been set to `3` 

```
bash install_aws_site.sh install f5xc-ce-crt-20260201-0090-9.2026.3-20260316044018 multi us-east-1 <site_token> --clientserver 2
```

- It will create keys in the same directory using which you can login to clients and servers 
```
$ ~/securemesh2/aws
-r--------@ 1 d.tummidi  staff   3.2K Apr  6 17:54 smv2-client-key.pem
-r--------@ 1 d.tummidi  staff   3.2K Apr  6 17:54 smv2-server-key.pem
```
- `ubuntu` is the default user for both server and client
```
ssh -i smv2-client-key.pem ubuntu@client-ip
ssh -i smv2-server-key.pem ubuntu@server-ip
```

- Server VMs will have nginx webserver, network tools pre-installed during the setup.
- Inter-connectivity between the clients ==> CE ==> Servers enabled