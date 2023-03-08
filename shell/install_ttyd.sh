#!/bin/bash

# Ask user to input a port number for ttyd
read -p "Enter a port number for ttyd (default is 8080): " TTYD_PORT
TTYD_PORT=${TTYD_PORT:-8080}

# Prompt user for custom title
read -p "Please enter a custom title for the terminal (default is login): " TTYD_TITLE
TTYD_TITLE=${TITLE:-login}

# Stop existing ttyd service
sudo systemctl stop ttyd.service

# Download the latest release of ttyd based on the system architecture
if [ $(uname -m) = "x86_64" ]; then
  wget https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 -O /opt/ttyd
elif [ $(uname -m) = "armv7l" ]; then
  wget https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.armhf -O /opt/ttyd
elif [ $(uname -m) = "aarch64" ]; then
  wget https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.aarch64 -O /opt/ttyd
else
  echo "Unsupported architecture"
  exit 1
fi

# Make ttyd executable
sudo chmod +x /opt/ttyd

# Create the ttyd.service file
sudo tee /etc/systemd/system/ttyd.service > /dev/null <<EOT
[Unit]
Description=ttyd web terminal
After=network.target

[Service]
ExecStart=/opt/ttyd -p $TTYD_PORT $TTYD_TITLE
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOT

# Reload systemd to detect the new ttyd.service file
sudo systemctl daemon-reload

# Enable and start ttyd service
sudo systemctl enable ttyd.service
sudo systemctl start ttyd.service

# Get the IP address of the machine
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Print the URL for accessing the ttyd web terminal
echo "ttyd is now running at http://${IP_ADDRESS}:${TTYD_PORT}"
