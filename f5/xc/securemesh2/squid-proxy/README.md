
# Squid Proxy Setup for SMSv2

### Proxy Installation

- The proxy VM must be connected to both the internet and the network where the CEs reside. The purpose is to ensure that CE nodes can access only the whitelisted XC destinations through the proxy. 
- Install Ubuntu 24.04 LTS in a Virtual Machine with minimum spec of 2 vCPUS, 4GB RAM, 30GB Disk.
- Switch to the root user on the proxy vm and run following commands in the same order as given

  ```
  apt update && apt upgrade -y  #Update and Upgrade the Ubuntu system
  apt install squid -y          #Install squid proxy
  systemctl enable squid        #Setup squid proxy as a system service to start automatically during the reboots
  systemctl status squid        #To check the initial setup is doing fine
  ```
- Download these files `squid.conf`, `f5xcdomains.txt` and `allowed-cidrs.txt` and place them at `/etc/squid` directory on the proxy VM.
- Run `squid -k reconfigure` to re-process the newly added configuration files. This would process configuration files `/etc/squid/squid.conf` and `/etc/squid/conf.d/debian.conf`. And set current directory to `/var/spool/squid` .
- Now proxy is ready with `no-auth` mode with port `3128` and IPv4 address of the Proxy VM.
- After hitting the proxy through a CE ,tail the squid access log file at `/var/log/squid/access.log` to make sure no `403`, `500`, `503` HTTP Error responses. `200` response code is a good sign of a healthy connected squid proxy to all the domains/cidr listed in the configuration.

### SMSv2 Site Object with Custom Proxy
- Create a site Object with custom proxy under the `Site Management` --> `Enterprise Proxy` --> Select `Custom Proxy`
  ```
  IPv4 Address: IP address of the Proxy VM
  Port : 3128
  ```
- Make sure the nodes of the site can be able to connect to the proxy.
- Verify the vpm logs to see if the node can download the most recent vpm image before requesting registration through the proxy.

### Proxy Setup with Authentication
- Follow these instructions to configure proxy to work with authentication.

- Switch to the root user on the proxy VM and run commands in the given order.
  
  ```
  apt update
  apt install apache2-utils
  ```
- Generate a password file to store `squidadmin` user credentials using `htpasswd` utility. Remember the password.

  ```
  sudo htpasswd -c /etc/squid/passwd squidadmin
  ```

- Replace the file `/etc/squid/squid.conf` in the proxy VM with the file `squid.conf.with.auth` placed in this directory.

  ```
  mv /etc/squid/squid.conf /etc/squid/squid.conf_bkp
  cp squid.conf.with.auth /etc/squid/squid.conf
  ```
- Restart the squid service

  ```
  systemctl restart squid
  ```
- While creating the SMSv2 site Object, select `Custom Proxy` under the `Site Management` and enter IPv4, Port, credentials of the proxy.

### Proxy for non-prod environments

- All the files placed in this directory have been prepared keeping production in mind. To make this work for any non-production environments, do below changes in the squid configuration.

- Add below additional lines in the file `/etc/squid/f5xcdomains.txt`

  ```
  .volterra.us
  waferdatasetsstaging.blob.core.windows.net
  ```

- Add additional line in the file `/etc/squid/allowed_cidrs.txt`
   
  ```
  159.60.140.193 #Proxy for non prod environments
  ```
- Restart squid proxy 

  ```
  systemctl restart squid
  ```