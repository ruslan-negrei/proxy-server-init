#!/bin/sh
# Update & install packages
apt-get install -y iptables-persistent build-essential curl git wget openssh-server network-manager moreutils

# Create linux user
echo "Creating user..."
adduser admin
usermod -aG sudo admin

# Remove suspend
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Installing 3proxy
echo "Installing 3proxy..."
git clone https://github.com/3proxy/3proxy
cd 3proxy
ln -s Makefile.Linux Makefile
make
sudo make install

# Install NVM
echo "Installing NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Load NVM
echo "Loading NVM..."
export NVM_DIR="$HOME/.nvm"
source $NVM_DIR/nvm.sh

# Install Node.js
echo "Installing Node.js..."
nvm install node lts
nvm use default

# Install PM2
echo "Installing PM2"
npm install -g pm2

# Symlinks
echo "Creating symlinks..."
ln -s $NVM_BIN/pm2 /usr/bin/pm2
ln -s $NVM_BIN/node /usr/bin/node
ln -s $NVM_BIN/npm /usr/bin/npm

# Installing anydesk
echo "Installing AnyDesk..."
wget -qO - https://keys.anydesk.com/repos/DEB-GPG-KEY | apt-key add -
echo "deb http://deb.anydesk.com/ all main" | tee /etc/apt/sources.list.d/anydesk-stable.list
apt-get update
apt-get install anydesk -y

# Setting Anydesk Display config
echo "Setting AnyDesk Display config..."
echo "[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
WaylandEnable=false

[security]

[xdmcp]

[chooser]

[debug]
" >/etc/gdm3/custom.conf

systemctl disable ufw
systemctl disable firewalld

# Copying NetworkManager configuration
echo "Copying NetworkManager configuration..."
cp /home/admin/proxy/proxy-server/init/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf

# Copying modem reconnection script
echo "Copying modem reconnection script..."
cp /home/admin/proxy/proxy-server/init/modem_reconnect.sh /etc/NetworkManager/dispatcher.d/99-modem-reconnect
chmod +x /etc/NetworkManager/dispatcher.d/99-modem-reconnect

# Setting IPTables rules
echo "Adding conntrack module..."
modprobe nf_conntrack

echo "Clearing all iptables rules..."
iptables -F
iptables -X

echo "Setting TRAFFIC_STATS chain..."
iptables -N TRAFFIC_STATS
iptables -A OUTPUT -j TRAFFIC_STATS
iptables -A INPUT -j TRAFFIC_STATS

echo "Setting up iptables rules..."
netfilter-persistent save

# Getting current interface connected to the internet
echo "Getting current interface connected to the internet..."
INTERFACE=$(ip route | awk '/^default/ {print $5; exit }')

# Setting ethernet interface not being managed by NetworkManager
echo "Setting ethernet interface not being managed by NetworkManager..."
echo "[connection-$INTERFACE]
match-device=interface-name:$INTERFACE
managed=false
ipv4.route-metric=50
ipv6.route-metric=50
autoconnect=true
" >>/etc/NetworkManager/NetworkManager.conf
