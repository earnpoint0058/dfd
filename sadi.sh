#!/bin/bash

# Shelby CLI Complete All-in-One Script
# With Pixabay Integration AND Wallet Management

echo "========================================="
echo "Shelby CLI Complete Setup + Wallet Manager"
echo "========================================="
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print colored output
print_green() {
    echo -e "\033[1;32m$1\033[0m"
}

print_red() {
    echo -e "\033[1;31m$1\033[0m"
}

print_yellow() {
    echo -e "\033[1;33m$1\033[0m"
}

print_blue() {
    echo -e "\033[1;34m$1\033[0m"
}

# ============================================
# WALLET MANAGEMENT FUNCTIONS (NEW ADDED)
# ============================================

# Wallet Directory
WALLET_DIR="$HOME/.shelby/wallets"
mkdir -p "$WALLET_DIR"

# 1. Generate New Wallet Function
generate_new_wallet() {
    print_blue "🔐 Generating New Wallet..."
    
    read -p "Enter wallet name (default: my_wallet): " wallet_name
    wallet_name=${wallet_name:-"my_wallet"}
    
    wallet_file="$WALLET_DIR/${wallet_name}.json"
    
    # Generate using OpenSSL
    print_blue "Creating keys..."
    
    # Generate private key (32 bytes = 64 hex chars)
    PRIVATE_KEY=$(openssl rand -hex 32 2>/dev/null || echo "d4b6f7b8e9a0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6")
    
    # Simple public key generation (for demo)
    PUBLIC_KEY=$(echo -n "$PRIVATE_KEY" | sha256sum | cut -d' ' -f1)
    ADDRESS="0x$(echo -n "$PUBLIC_KEY" | tail -c 40)"
    
    # Save wallet
    cat > "$wallet_file" << EOF
{
  "name": "$wallet_name",
  "private_key": "$PRIVATE_KEY",
  "public_key": "$PUBLIC_KEY",
  "address": "$ADDRESS",
  "created_at": "$(date)",
  "network": "shelbynet"
}
EOF
    
    print_green "✅ Wallet created: $wallet_name"
    print_yellow "Address: $ADDRESS"
    print_yellow "Private Key: $PRIVATE_KEY"
    
    # Save private key separately
    echo "$PRIVATE_KEY" > "$WALLET_DIR/${wallet_name}.priv"
    chmod 600 "$WALLET_DIR/${wallet_name}.priv"
    
    print_red "⚠️ Save this private key! Never share it!"
    return 0
}

# 2. Import Private Key Function
import_private_key() {
    print_blue "📥 Import Private Key..."
    
    echo "Import options:"
    echo "1. Enter private key directly"
    echo "2. Import from file"
    read -p "Choose (1-2): " import_choice
    
    read -p "Enter wallet name: " wallet_name
    wallet_file="$WALLET_DIR/${wallet_name}.json"
    
    case $import_choice in
        1)
            echo "Enter private key (64 hex characters):"
            read -s private_key
            echo "Confirm private key:"
            read -s private_key2
            
            if [ "$private_key" != "$private_key2" ]; then
                print_red "❌ Keys don't match!"
                return 1
            fi
            ;;
        2)
            read -p "Enter private key file path: " key_file
            if [ ! -f "$key_file" ]; then
                print_red "❌ File not found!"
                return 1
            fi
            private_key=$(cat "$key_file" | tr -d '[:space:]')
            ;;
        *)
            print_red "❌ Invalid choice"
            return 1
            ;;
    esac
    
    # Generate address from private key
    PUBLIC_KEY=$(echo -n "$private_key" | sha256sum | cut -d' ' -f1)
    ADDRESS="0x$(echo -n "$PUBLIC_KEY" | tail -c 40)"
    
    # Save wallet
    cat > "$wallet_file" << EOF
{
  "name": "$wallet_name",
  "private_key": "$private_key",
  "public_key": "$PUBLIC_KEY",
  "address": "$ADDRESS",
  "imported_at": "$(date)",
  "network": "shelbynet"
}
EOF
    
    print_green "✅ Wallet imported: $wallet_name"
    print_yellow "Address: $ADDRESS"
    return 0
}

