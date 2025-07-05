#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Update package lists
sudo apt update

# Install required packages
sudo apt install -y nginx git curl

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Clone the frontend repo into /root/qubic/
sudo git clone https://github.com/icyblob/hm25-frontend /root/qubic/hm25-frontend

# Enter the project directory
cd /root/qubic/hm25-frontend

# Install NVM (Node Version Manager)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

# Load NVM immediately
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

# Install the latest LTS version of Node.js
nvm install --lts

# Install pnpm
curl -fsSL https://get.pnpm.io/install.sh | sh -

# Add pnpm to current PATH
export PNPM_HOME="/root/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Verify pnpm is available
pnpm -v

# Install project dependencies
pnpm install

# Get public IP of the server
IP=$(curl -s ifconfig.me)
echo "Detected public IP: $IP"

# Build the React app with the server IP
REACT_APP_HTTP_ENDPOINT=http://$IP pnpm build

# Create the deployment directory
sudo mkdir -p /var/www/hm25

# Copy built frontend files to web directory
sudo cp -r build/* /var/www/hm25/

# Set correct permissions
sudo chown -R www-data:www-data /var/www/hm25
sudo chmod -R 755 /var/www/hm25

# Create the Nginx config file
sudo tee /etc/nginx/sites-available/hm25 > /dev/null <<EOF
server {
    listen 8088;
    server_name $IP;

    root /var/www/hm25;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

# Remove default config if it exists
sudo rm -f /etc/nginx/sites-enabled/default

# Enable the new site config
sudo ln -sf /etc/nginx/sites-available/hm25 /etc/nginx/sites-enabled/hm25

# Test Nginx configuration
sudo nginx -t

# Reload Nginx to apply changes
sudo systemctl reload nginx

# Ensure Nginx is running
sudo systemctl start nginx
sudo systemctl enable nginx

echo "✅ Deployment complete!"
echo "🌐 Open in browser: http://$IP:8088"
