#!/bin/bash
set -e

SERVICE_NAME="ceremony"
WORKDIR="$HOME/trusted-setup-tmp"
NODE_REQUIRED_VERSION="v18"

echo "🚀 Ceremony Auto Setup Starting..."
echo "==================================="

# Function to remove existing Node.js installations
remove_existing_node() {
    echo "🗑️ Removing existing Node.js installations..."
    sudo apt remove --purge -y nodejs npm
    sudo rm -rf /usr/local/bin/node /usr/local/bin/npm
    sudo rm -rf /usr/local/lib/node_modules
    sudo rm -rf /usr/local/include/node
    sudo rm -rf /usr/local/share/man/man1/node.1
    sudo rm -rf ~/.npm
    sudo rm -rf ~/.node-gyp
    sudo rm -rf /opt/local/bin/node
    sudo rm -rf /opt/local/include/node
    sudo rm -rf /opt/local/lib/node_modules
}

# 1️⃣ Update & Install Dependencies
echo "📦 Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git build-essential

# 2️⃣ Remove any existing Node.js and install v18
if command -v node &> /dev/null; then
    current_version=$(node -v)
    if [[ "$current_version" != "$NODE_REQUIRED_VERSION"* ]]; then
        echo "⚠️ Found incompatible Node.js version: $current_version"
        remove_existing_node
    else
        echo "✅ Node.js version compatible: $current_version"
    fi
fi

if ! command -v node &> /dev/null || ! [[ "$(node -v)" == "$NODE_REQUIRED_VERSION"* ]]; then
    echo "📦 Installing Node.js $NODE_REQUIRED_VERSION..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    sudo npm install -g npm@9.2
    echo "✅ Node.js installed: $(node -v)"
    echo "✅ npm installed: $(npm -v)"
fi

# 3️⃣ Create working directory
echo "📂 Setting up working directory..."
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 4️⃣ Install/Update Phase2 CLI
echo "📦 Installing/Updating Phase2 CLI..."
# First remove any existing installation
sudo npm uninstall -g @p0tion/phase2cli || true

# Install specific version that works with Node.js v18
sudo npm install -g @p0tion/phase2cli

# 5️⃣ GitHub Authentication
echo "🔐 Setting up GitHub authentication..."
echo "Please complete the GitHub authentication in the browser window that opens..."
phase2cli auth

# Wait briefly for auth to complete
sleep 5

# 6️⃣ Create systemd service
echo "⚙️ Creating systemd service..."
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# Create temp service file first
TEMP_SERVICE="/tmp/$SERVICE_NAME.service"
cat > "$TEMP_SERVICE" <<EOL
[Unit]
Description=EthStorage Ceremony Contributor Node
After=network.target

[Service]
WorkingDirectory=$WORKDIR
ExecStart=/usr/bin/env bash -c 'yes "" | phase2cli contribute -c ethstorage-v1-trusted-setup-ceremony'
Restart=always
RestartSec=10
User=$USER
Environment="PATH=$PATH"
Environment="HOME=$HOME"

# Add memory limits to prevent excessive usage
MemoryMax=4G
MemoryHigh=3.5G

[Install]
WantedBy=multi-user.target
EOL

# Move with sudo
sudo mv "$TEMP_SERVICE" "$SERVICE_FILE"
sudo chmod 644 "$SERVICE_FILE"

# 7️⃣ Reload and enable service
echo "🔄 Reloading systemd and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable --now $SERVICE_NAME

# Wait a moment for service to start
sleep 3

# Check service status
if sudo systemctl is-active --quiet $SERVICE_NAME; then
    echo "✅ Service started successfully!"
else
    echo "❌ Service failed to start. Check status with: sudo systemctl status $SERVICE_NAME"
    exit 1
fi

echo ""
echo "🎉 Ceremony setup complete!"
echo "==================================="
echo "👉 View logs:          journalctl -u $SERVICE_NAME -f"
echo "👉 Stop service:       sudo systemctl stop $SERVICE_NAME"
echo "👉 Restart service:    sudo systemctl restart $SERVICE_NAME"
echo "👉 Check status:       sudo systemctl status $SERVICE_NAME"
echo ""
echo "📝 The node will automatically contribute to the ceremony and restart if needed"
