Vaultwarden_Install_Script. 
-----
Script used to download, extract, and install VaultWarden on Ubuntu 22.04 without the use of Docker. The script is forked from https://github.com/dinger1986/bitwardenrs_install_script which uses https://github.com/dani-garcia/vaultwarden binaries. 

This script also removes the installation of NGINX and Fail2Ban and adds a cron job to reboot the server monthly.

If you have issues, please reach out here instead of submitting a support requests to either dinger1986 or dani-garcia

## Hardware Requirements 

- 2GB RAM

## Prerequisites 

- Ubuntu 22.04 
- Create non root user
- DNS record pointing to your external IP 
- Ports 80 and 443 opened on your firewall

## HTTPS Required
Note: HTTPS is required to use VaultWarden. This script removed automatic NGINX/LetsEncrypt setup as I have a NGINX proxy in place already. You'll need to ensure one is setup prior to beginning the installation and you will be on your own for setup. 

https://inepttech.com/nginx-reverse-proxy-with-ssl/

## Installation

Install.sh will install the newest version of VaultWarden.


```bash
# If logged in as root add a user using these commands prior to install: 
$ adduser vaultwarden
$ usermod -a -G sudo vaultwarden
# Switch to vaultwarden user (script won't run as root) 
$ su vaultwarden
# Change Directory to vaultwarden home 
$ cd ~/
# Download the install script from github 
$ wget https://raw.githubusercontent.com/itsjustbrianyo/Vaultwarden_Install_Script/master/install.sh
# Set Script as executable 
$ chmod +x install.sh
# Run script 
$ ./install.sh
```

Fill in info as requested as the script runs.

Once complete go to https://vault.yourdomain.com/admin

## Update

```bash
# Download the update script from github 
$ wget https://raw.githubusercontent.com/itsjustbrianyo/Vaultwarden_Install_Script/master/update.sh
# Set Script as executable 
$ chmod +x update.sh
# Run script $ ./update.sh
```

Fill in info as requested as the script runs.