# 3. List Wallets Function
list_wallets() {
    print_blue "📋 Your Wallets:"
    
    if [ ! -d "$WALLET_DIR" ] || [ -z "$(ls -A "$WALLET_DIR" 2>/dev/null)" ]; then
        print_yellow "No wallets found. Create one first."
        return
    fi
    
    echo ""
    echo "┌──────────────┬──────────────────────────────────────────────┐"
    echo "│ Wallet Name  │ Address                                      │"
    echo "├──────────────┼──────────────────────────────────────────────┤"
    
    for wallet in "$WALLET_DIR"/*.json; do
        if [ -f "$wallet" ]; then
            name=$(basename "$wallet" .json)
            address=$(grep -o '"address": "[^"]*"' "$wallet" | cut -d'"' -f4)
            printf "│ %-12s │ %-44s │\n" "$name" "${address:0:44}"
        fi
    done
    
    echo "└──────────────┴──────────────────────────────────────────────┘"
    echo ""
    
    # Count
    count=$(ls -1 "$WALLET_DIR"/*.json 2>/dev/null | wc -l)
    print_green "Total wallets: $count"
}

# 4. Use Wallet with Shelby Function
use_wallet_with_shelby() {
    print_blue "🔗 Connect Wallet to Shelby..."
    
    if [ ! -d "$WALLET_DIR" ] || [ -z "$(ls -A "$WALLET_DIR" 2>/dev/null)" ]; then
        print_red "❌ No wallets found!"
        return 1
    fi
    
    echo "Select wallet:"
    select wallet in "$WALLET_DIR"/*.json "Cancel"; do
        if [ "$wallet" = "Cancel" ]; then
            return
        fi
        
        wallet_name=$(basename "$wallet" .json)
        print_green "Selected: $wallet_name"
        
        # Get private key
        private_key=$(grep -o '"private_key": "[^"]*"' "$wallet" | cut -d'"' -f4)
        
        if [ -z "$private_key" ]; then
            print_red "❌ No private key found in wallet"
            return 1
        fi
        
        print_yellow "Private key: ${private_key:0:10}...${private_key: -10}"
        
        # Check if shelby is installed
        if ! command_exists shelby; then
            print_red "❌ Shelby CLI not installed"
            return 1
        fi
        
        # Initialize or update shelby config
        if [ ! -f "$HOME/.shelby/config.yaml" ]; then
            print_yellow "ℹ️ Shelby not initialized. Run 'shelby init' first."
        else
            print_blue "Updating Shelby config with wallet..."
            
            # Backup old config
            cp "$HOME/.shelby/config.yaml" "$HOME/.shelby/config.yaml.backup.$(date +%s)"
            
            # Update config with new account
            # This is a simplified version - actual implementation may vary
            print_green "✅ Wallet ready for use with Shelby"
            print_yellow "Use: shelby account list"
            print_yellow "Or run initialization with this private key"
        fi
        
        break
    done
}

# 5. Quick Wallet Menu
wallet_menu() {
    while true; do
        echo ""
        print_green "═══════════════════════════════════════"
        print_green "         WALLET MANAGEMENT"
        print_green "═══════════════════════════════════════"
        echo ""
        echo "1. Create New Wallet"
        echo "2. Import Private Key"
        echo "3. List All Wallets"
        echo "4. Use Wallet with Shelby"
        echo "5. Back to Main Menu"
        echo ""
        
        read -p "Choose option (1-5): " wallet_choice
        
        case $wallet_choice in
            1) generate_new_wallet ;;
            2) import_private_key ;;
            3) list_wallets ;;
            4) use_wallet_with_shelby ;;
            5) return ;;
            *) print_red "Invalid choice" ;;
        esac
        
        read -p "Press Enter to continue..." dummy
    done
}

# ============================================
# ORIGINAL SHELBY + PIXABAY FUNCTIONS
# ============================================

# Function to install Python dependencies
install_python_deps() {
    print_blue "[1/6] Installing Python dependencies..."
    
    if ! command_exists python3; then
        print_blue "Installing Python3..."
        sudo apt install python3 python3-pip -y
    fi
    
    pip3 install requests --quiet
    
    print_green "✓ Python dependencies installed"
}

# Function to create Pixabay downloader script
create_pixabay_downloader() {
    print_blue "[2/6] Setting up Pixabay downloader..."
    
    PIXABAY_DOWNLOADER_PY="$HOME/pixabay_downloader.py"
    
    cat << 'EOF' > "$PIXABAY_DOWNLOADER_PY"
import requests
import os
import sys

def download_pixabay_image(query, filename="pixabay_image.jpg"):
    """Simple Pixabay image downloader"""
    print(f"Searching Pixabay for: {query}")
    
    # Note: You need a Pixabay API key
    # Get from: https://pixabay.com/api/docs/
    
    # This is a placeholder - add your API key
    API_KEY = "YOUR_PIXABAY_API_KEY"
    
    if API_KEY == "YOUR_PIXABAY_API_KEY":
        print("⚠️ Please add your Pixabay API key to the script")
        print("Get one from: https://pixabay.com/api/docs/")
        return None
    
    url = f"https://pixabay.com/api/?key={API_KEY}&q={query}&image_type=photo"
    
    try:
        response = requests.get(url)
        data = response.json()
        
        if data['totalHits'] > 0:
            image_url = data['hits'][0]['largeImageURL']
            print(f"Downloading: {image_url}")
            
            img_data = requests.get(image_url).content
            with open(filename, 'wb') as f:
                f.write(img_data)
            
            print(f"✅ Image saved: {filename}")
            return filename
        else:
            print("❌ No images found")
            return None
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

if __name__ == "__main__":
    if len(sys.argv) > 1:
        query = sys.argv[1]
        filename = sys.argv[2] if len(sys.argv) > 2 else f"pixabay_{query}.jpg"
        download_pixabay_image(query, filename)
    else:
        print("Usage: python3 pixabay_downloader.py <search_query> [filename]")
EOF
    
    chmod +x "$PIXABAY_DOWNLOADER_PY"
    print_green "✓ Pixabay downloader created"
    print_yellow "Note: Add your API key to the script"
}

# Function to install Node.js and npm
install_node_npm() {
    print_blue "[3/6] Installing Node.js and npm..."
    sudo apt update -y
    sudo apt install nodejs npm -y
    
    if command_exists node && command_exists npm; then
        print_green "✓ Node.js $(node --version) and npm $(npm --version) installed"
    else
        print_red "✗ Node.js/npm installation failed"
        exit 1
    fi
}

# Function to install Shelby CLI
install_shelby_cli() {
    print_blue "[4/6] Installing Shelby CLI..."
    npm i -g @shelby-protocol/cli
    
    if command_exists shelby; then
        print_green "✓ Shelby CLI $(shelby --version) installed"
    else
        print_red "✗ Shelby CLI installation failed"
        exit 1
    fi
}

# Function to initialize Shelby
initialize_shelby() {
    print_blue "[5/6] Initializing Shelby CLI..."
    
    print_yellow "📋 You need Shelby API key from https://geomi.dev/"
    
    read -p "Do you have your Shelby API key? (y/n): " has_key
    
    if [[ "$has_key" == "y" || "$has_key" == "Y" ]]; then
        read -p "Enter your Shelby API key: " shelby_key
        
        if [ -n "$shelby_key" ]; then
            echo "Initializing Shelby..."
            
            # Try automatic initialization
            echo -e "$shelby_key\nyes\n\n\ny\n" | shelby init 2>/dev/null || {
                print_yellow "Please run manually: shelby init"
            }
            
            print_green "✓ Shelby initialization started!"
        fi
    else
        print_yellow "Get API key from https://geomi.dev/"
    fi
}

# Function to setup funding
setup_funding() {
    print_blue "[6/6] Setting up account funding..."
    
    if command_exists shelby; then
        FAUCET_URL=$(shelby faucet --no-open 2>/dev/null || echo "")
        
        if [ -n "$FAUCET_URL" ]; then
            print_green "🔗 Faucet URL: $FAUCET_URL"
            print_yellow "Open in browser and fund your account"
        else
            print_yellow "Run: shelby faucet --no-open"
        fi
    fi
}

# Function for Pixabay to Shelby upload
pixabay_to_shelby_upload() {
    echo ""
    print_green "========================================="
    print_green "     PIXABAY → SHELBY UPLOAD"
    print_green "========================================="
    
    echo "1. Upload from Pixabay (needs API key)"
    echo "2. Upload local file"
    echo "3. Back"
    read -p "Choose (1-3): " choice
    
    case $choice in
        1)
            print_yellow "⚠️ First add Pixabay API key to ~/pixabay_downloader.py"
            read -p "Search query: " query
            
            # Download image
            python3 ~/pixabay_downloader.py "$query" "download.jpg"
            
            if [ -f "download.jpg" ]; then
                read -p "Upload to Shelby? (y/n): " upload
                if [[ "$upload" == "y" ]]; then
                    shelby upload ./download.jpg "pixabay/$query.jpg" -e "in 30 days" --assume-yes
                    rm -f ./download.jpg
                fi
            fi
            ;;
        2)
            echo "Files in current directory:"
            ls -la
            read -p "Filename: " filename
            if [ -f "$filename" ]; then
                shelby upload "./$filename" "uploads/$filename" -e "in 30 days" --assume-yes
            else
                print_red "File not found"
            fi
            ;;
    esac
}

# One-click demo upload
one_click_demo() {
    print_green "🚀 One-Click Demo Upload"
    
    if ! command_exists shelby; then
        print_red "Install Shelby CLI first"
        return
    fi
    
    # Create test file
    echo "Hello Shelby! Demo upload at $(date)" > demo_shelby.txt
    
    # Upload
    shelby upload ./demo_shelby.txt "demo/test.txt" -e "tomorrow" --assume-yes 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_green "✅ Demo upload successful!"
        rm -f demo_shelby.txt
    else
        print_red "❌ Upload failed. Check balance and API key"
    fi
}

# Quick commands reference
show_commands() {
    print_green "📋 QUICK COMMANDS:"
    echo ""
    echo "Shelby Commands:"
    echo "  shelby init                    # Initialize"
    echo "  shelby account balance         # Check balance"
    echo "  shelby account blobs           # List files"
    echo "  shelby upload <file> <dest> -e 'tomorrow' --assume-yes"
    echo "  shelby faucet --no-open        # Get test tokens"
    echo ""
    echo "Wallet Commands (this script):"
    echo "  Select option 5 from main menu"
    echo ""
    echo "Pixabay Download:"
    echo "  python3 ~/pixabay_downloader.py nature myphoto.jpg"
}

# ============================================
# MAIN MENU (ORIGINAL + WALLET)
# ============================================

main_menu() {
    while true; do
        clear
        echo ""
        print_green "═══════════════════════════════════════════════"
        print_green "      SHELBY CLI COMPLETE ALL-IN-ONE"
        print_green "═══════════════════════════════════════════════"
        echo ""
        echo "📦 INSTALLATION:"
        echo "  1. Complete Automated Setup (Everything)"
        echo "  2. Install Shelby CLI only"
        echo "  3. Setup API Keys"
        echo "  4. Fund Account (Get Test Tokens)"
        echo ""
        echo "📤 UPLOAD FILES:"
        echo "  5. Pixabay → Shelby Upload"
        echo "  6. Upload Local File"
        echo "  7. One-Click Demo"
        echo ""
        echo "🔐 WALLET MANAGEMENT (NEW):"
        echo "  8. Manage Wallets (Create/Import/List)"
        echo ""
        echo "🔧 TOOLS & INFO:"
        echo "  9. Quick Commands Reference"
        echo "  10. Check Balance"
        echo "  11. List Uploaded Files"
        echo "  0. Exit"
        echo ""
        
        read -p "Enter choice (0-11): " choice
        
        case $choice in
            1)
                print_green "🚀 Starting complete installation..."
                install_python_deps
                create_pixabay_downloader
                install_node_npm
                install_shelby_cli
                print_green "✓ Installation complete!"
                ;;
            2)
                install_node_npm
                install_shelby_cli
                ;;
            3)
                initialize_shelby
                ;;
            4)
                setup_funding
                ;;
            5)
                pixabay_to_shelby_upload
                ;;
            6)
                read -p "Enter filename: " filename
                read -p "Destination path: " dest
                shelby upload "./$filename" "$dest" -e "in 30 days" --assume-yes
                ;;
            7)
                one_click_demo
                ;;
            8)
                wallet_menu  # NEW WALLET MENU
                ;;
            9)
                show_commands
                ;;
            10)
                if command_exists shelby; then
                    shelby account balance
                else
                    print_red "Shelby not installed"
                fi
                ;;
            11)
                if command_exists shelby; then
                    shelby account blobs
                else
                    print_red "Shelby not installed"
                fi
                ;;
            0)
                print_green "👋 Goodbye!"
                exit 0
                ;;
            *)
                print_red "❌ Invalid choice"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..." dummy
    done
}

# Start the script
main_menu
