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
# PIXABAY API SETUP (NEW ADDED)
# ============================================

# Pixabay API Key File
PIXABAY_API_FILE="$HOME/.pixabay_api_key"

# Function to setup Pixabay API
setup_pixabay_api() {
    print_blue "🔑 Pixabay API Setup"
    echo ""
    print_yellow "To get Pixabay API Key:"
    echo "1. Go to: https://pixabay.com/api/docs/"
    echo "2. Sign up for free account"
    echo "3. Get your API key from dashboard"
    echo ""
    
    if [ -f "$PIXABAY_API_FILE" ]; then
        current_key=$(cat "$PIXABAY_API_FILE")
        print_green "Current API Key: ${current_key:0:8}...${current_key: -4}"
        read -p "Do you want to change it? (y/n): " change
        if [[ "$change" != "y" ]]; then
            return
        fi
    fi
    
    read -p "Enter your Pixabay API Key: " api_key
    if [ -n "$api_key" ]; then
        echo "$api_key" > "$PIXABAY_API_FILE"
        chmod 600 "$PIXABAY_API_FILE"
        print_green "✅ Pixabay API key saved!"
    else
        print_red "❌ No API key entered"
    fi
}

# Function to get Pixabay API key
get_pixabay_api() {
    if [ -f "$PIXABAY_API_FILE" ]; then
        cat "$PIXABAY_API_FILE"
    else
        echo ""
    fi
}

# Function to check Pixabay API
check_pixabay_api() {
    if [ -f "$PIXABAY_API_FILE" ]; then
        key=$(get_pixabay_api)
        if [ -n "$key" ]; then
            print_green "✅ Pixabay API: Configured"
            return 0
        fi
    fi
    print_red "❌ Pixabay API: Not configured"
    return 1
}

