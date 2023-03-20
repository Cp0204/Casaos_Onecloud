#!/bin/bash

# Constants
TTYD_DOWNLOAD_URL="https://github.com/tsl0922/ttyd/releases/latest/download"
TTYD_FILE_PATH="/opt/ttyd"
TTYD_SERVICE_FILE_PATH="/etc/systemd/system/ttyd.service"

# Set TTYD_PORT to default value if not specified by user
read -p "Enter a port number for ttyd (default is 7681): " TTYD_PORT
TTYD_PORT=${TTYD_PORT:-7681}

read -p "Using system user authentication? (y/n): " -r USE_SYSTEM_AUTH
USE_SYSTEM_AUTH=${USE_SYSTEM_AUTH:-y}
if [[ $USE_SYSTEM_AUTH =~ ^[Yy]$ ]]; then
  AUTH_MOD="login"
else
  AUTH_MOD="bash"
fi

read -p "Using basic authentication? (y/n): " -r USE_BASIC_AUTH
USE_BASIC_AUTH=${USE_BASIC_AUTH:-y}
if [[ $USE_BASIC_AUTH =~ ^[Yy]$ ]]; then
  read -p "Enter USERNAME: " -r BASIC_AUTH_USERNAME
  read -s -p "Enter PASSWORD: " -r BASIC_AUTH_PASSWORD
  if [ -n $BASIC_AUTH_USERNAME ] && [ -n $BASIC_AUTH_PASSWORD ]; then
    BASIC_AUTH="-c $BASIC_AUTH_USERNAME:$BASIC_AUTH_PASSWORD"
  else
    BASIC_AUTH=""
    echo "WARNING: USERNAME and PASSWORD are empty, FORCE to use system user authentication."
    AUTH_MOD="login"
  fi
fi

# Stop existing ttyd service
sudo systemctl stop ttyd.service

# Download the latest release of ttyd based on the system architecture
if [ $(uname -m) = "x86_64" ]; then
  TTYD_DOWNLOAD_FILENAME="ttyd.x86_64"
elif [ $(uname -m) = "armv7l" ]; then
  TTYD_DOWNLOAD_FILENAME="ttyd.armhf"
elif [ $(uname -m) = "aarch64" ]; then
  TTYD_DOWNLOAD_FILENAME="ttyd.aarch64"
else
  echo "Unsupported architecture"
  exit 1
fi

echo "Downloading ttyd..."
wget --progress=bar:force $TTYD_DOWNLOAD_URL/$TTYD_DOWNLOAD_FILENAME -O $TTYD_FILE_PATH || { echo "Failed to download ttyd"; exit 1; }

# Make ttyd executable
sudo chmod +x $TTYD_FILE_PATH

# Create the ttyd.service file
if [ -f "$TTYD_SERVICE_FILE_PATH" ]; then
  read -p "The ttyd.service file already exists. Do you want to overwrite it? (y/n): " -r OVERWRITE_SERVICE_FILE
  if [[ $OVERWRITE_SERVICE_FILE =~ ^[Yy]$ ]]; then
    OVERWRITE_SERVICE_FILE=y
  else
    echo "Not overwriting the ttyd.service file."
    exit 1
  fi
else
    OVERWRITE_SERVICE_FILE=y
fi

if [[ $OVERWRITE_SERVICE_FILE =~ ^[Yy]$ ]]; then
  sudo tee $TTYD_SERVICE_FILE_PATH > /dev/null <<EOT
[Unit]
Description=TTYD
After=syslog.target
After=network.target

[Service]
ExecStart=$TTYD_FILE_PATH -p $TTYD_PORT $BASIC_AUTH $AUTH_MOD
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOT
fi

# Reload systemd to detect the new ttyd.service file
sudo systemctl daemon-reload

# Enable and start ttyd service
sudo systemctl enable ttyd.service
sudo systemctl start ttyd.service

# Get the IP address of the machine
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Print the URL for accessing the ttyd web terminal
echo "ttyd is now running at http://${IP_ADDRESS}:${TTYD_PORT}"
