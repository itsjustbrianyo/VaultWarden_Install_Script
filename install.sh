####     Thanks to wh1te909 who I stole (or got inspiration) alot of this script from (first script I have ever written)
####     and https://pieterhollander.nl/post/vaultwarden/ which I followed the steps and converted them to a script

#### Adapted to run on Ubuntu 22.04 with PostgreSQL and (optional) behind a dedicated reverse proxy (configured on a different machine with SSL enabled)

#check if running on ubuntu 22.04
UBU22=$(grep 22.04 "/etc/"*"release")
if ! [[ $UBU22 ]]; then
  echo -ne "\033[0;31mThis script will only work on Ubuntu 22.04\e[0m\n"
  exit 1
fi

#check if running as root
if [ $EUID -eq 0 ]; then
  echo -ne "\033[0;31mDo NOT run this script as root. Exiting.\e[0m\n"
  exit 1
fi

#Username
echo -ne "Enter your created username if you havent done this please do it now, use ctrl+c to cancel this script and do it${NC}: "
read username

#Enter domain
while [[ $domain != *[.]*[.]* ]]
do
echo -ne "Enter your Domain${NC}: "
read domain
done


#Local server IP
ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
echo "Local IP:$ip4"

if [ $enable_nginx -eq 1 ]; then
    vw_ip="127.0.0.1"
else
    vw_ip=$ip4
fi

admintoken=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 70 | head -n 1)

#Check Sudo works
if [[ "$EUID" != 0 ]]; then
    sudo -k # make sure to ask for password on next sudo
    if sudo true; then
        echo "Password ok"
    else
        echo "Aborting script"
        exit 1
    fi
fi

echo "Running Script"

#install dependencies
sudo apt update && apt list -u && sudo apt dist-upgrade -y
sudo apt install postgresql postgresql-contrib libpq-dev dirmngr git libssl-dev pkg-config build-essential curl wget apt-transport-https ca-certificates software-properties-common pwgen -y

curl -sL https://deb.nodesource.com/setup_16.x | sudo bash -
sudo apt install nodejs -y
curl https://sh.rustup.rs -sSf | sh
source ${HOME}/.cargo/env

### Configure PostgreSQL DB
# Random password
postgresql_pwd=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
sudo -u postgres psql -c "CREATE DATABASE vaultwarden;"
sudo -u postgres psql -c "CREATE USER vaultwarden WITH ENCRYPTED PASSWORD '${postgresql_pwd}';"
sudo -u postgres psql -c "GRANT all privileges ON database vaultwarden TO vaultwarden;"
echo "Successfully setup PostgreSQL DB vaultwarden with user vaultwarden and password ${postgresql_pwd}"

#Compile vaultwarden
git clone https://github.com/dani-garcia/vaultwarden.git
cd vaultwarden/
git checkout
#cargo build --features sqlite --release
cargo build --features postgresql --release
cd ..