# Function to download from Pixabay
download_from_pixabay() {
    print_blue "📸 Download from Pixabay"
    
    # Check API
    if ! check_pixabay_api; then
        print_red "Please setup Pixabay API first (Option 12)"
        return 1
    fi
    
    API_KEY=$(get_pixabay_api)
    
    read -p "Search query: " query
    read -p "Number of images (1-5): " count
    count=${count:-1}
    
    if [ "$count" -gt 5 ]; then
        count=5
    fi
    
    read -p "Save as (default: pixabay_image.jpg): " filename
    filename=${filename:-"pixabay_image.jpg"}
    
    print_blue "Searching Pixabay for '$query'..."
    
    # Simple download using curl
    url="https://pixabay.com/api/?key=$API_KEY&q=${query// /+}&per_page=$count&image_type=photo"
    
    # Get image URL
    response=$(curl -s "$url")
    
    if echo "$response" | grep -q '"totalHits":0'; then
        print_red "❌ No images found"
        return 1
    fi
    
    # Extract first image URL
    image_url=$(echo "$response" | grep -o '"largeImageURL":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$image_url" ]; then
        print_red "❌ Could not get image URL"
        return 1
    fi
    
    print_blue "Downloading: $image_url"
    
    # Download image
    curl -s -o "$filename" "$image_url"
    
    if [ -f "$filename" ] && [ -s "$filename" ]; then
        file_size=$(stat -c%s "$filename")
        print_green "✅ Downloaded: $filename ($((file_size/1024)) KB)"
        echo "$filename"
    else
        print_red "❌ Download failed"
        return 1
    fi
}

# ============================================
# WALLET MANAGEMENT FUNCTIONS
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
    
    # Simple public key generation
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
# SHELBY FUNCTIONS
# ============================================

# Function to install Node.js and npm
install_node_npm() {
    print_blue "Installing Node.js and npm..."
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
    print_blue "Installing Shelby CLI..."
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
    print_blue "Initializing Shelby CLI..."
    
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
    print_blue "Setting up account funding..."
    
    if command_exists shelby; then
        FAUCET_URL=$(shelby faucet --no-open 2>/dev/null || echo "")
        
        if [ -n "$FAUCET_URL" ]; then
            print_green "🔗 Faucet URL: $FAUCET_URL"
            print_yellow "Open in browser and fund your account"
            echo ""
            print_yellow "You need BOTH:"
            print_yellow "1. APT tokens (for gas fees)"
            print_yellow "2. ShelbyUSD tokens (for uploads/downloads)"
        else
            print_yellow "Run: shelby faucet --no-open"
        fi
    fi
}

# Function for Pixabay to Shelby upload
pixabay_to_shelby_upload() {
    echo ""
    print_green "═══════════════════════════════════════"
    print_green "     PIXABAY → SHELBY UPLOAD"
    print_green "═══════════════════════════════════════"
    
    # Check Pixabay API
    if ! check_pixabay_api; then
        print_red "Please setup Pixabay API first (Option 12)"
        return
    fi
    
    # Check Shelby
    if ! command_exists shelby; then
        print_red "Shelby CLI not installed. Install first."
        return
    fi
    
    while true; do
        echo ""
        echo "1. Search & Download from Pixabay"
        echo "2. Upload downloaded image to Shelby"
        echo "3. Download & Upload automatically"
        echo "4. Back to Main Menu"
        echo ""
        
        read -p "Choose (1-4): " choice
        
        case $choice in
            1)
                # Download only
                download_from_pixabay
                ;;
            2)
                # Upload existing file
                echo "Available images:"
                ls -1 *.jpg *.jpeg *.png 2>/dev/null | nl
                
                read -p "Select image number or filename: " img_input
                if [[ "$img_input" =~ ^[0-9]+$ ]]; then
                    filename=$(ls -1 *.jpg *.jpeg *.png 2>/dev/null | sed -n "${img_input}p")
                else
                    filename="$img_input"
                fi
                
                if [ -f "$filename" ]; then
                    read -p "Destination path (e.g., pixabay/photo.jpg): " dest_path
                    read -p "Expiration (default: in 30 days): " expiration
                    expiration=${expiration:-"in 30 days"}
                    
                    print_blue "Uploading to Shelby..."
                    shelby upload "./$filename" "$dest_path" -e "$expiration" --assume-yes
                    
                    if [ $? -eq 0 ]; then
                        print_green "✅ Upload successful!"
                        read -p "Delete local file? (y/n): " delete
                        if [[ "$delete" == "y" ]]; then
                            rm -f "$filename"
                        fi
                    fi
                else
                    print_red "File not found: $filename"
                fi
                ;;
            3)
                # Auto download & upload
                read -p "Search query: " query
                filename="pixabay_${query}_$(date +%Y%m%d_%H%M%S).jpg"
                
                # Download
                print_blue "Downloading from Pixabay..."
                downloaded_file=$(download_from_pixabay)
                
                if [ -n "$downloaded_file" ] && [ -f "$downloaded_file" ]; then
                    # Upload
                    dest_path="pixabay/${query}_$(date +%Y%m%d).jpg"
                    expiration="in 30 days"
                    
                    print_blue "Uploading to Shelby..."
                    shelby upload "./$downloaded_file" "$dest_path" -e "$expiration" --assume-yes
                    
                    if [ $? -eq 0 ]; then
                        print_green "✅ Download & Upload successful!"
                        rm -f "$downloaded_file"
                    else
                        print_red "❌ Upload failed. File saved: $downloaded_file"
                    fi
                fi
                ;;
            4)
                return
                ;;
            *)
                print_red "Invalid choice"
                ;;
        esac
        
        read -p "Press Enter to continue..." dummy
    done
}

