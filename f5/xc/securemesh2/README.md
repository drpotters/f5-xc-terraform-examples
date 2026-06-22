# SecureMesh-v2 Automation

### * Generating API Token:
Login to the respective environment's web console --> Administration --> Credentials --> Add Credential --> Create a new credential with type 'API Token'

### * Script Usage():

```
export API_TOKEN='--PASTE_THE_GENERATED_TOKEN--'
```

```
~/scripts/manage_sm2_site.sh <action> <site-name> <env> <provider-type> <cluster-type>
```

- **action**: create | delete | status
- **site-name**: ce name
- **env** : production
- **provider-type** : All providers SMSv2 supports
- **cluster-type** : single | multi

### * To CREATE the SMSv2 site object:

```
~/scripts/manage_sm2_site.sh create <site-name> <env> <provider-type> <cluster-type>
```

E.g.,

```
~/scripts/manage_sm2_site.sh create site-name production aws single
```

This script generates the site JWT token after successful execution which can be used to create the site infrastructure.

#### Create SMSv2 provider's infrastructure:

- Navigate to the respective provider's directory in this repo and follow the `README` instructions to create the site infrastructure


### * To DELETE the SMSv2 site

#### Script usage to delete SMSv2 site:

```
~/scripts/manage_sm2_site.sh delete <site-name> <env>
```

This will remove both site object as well as the associated token from the environment.

#### Delete SMSv2 provider's infrastructure:

- In order to destroy the infrastructure, navigate to the respective provider's directory in this repo and follow the README instructions.

### * To get the TOKEN only of an existing site:

- To generate only token of an existing site in any environment, use the below syntax:

```
~/scripts/manage_sm2_site.sh token <site-name> <env>
```

### * To check the STATUS of a site

```
~/scripts/manage_sm2_site.sh status <site-name> <env>
```

Expected Statuses

```
WAITING_FOR_REGISTRATION
PROVISIONING
ONLINE
UPGRADING
FAILED
DECOMMISSIONING
```