#Download precompiled webvault
VWRELEASE=$(curl -s https://api.github.com/repos/dani-garcia/bw_web_builds/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')

wget https://github.com/dani-garcia/bw_web_builds/releases/download/$VWRELEASE/bw_web_$VWRELEASE.tar.gz

tar -xzf bw_web_$VWRELEASE.tar.gz

#Create vaultwarden folder and copy
sudo mkdir /opt/vaultwarden
sudo cp -r vaultwarden/target/release/vaultwarden /opt/vaultwarden
sudo mv web-vault /opt/vaultwarden/web-vault
sudo mkdir /opt/vaultwarden/data
sudo mkdir /etc/vaultwarden
sudo chown ${username}:${username} -R /etc/vaultwarden
sudo chown ${username}:${username} -R /opt/vaultwarden

touch /etc/vaultwarden/vaultwarden.conf

#Set vaultwardenRS Conf File
vaultwardenconf="$(cat << EOF
## Bitwarden_RS Configuration File
## Uncomment any of the following lines to change the defaults
##
## Be aware that most of these settings will be overridden if they were changed.
## in the admin interface. Those overrides are stored within DATA_FOLDER/config.json .

## Main data folder
# DATA_FOLDER=data

## Database URL
## When using SQLite, this is the path to the DB file, default to %DATA_FOLDER%/db.sqlite3
# DATABASE_URL=data/db.sqlite3
## When using MySQL, specify an appropriate connection URI.
## Details: https://docs.diesel.rs/diesel/mysql/struct.MysqlConnection.html
# DATABASE_URL=mysql://user:password@host[:port]/database_name
## When using PostgreSQL, specify an appropriate connection URI (recommended)
## or keyword/value connection string.
## Details:
## - https://docs.diesel.rs/diesel/pg/struct.PgConnection.html
## - https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING
## DATABASE_URL=mysql://vwarden:${mysqlpwd}@localhost:3306/vwarden
#DATABASE_URL=postgresql://vwarden:${mysqlpwd}@localhost:3306/vwarden
#DATABASE_URL=postgresql://[[user]:[password]@]host[:port][/database]
DATABASE_URL=postgresql://vaultwarden:${postgresql_pwd}@localhost:5432/vaultwarden

## Individual folders, these override %DATA_FOLDER%
# RSA_KEY_FILENAME=data/rsa_key
# ICON_CACHE_FOLDER=data/icon_cache
# ATTACHMENTS_FOLDER=data/attachments

## Templates data folder, by default uses embedded templates
## Check source code to see the format
# TEMPLATES_FOLDER=/path/to/templates
## Automatically reload the templates for every request, slow, use only for development
# RELOAD_TEMPLATES=false

## Client IP Header, used to identify the IP of the client, defaults to "X-Client-IP"
## Set to the string "none" (without quotes), to disable any headers and just use the remote IP
# IP_HEADER=X-Client-IP

## Cache time-to-live for successfully obtained icons, in seconds (0 is "forever")
# ICON_CACHE_TTL=2592000
## Cache time-to-live for icons which weren't available, in seconds (0 is "forever")
# ICON_CACHE_NEGTTL=259200

## Web vault settings
#WEB_VAULT_FOLDER=/opt/vaultwarden/web-vault/
#WEB_VAULT_ENABLED=true

## Enables websocket notifications
WEBSOCKET_ENABLED=true

## Controls the WebSocket server address and port
#WEBSOCKET_ADDRESS=127.0.0.1
WEBSOCKET_ADDRESS=${vw_ip}
WEBSOCKET_PORT=3012

## Enable extended logging, which shows timestamps and targets in the logs
# EXTENDED_LOGGING=true

## Timestamp format used in extended logging.
## Format specifiers: https://docs.rs/chrono/latest/chrono/format/strftime
# LOG_TIMESTAMP_FORMAT="%Y-%m-%d %H:%M:%S.%3f"

## Logging to file
## This requires extended logging
## It's recommended to also set 'ROCKET_CLI_COLORS=off'
LOG_FILE=/var/log/vaultwarden/error.log

## Logging to Syslog
## This requires extended logging
## It's recommended to also set 'ROCKET_CLI_COLORS=off'
# USE_SYSLOG=false

## Log level
## Change the verbosity of the log output
## Valid values are "trace", "debug", "info", "warn", "error" and "off"
## Setting it to "trace" or "debug" would also show logs for mounted 
## routes and static file, websocket and alive requests
LOG_LEVEL=info

## Enable WAL for the DB
## Set to false to avoid enabling WAL during startup.
## Note that if the DB already has WAL enabled, you will also need to disable WAL in the DB,
## this setting only prevents vaultwarden_rs from automatically enabling it on start.
## Please read project wiki page about this setting first before changing the value as it can
## cause performance degradation or might render  the service unable to start.
# ENABLE_DB_WAL=true

## Disable icon downloading
## Set to true to disable icon downloading, this would still serve icons from $ICON_CACHE_FOLDER,
## but it won't produce any external network request. Needs to set $ICON_CACHE_TTL to 0,
## otherwise it will delete them and they won't be downloaded again.
# DISABLE_ICON_DOWNLOAD=false

## Icon download timeout
## Configure the timeout value when downloading the favicons.
## The default is 10 seconds, but this could be to low on slower network connections
# ICON_DOWNLOAD_TIMEOUT=10

## Icon blacklist Regex
## Any domains or IPs that match this regex won't be fetched by the icon service.
## Useful to hide other servers in the local network. Check the WIKI for more details
# ICON_BLACKLIST_REGEX=192\.168\.1\.[0-9].*^

## Any IP which is not defined as a global IP will be blacklisted.
## Usefull to secure your internal environment: See https://en.wikipedia.org/wiki/Reserved_IP_addresses for a list of IPs which it will block
# ICON_BLACKLIST_NON_GLOBAL_IPS=true

## Disable 2FA remember
## Enabling this would force the users to use a second factor to login every time.
## Note that the checkbox would still be present, but ignored.
# DISABLE_2FA_REMEMBER=false

## Controls if new users can register
# SIGNUPS_ALLOWED=true

## Controls if new users need to verify their email address upon registration
## Note that setting this option to true prevents logins until the email address has been verified!
## The welcome email will include a verification link, and login attempts will periodically
## trigger another verification email to be sent.
# SIGNUPS_VERIFY=false

## If SIGNUPS_VERIFY is set to true, this limits how many seconds after the last time
## an email verification link has been sent another verification email will be sent
# SIGNUPS_VERIFY_RESEND_TIME=3600

## If SIGNUPS_VERIFY is set to true, this limits how many times an email verification
## email will be re-sent upon an attempted login.
# SIGNUPS_VERIFY_RESEND_LIMIT=6

## Controls if new users from a list of comma-separated domains can register
## even if SIGNUPS_ALLOWED is set to false
# SIGNUPS_DOMAINS_WHITELIST=example.com,example.net,example.org

## Controls which users can create new orgs.
## Blank or 'all' means all users can create orgs (this is the default):
ORG_CREATION_USERS=all
## 'none' means no users can create orgs:
# ORG_CREATION_USERS=none
## A comma-separated list means only those users can create orgs:
# ORG_CREATION_USERS=admin1@example.com,admin2@example.com

## Token for the admin interface, preferably use a long random string
## One option is to use 'openssl rand -base64 48'
## If not set, the admin panel is disabled
ADMIN_TOKEN=${admintoken}

## Enable this to bypass the admin panel security. This option is only
## meant to be used with the use of a separate auth layer in front
# DISABLE_ADMIN_TOKEN=false

## Invitations org admins to invite users, even when signups are disabled
# INVITATIONS_ALLOWED=true

## Controls the PBBKDF password iterations to apply on the server
## The change only applies when the password is changed
# PASSWORD_ITERATIONS=100000

## Whether password hint should be sent into the error response when the client request it
SHOW_PASSWORD_HINT=false

## Domain settings
## The domain must match the address from where you access the server
## It's recommended to configure this value, otherwise certain functionality might not work,
## like attachment downloads, email links and U2F.
## For U2F to work, the server must use HTTPS, you can use Let's Encrypt for free certs
DOMAIN=https://${domain}

## Yubico (Yubikey) Settings
## Set your Client ID and Secret Key for Yubikey OTP
## You can generate it here: https://upgrade.yubico.com/getapikey/
## You can optionally specify a custom OTP server
# YUBICO_CLIENT_ID=11111
# YUBICO_SECRET_KEY=AAAAAAAAAAAAAAAAAAAAAAAA
# YUBICO_SERVER=http://yourdomain.com/wsapi/2.0/verify

## Duo Settings
## You need to configure all options to enable global Duo support, otherwise users would need to configure it themselves
## Create an account and protect an application as mentioned in this link (only the first step, not the rest):
## https://help.vaultwarden.com/article/setup-two-step-login-duo/#create-a-duo-security-account
## Then set the following options, based on the values obtained from the last step:
# DUO_IKEY=<Integration Key>
# DUO_SKEY=<Secret Key>
# DUO_HOST=<API Hostname>
## After that, you should be able to follow the rest of the guide linked above,
## ignoring the fields that ask for the values that you already configured beforehand.

## Authenticator Settings
## Disable authenticator time drifted codes to be valid.
## TOTP codes of the previous and next 30 seconds will be invalid
##
## According to the RFC6238 (https://tools.ietf.org/html/rfc6238),
## we allow by default the TOTP code which was valid one step back and one in the future.
## This can however allow attackers to be a bit more lucky with there attempts because there are 3 valid codes.
## You can disable this, so that only the current TOTP Code is allowed.
## Keep in mind that when a sever drifts out of time, valid codes could be marked as invalid.
## In any case, if a code has been used it can not be used again, also codes which predates it will be invalid.
# AUTHENTICATOR_DISABLE_TIME_DRIFT = false

## Rocket specific settings, check Rocket documentation to learn more
# ROCKET_ENV=staging
#ROCKET_ADDRESS=127.0.0.1
ROCKET_ADDRESS=${vw_ip}
ROCKET_PORT=8000
# ROCKET_TLS={certs="/path/to/certs.pem",key="/path/to/key.pem"}

## Mail specific settings, set SMTP_HOST and SMTP_FROM to enable the mail service.
## Note: if SMTP_USERNAME is specified, SMTP_PASSWORD is mandatory
#SMTP_HOST=smtp.${domain}
#SMTP_FROM=vault@${domain}
# SMTP_FROM_NAME=Bitwarden_RS
#SMTP_PORT=25
#SMTP_SSL=true
# SMTP_EXPLICIT_TLS=true
#SMTP_USERNAME=vault@${domain}
#SMTP_PASSWORD=____PASSWORD____
# SMTP_AUTH_MECHANISM="Plain"
# SMTP_TIMEOUT=15

# vim: syntax=ini

EOF
)"
echo "${vaultwardenconf}" > /etc/vaultwarden/vaultwarden.conf

