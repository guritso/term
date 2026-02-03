#!/bin/bash

# Deploy script - move files from dev to nginx prod

# Detect dev directory (where this script is located)
DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROD_DIR="/usr/share/nginx/html"
NGINX_CONF_DIR="/etc/nginx"

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    echo "Error: nginx is not installed"
    exit 1
fi

# Array with current files and directories (excluding deploy.sh)
ITEMS=(
    "index.html"
    "favicon.svg"
    "robots.txt"
    "crontabs"
    "github_repos"
    "pages"
    "recent_animes"
    "scripts"
    "nginx.conf"
    "locations.conf"
)

echo "Deploying from $DEV_DIR..."

# Check if running with sudo access
if ! sudo -n true 2>/dev/null; then
    echo "Error: sudo access required"
    exit 1
fi

# Copy each item
for item in "${ITEMS[@]}"; do
    src="$DEV_DIR/$item"
    
    # Handle nginx.conf separately (goes to /etc/nginx/)
    if [ "$item" == "nginx.conf" ]; then
        dest="$NGINX_CONF_DIR/nginx.conf"
        if [ -e "$src" ]; then
            echo "Copying nginx config: $item"
            sudo cp "$src" "$dest"
            sudo chown root:root "$dest"
        else
            echo "Warning: $item not found"
        fi
        continue
    fi
    
    # Regular items go to PROD_DIR
    dest="$PROD_DIR/$item"
    
    if [ -e "$src" ]; then
        if [ -d "$src" ]; then
            # It's a directory
            echo "Copying directory: $item"
            sudo rm -rf "$dest" 2>/dev/null
            sudo cp -r "$src" "$dest"
        else
            # It's a file
            echo "Copying file: $item"
            sudo cp "$src" "$dest"
        fi
        sudo chown -R root:root "$dest"
    else
        echo "Warning: $item not found"
    fi
done

echo "Files deployed successfully!"
echo "Running index script..."  
# Run the index script
chmod +x $DEV_DIR/scripts/index.sh
$DEV_DIR/scripts/index.sh

echo "Index script executed!."
echo "Reloading nginx..."

# Reload nginx
sudo nginx -s reload

echo "Done!"
