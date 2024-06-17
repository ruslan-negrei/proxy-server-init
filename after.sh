#!/bin/sh

# Run with sudo bash init.sh

echo "You need to be connected to the internet via ethernet for this to work. Continue? (y/n)"
read -r response

if [ "$response" != "y" ]; then
  echo "Exiting..."
  exit 1
fi

echo "Server URL: (f.x. https://my-website.com)"
read -r PROXY_SERVER_URL

if [ -z "$PROXY_SERVER_URL" ]; then
  echo "Server URL is required"
  exit 1
fi

echo "Server API key: "
read -r PROXY_API_KEY

if [ -z "$PROXY_API_KEY" ]; then
  echo "Server API key is required"
  exit 1
fi

authorization=$(curl -s -o /dev/null -w "%{http_code}" $PROXY_SERVER_URL/api/proxy/latest?apiKey=$PROXY_API_KEY)

if [ "$authorization" == "200" ]; then
  echo "API key is valid"
elif [ "$authorization" == "401" ]; then
  echo "Invalid API key: $PROXY_API_KEY. Unauthorized"
  exit 1
else
  echo "Error: $authorization"
  exit 1
fi

echo "Port range forwarded to the server: (f.x. 6000-7000) "
echo "Port start: (f.x. 6000)"
read -r PORT_START

if [ -z "$PORT_START" ]; then
  echo "Port start is required"
  exit 1
fi

echo "Port end: (f.x. 7000)"
read -r PORT_END

if [ -z "$PORT_END" ]; then
  echo "Port end is required"
  exit 1
fi

echo "Set up AnyDesk password: "
read -r ANYDESK_PASSWORD

if [ -z "$ANYDESK_PASSWORD" ]; then
  echo "AnyDesk password is required"
  exit 1
fi

echo "Setting up AnyDesk..."
anydesk --service
echo $ANYDESK_PASSWORD | anydesk --set-password
ANYDESK_ID=$(anydesk --get-id)

# Getting internal IP
echo "Getting internal IP..."
INTERNAL_IP=$(ip route | awk '/^default/ {print $9}')

# Setting environment variables
echo "Creating server configuration..."
mkdir -p /home/admin/proxy
chown -R admin:admin /home/admin/proxy
echo "PROXY_SERVER_URL=$PROXY_SERVER_URL
PORT_START=$PORT_START
PORT_END=$PORT_END
ANYDESK_ID=$ANYDESK_ID
ANYDESK_PASSWORD=$ANYDESK_PASSWORD
INTERNAL_IP=$INTERNAL_IP
PROXY_API_KEY=$PROXY_API_KEY" >/home/admin/proxy/.env

# Setting up proxy server
echo "Setting up proxy server..."

echo "Creating empty custom.cfg file..."
touch /home/admin/proxy/custom.cfg

echo "Downloading latest release..."
curl -o /home/admin/release.zip $PROXY_SERVER_URL/api/proxy/latest?apiKey=$PROXY_API_KEY

echo "Unzipping release..."
unzip -o /home/admin/release.zip -d /home/admin/

echo "Copying files..."
cp /home/admin/release/* /home/admin/proxy

echo "Cleaning up..."
rm -rf /home/admin/release /home/admin/release.zip

# Installing dependencies
cd /home/admin/proxy

# Enabling PM2
echo "Initializing PM2..."
pm2 startup
pm2 start
pm2 save

# Deleting user from sudo
deluser user sudo
passwd -d user

echo "Setup complete. Rebooting"
reboot
