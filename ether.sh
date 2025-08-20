#!/bin/bash
set -e

SERVICE_NAME="ceremony"
WORKDIR="$HOME/trusted-setup-tmp"
NODE_REQUIRED_VERSION="v18"

echo "🚀 Ceremony Auto Setup Starting..."
echo "==================================="

# Function to completely remove all Node.js versions
remove_all_nodejs() {
    echo "🗑️ Removing all existing Node.js installations..."
    
    # Stop any running node processes
    pkill -f node || true
    sudo pkill -f node || true
    
    # Remove apt packages
    sudo apt remove --purge -y nodejs npm
    
    # Remove manually installed node
    sudo rm -rf /usr/local/bin/node
    sudo rm -rf /usr/local/bin/npm
    sudo rm -rf /usr/local/bin/npx
    sudo rm -rf /usr/local/lib/node_modules
    sudo rm -rf /usr/local/include/node
    sudo rm -rf /usr/local/share/man/man1/node.1
    
    # Remove nvm if installed
    rm -rf ~/.nvm
    
    # Remove other common node locations
    sudo rm -rf /opt/local/bin/node
    sudo rm -rf /opt/local/include/node
    sudo rm -rf /opt/local/lib/node_modules
    
    # Clean up directories
    rm -rf ~/.npm
    rm -rf ~/.node-gyp
    sudo rm -rf /var/lib/apt/lists/lock
    sudo rm -rf /var/cache/apt/archives/lock
    sudo rm -rf /var/lib/dpkg/lock
    
    # Clean environment variables
    unset NVM_DIR
    unset NODE_PATH
    
    echo "✅ All Node.js installations removed"
}

# 1️⃣ Update & Install Dependencies
echo "📦 Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git build-essential

# 2️⃣ Remove ALL existing Node.js installations
remove_all_nodejs

# 3️⃣ Install Node.js v18 using the official NodeSource method
echo "📦 Installing Node.js v18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
echo "✅ Node.js installed: $(node -v)"
echo "✅ npm installed: $(npm -v)"

# Check if we have the right version
if ! [[ "$(node -v)" == "v18"* ]]; then
    echo "❌ ERROR: Wrong Node.js version installed. Expected v18.x, got $(node -v)"
    echo "Trying alternative installation method..."
    
    # Alternative method using nodesource directly
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
    sudo apt-get install -y nodejs
    
    if ! [[ "$(node -v)" == "v18"* ]]; then
        echo "❌ CRITICAL: Still wrong Node.js version: $(node -v)"
        echo "Please manually install Node.js v18 and try again"
        exit 1
    fi
fi

# 4️⃣ Create working directory
echo "📂 Setting up working directory..."
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 5️⃣ Install Phase2 CLI with specific working directory
echo "📦 Installing Phase2 CLI..."
# Remove any existing installation completely
sudo npm uninstall -g @p0tion/phase2cli || true
rm -rf ~/.npm/_libvips ~/.npm/_cacache || true

# Install with clean cache
sudo npm cache clean -f
sudo npm install -g @p0tion/phase2cli

# Verify installation
if ! command -v phase2cli &> /dev/null; then
    echo "❌ phase2cli installation failed"
    exit 1
fi

echo "✅ Phase2 CLI installed: $(phase2cli --version)"

# 6️⃣ GitHub Authentication
echo "🔐 Setting up GitHub authentication..."
echo "Please complete the GitHub authentication when prompted..."
phase2cli auth

echo ""
read -p "✅ Have you completed the GitHub authentication? (yes/no): " AUTH_CONFIRM
if [[ "$AUTH_CONFIRM" != "yes" ]]; then
    echo "❌ GitHub authentication not confirmed. Please run 'phase2cli auth' manually."
    exit 1
fi

# 7️⃣ Create systemd service with explicit Node.js path
echo "⚙️ Creating systemd service..."

# Get the actual path to node
NODE_PATH=$(which node)
echo "📝 Using Node.js at: $NODE_PATH"

SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# Create temp service file first
TEMP_SERVICE="/tmp/$SERVICE_NAME.service"
cat > "$TEMP_SERVICE" <<EOL
[Unit]
Description=EthStorage Ceremony Contributor Node
After=network.target

[Service]
WorkingDirectory=$WORKDIR
ExecStart=$NODE_PATH $(which phase2cli) contribute -c ethstorage-v1-trusted-setup-ceremony --yes
Restart=always
RestartSec=30
User=$USER
Environment="PATH=$PATH"
Environment="HOME=$HOME"

# Resource limits
MemoryMax=4G
MemoryHigh=3.5G
CPUQuota=200%

# Standard output logging
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL

# Move with sudo and set permissions
sudo mv "$TEMP_SERVICE" "$SERVICE_FILE"
sudo chmod 644 "$SERVICE_FILE"

# 8️⃣ Reload and enable service
echo "🔄 Reloading systemd and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable --now $SERVICE_NAME

# Wait a moment for service to start
sleep 5

# Check service status
if sudo systemctl is-active --quiet $SERVICE_NAME; then
    echo "✅ Service started successfully!"
    echo "📊 Service status:"
    sudo systemctl status $SERVICE_NAME --no-pager -l
else
    echo "❌ Service failed to start. Checking status..."
    sudo systemctl status $SERVICE_NAME --no-pager -l
    echo "📋 Last logs:"
    journalctl -u $SERVICE_NAME -n 20 --no-pager
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
echo "📝 The node will automatically contribute to the ceremony"
echo "📝 Using Node.js version: $(node -v)"