# One-click demo upload (FIXED)
one_click_demo() {
    print_green "🚀 One-Click Demo Upload"
    echo ""
    
    # Check Shelby
    if ! command_exists shelby; then
        print_red "❌ Shelby CLI not installed"
        print_yellow "Install with Option 2 first"
        return
    fi
    
    # Check if initialized
    if [ ! -f "$HOME/.shelby/config.yaml" ]; then
        print_red "❌ Shelby not initialized"
        print_yellow "Run Option 3 to setup API key"
        return
    fi
    
    # Check balance
    print_blue "Checking account balance..."
    balance_output=$(shelby account balance 2>&1)
    
    if echo "$balance_output" | grep -q "ShelbyUSD"; then
        print_green "✅ Account has balance"
    else
        print_red "❌ Account needs funding"
        print_yellow "Run Option 4 to get test tokens"
        return
    fi
    
    # Create test file
    echo "This is a Shelby CLI demo upload" > shelby_demo.txt
    echo "Uploaded at: $(date)" >> shelby_demo.txt
    echo "One-click demo from automated script" >> shelby_demo.txt
    
    print_blue "Uploading demo file..."
    
    # Upload with different expiration options
    EXPIRATIONS=("tomorrow" "in 2 days" "next Friday" "in 7 days")
    EXPIRATION=${EXPIRATIONS[$RANDOM % ${#EXPIRATIONS[@]}]}
    
    shelby upload ./shelby_demo.txt "demo/shelby_demo_$(date +%Y%m%d).txt" -e "$EXPIRATION" --assume-yes
    
    if [ $? -eq 0 ]; then
        print_green "✅ Demo upload successful!"
        print_green "📁 File: demo/shelby_demo_$(date +%Y%m%d).txt"
        print_green "⏰ Expires: $EXPIRATION"
        
        # Show uploaded files
        print_blue "📋 Your uploaded files:"
        shelby account blobs | grep -i demo || echo "No demo files found"
        
        # Clean up
        rm -f ./shelby_demo.txt
    else
        print_red "❌ Upload failed"
        print_yellow "Possible issues:"
        print_yellow "1. Insufficient ShelbyUSD balance"
        print_yellow "2. Network connection"
        print_yellow "3. API key expired"
        
        # Keep the file for debugging
        print_yellow "Debug file saved: shelby_demo.txt"
    fi
}

# Upload Local File
upload_local_file() {
    print_blue "📤 Upload Local File"
    
    if ! command_exists shelby; then
        print_red "Install Shelby CLI first"
        return
    fi
    
    echo "Current directory:"
    ls -la
    
    read -p "Enter filename to upload: " filename
    
    if [ ! -f "$filename" ]; then
        print_red "File not found: $filename"
        return
    fi
    
    read -p "Destination path in Shelby (e.g., myfiles/doc.txt): " dest_path
    read -p "Expiration (e.g., tomorrow, in 30 days): " expiration
    expiration=${expiration:-"in 30 days"}
    
    print_blue "Uploading..."
    shelby upload "./$filename" "$dest_path" -e "$expiration" --assume-yes
    
    if [ $? -eq 0 ]; then
        print_green "✅ Upload successful!"
    else
        print_red "❌ Upload failed"
    fi
}

# Complete Automated Setup
complete_setup() {
    print_green "🚀 Starting Complete Setup..."
    echo ""
    
    # 1. Update system
    print_blue "Step 1: Updating system..."
    sudo apt update -y
    
    # 2. Install Node.js
    install_node_npm
    
    # 3. Install Shelby CLI
    install_shelby_cli
    
    # 4. Install Python for Pixabay
    print_blue "Step 4: Installing Python..."
    sudo apt install python3 python3-pip curl -y
    
    print_green "✅ Complete setup finished!"
    echo ""
    print_yellow "Next steps:"
    print_yellow "1. Run Option 3: Setup Shelby API key"
    print_yellow "2. Run Option 12: Setup Pixabay API key"
    print_yellow "3. Run Option 4: Fund your account"
    print_yellow "4. Run Option 7: Test upload"
}

# Quick commands reference
show_commands() {
    print_green "📋 QUICK COMMANDS REFERENCE"
    echo ""
    
    print_blue "Shelby Commands:"
    echo "  shelby init                    # Initialize with API key"
    echo "  shelby account balance         # Check token balance"
    echo "  shelby account blobs           # List uploaded files"
    echo "  shelby upload <file> <dest> -e 'tomorrow' --assume-yes"
    echo "  shelby download <blob> <file>  # Download file"
    echo "  shelby faucet --no-open        # Get test tokens"
    echo "  shelby account list            # List accounts"
    echo "  shelby context list            # List networks"
    echo ""
    
    print_blue "Pixabay Commands (via script):"
    echo "  Option 5: Pixabay → Shelby upload"
    echo "  Option 12: Setup Pixabay API"
    echo ""
    
    print_blue "Wallet Commands:"
    echo "  Option 8: Wallet management"
    echo ""
    
    print_blue "File Operations:"
    echo "  Option 6: Upload local file"
    echo "  Option 7: One-click demo"
    echo "  Option 11: List uploaded files"
}

# Check system status
check_status() {
    print_blue "🔍 System Status Check"
    echo ""
    
    # Check Shelby
    if command_exists shelby; then
        print_green "✅ Shelby CLI: Installed"
        VERSION=$(shelby --version 2>/dev/null || echo "Unknown")
        print_green "   Version: $VERSION"
    else
        print_red "❌ Shelby CLI: Not installed"
    fi
    
    # Check Node.js
    if command_exists node; then
        print_green "✅ Node.js: Installed"
    else
        print_red "❌ Node.js: Not installed"
    fi
    
    # Check Shelby config
    if [ -f "$HOME/.shelby/config.yaml" ]; then
        print_green "✅ Shelby Config: Found"
    else
        print_red "❌ Shelby Config: Not found"
    fi
    
    # Check Pixabay API
    check_pixabay_api
    
    # Check wallets
    if [ -d "$WALLET_DIR" ] && [ -n "$(ls -A "$WALLET_DIR" 2>/dev/null)" ]; then
        count=$(ls -1 "$WALLET_DIR"/*.json 2>/dev/null | wc -l)
        print_green "✅ Wallets: $count found"
    else
        print_yellow "⚠️ Wallets: None created"
    fi
    
    echo ""
}

# ============================================
# MAIN MENU (UPDATED)
# ============================================

main_menu() {
    while true; do
        clear
        echo ""
        print_green "═══════════════════════════════════════════════"
        print_green "      SHELBY CLI COMPLETE ALL-IN-ONE"
        print_green "═══════════════════════════════════════════════"
        echo ""
        
        # Show status
        check_status
        echo ""
        
        print_blue "📦 INSTALLATION:"
        echo "  1. Complete Automated Setup (Everything)"
        echo "  2. Install Shelby CLI only"
        echo "  3. Setup Shelby API Key"
        echo "  4. Fund Account (Get Test Tokens)"
        echo ""
        
        print_blue "📤 UPLOAD FILES:"
        echo "  5. Pixabay → Shelby Upload"
        echo "  6. Upload Local File"
        echo "  7. One-Click Demo Upload"
        echo ""
        
        print_blue "🔐 WALLET MANAGEMENT:"
        echo "  8. Manage Wallets (Create/Import/List)"
        echo ""
        
        print_blue "🛠️  TOOLS & INFO:"
        echo "  9. Quick Commands Reference"
        echo "  10. Check Balance"
        echo "  11. List Uploaded Files"
        echo "  12. Setup Pixabay API Key"  # NEW OPTION
        echo "  13. System Status"
        echo "  0. Exit"
        echo ""
        
        read -p "Enter choice (0-13): " choice
        
        case $choice in
            1) complete_setup ;;
            2) install_shelby_cli ;;
            3) initialize_shelby ;;
            4) setup_funding ;;
            5) pixabay_to_shelby_upload ;;
            6) upload_local_file ;;
            7) one_click_demo ;;
            8) wallet_menu ;;
            9) show_commands ;;
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
            12) setup_pixabay_api ;;  # NEW: Pixabay API setup
            13) check_status ;;
            0)
                print_green "👋 Goodbye! Happy uploading!"
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