#Add some folders and permissions
sudo chmod 600 /etc/vaultwarden/vaultwarden.conf
sudo chown ${username}:${username} /etc/vaultwarden/vaultwarden.conf

sudo mkdir /var/log/vaultwarden
sudo chown -R ${username}:${username} /var/log/vaultwarden
touch /var/log/vaultwarden/error.log

sudo touch /etc/systemd/system/vaultwarden.service
sudo chown ${username}:${username} -R /etc/systemd/system/vaultwarden.service

#Set vaultwarden Service File
vaultwardenservice="$(cat << EOF
[Unit]
Description=Vaultwarden server
After=network.target auditd.service

[Service]
RestartSec=2s
Type=simple

User=${username}
Group=${username}

EnvironmentFile=/etc/vaultwarden/vaultwarden.conf

WorkingDirectory=/opt/vaultwarden/
ExecStart=/opt/vaultwarden/vaultwarden
Restart=always

# Isolate vaultwarden from the rest of the system
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
NoNewPrivileges=true
ProtectSystem=strict

# Only allow writes to the following directory
ReadWritePaths=/opt/vaultwarden/data/ /var/log/vaultwarden/error.log

# Set reasonable connection and process limits
LimitNOFILE=1048576
LimitNPROC=64

[Install]
WantedBy=multi-user.target

EOF
)"
echo "${vaultwardenservice}" > /etc/systemd/system/vaultwarden.service

sudo systemctl daemon-reload
sudo systemctl enable vaultwarden
sudo systemctl start vaultwarden

#Set maintenence task for monthly reboot
echo "0 0 1 * * root /usr/sbin/shutdown -r now" | sudo tee -a /etc/crontab > /dev/null

printf >&2 "Please go to admin url: https://${domain}/admin\n\n"
printf >&2 "Enter ${admintoken} to gain access, please save this somewhere!!\n\n"

echo "Installation complete!"
