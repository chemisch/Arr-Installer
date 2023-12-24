#!/bin/bash

#########################################################################################################################################
#### Script assumes you have a SMB Network Drive that you plan to use - Delete/markout associated sections if you don't plan to use #####
#########################################################################################################################################
####              was designed around using Debian 12 but should work with most debian based distrubutions                          #####
#########################################################################################################################################
####                           Make nessecary changes to docker-compose.yml before running                                          #####
#########################################################################################################################################

# Check for root privilege
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run with sudo."
  exit 1
fi

# Define starting point file tree.
BaseDIR="/home/$SUDO_USER"

# Create directories
directories=(
    "SMB" #NAS mounting point
    "filebrowser"
    "homarr/configs"
    "homarr/icons"
    "homarr/data"
    "Arr-stack/prowlarr/data"
    "Arr-stack/qbittorrent/config"
    "Arr-stack/qbittorrent/downloads"
    "Arr-stack/sonarr/data"
)

# Create directories
sudo -u "$SUDO_USER" mkdir -p "${directories[@]/#/$BaseDIR/}"

# Generate hommarr settings.json
json_content='{
  "port": 80,
  "baseURL": "",
  "address": "",
  "log": "stdout",
  "database": "/database/filebrowser.db",
  "root": "/srv"
}'
echo "$json_content" > "$BaseDIR/filebrowser/settings.json"

# Generate empty filebrowser.db
sudo -u "$SUDO_USER" touch $BaseDIR/filebrowser/"filebrowser.db"

# Generate .SMBCred file - SMB credentials.

read -p 'Enter SMB USERNAME: ' USERNAME
read -p 'Enter SMB PASSWORD: ' PASSWORD
echo "username=$USERNAME" > "$BaseDIR/.SMBCred"
echo "password=$PASSWORD" >> "$BaseDIR/.SMBCred"
echo "domain=WORKGROUP" >> "$BaseDIR/.SMBCred"

# Mount network drive
read -p 'Enter NAS IP: ' IP
echo "//$IP/Media $BaseDIR/SMB cifs nofail,_netdev,credentials=$BaseDIR/.SMBCred 0 0" >> /etc/fstab

#### docker install ####

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin cifs-utils

docker volume create portainer_data

docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

docker compose up -d

#mount NAS
mount -a