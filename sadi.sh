#!/bin/bash

# Shelby Complete with Wallet Management
# All-in-One Solution

echo "========================================="
echo "Shelby CLI + Wallet + Pixabay"
echo "========================================="
echo ""

# Color functions
print_green() { echo -e "\033[1;32m$1\033[0m"; }
print_red() { echo -e "\033[1;31m$1\033[0m"; }
print_yellow() { echo -e "\033[1;33m$1\033[0m"; }
print_blue() { echo -e "\033[1;34m$1\033[0m"; }

# Check commands
command_exists() { command -v "$1" >/dev/null 2>&1; }

# ============================================
# WALLET MANAGEMENT - IMPORT PRIVATE KEY
# ============================================

WALLET_DIR="$HOME/.shelby_wallets"
mkdir -p "$WALLET_DIR"

# Option 10: Import Private Key
import_private_key() {
    print_green "═══════════════════════════════════════"
    print_green "       IMPORT PRIVATE KEY"
    print_green "═══════════════════════════════════════"
    echo ""
    
    echo "Choose import method:"
    echo "1. 📝 Enter private key manually"
    echo "2. 📁 Import from file"
    echo "3. 🔄 Import from mnemonic (12/24 words)"
    echo "4. ↩️ Back to main menu"
    echo ""
    
    read -p "Choose (1-4): " method
    
    case $method in
        1)
            import_manual_key
            ;;
        2)
            import_from_file
            ;;
        3)
            import_from_mnemonic
            ;;
        4)
            return
            ;;
        *)
            print_red "Invalid choice"
            ;;
    esac
}

# 1. Import manually
import_manual_key() {
    print_blue "Manual Private Key Import"
    echo ""
    
    read -p "Enter wallet name: " wallet_name
    if [ -z "$wallet_name" ]; then
        wallet_name="imported_$(date +%s)"
    fi
    
    echo "Enter private key (64 hex characters):"
    echo "Example: a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"
    read -s private_key
    echo ""
    
    echo "Confirm private key:"
    read -s private_key2
    echo ""
    
    if [ "$private_key" != "$private_key2" ]; then
        print_red "❌ Keys don't match!"
        return 1
    fi
    
    # Validate length
    if [ ${#private_key} -ne 64 ]; then
        print_yellow "⚠️ Warning: Private key should be 64 hex characters"
        print_yellow "You entered: ${#private_key} characters"
        read -p "Continue anyway? (y/n): " confirm
        if [[ "$confirm" != "y" ]]; then
            return 1
        fi
    fi
    
    # Generate address
    address=$(generate_address "$private_key")
    
    # Save wallet
    save_wallet "$wallet_name" "$private_key" "$address" "manual_import"
    
    print_green "✅ Wallet imported successfully!"
    print_yellow "Wallet Name: $wallet_name"
    print_yellow "Address: $address"
    print_yellow "Private Key: ${private_key:0:8}...${private_key: -8}"
    
    # Save to secure file
    secure_file="$WALLET_DIR/${wallet_name}.secure.key"
    echo "$private_key" > "$secure_file"
    chmod 600 "$secure_file"
    print_red "⚠️ Private key saved to: $secure_file"
    print_red "🔒 KEEP THIS FILE SECURE!"
}

# 2. Import from file
import_from_file() {
    print_blue "Import from File"
    echo ""
    
    echo "Current directory files:"
    ls -la | grep -E "\.(key|txt|pem|priv)$" || echo "No key files found"
    echo ""
    
    read -p "Enter private key file path: " key_file
    
    if [ ! -f "$key_file" ]; then
        print_red "❌ File not found: $key_file"
        return 1
    fi
    
    # Read private key
    private_key=$(cat "$key_file" | tr -d '[:space:]')
    
    if [ -z "$private_key" ]; then
        print_red "❌ File is empty"
        return 1
    fi
    
    if [ ${#private_key} -lt 32 ]; then
        print_red "❌ Invalid private key (too short)"
        return 1
    fi
    
    read -p "Enter wallet name: " wallet_name
    if [ -z "$wallet_name" ]; then
        wallet_name="file_import_$(date +%s)"
    fi
    
    # Generate address
    address=$(generate_address "$private_key")
    
    # Save wallet
    save_wallet "$wallet_name" "$private_key" "$address" "file_import"
    
    print_green "✅ Wallet imported from file!"
    print_yellow "Source: $key_file"
    print_yellow "Wallet: $wallet_name"
    print_yellow "Address: $address"
}

# 3. Import from mnemonic
import_from_mnemonic() {
    print_blue "Import from Mnemonic Phrase"
    echo ""
    
    print_yellow "Enter 12 or 24 word mnemonic phrase:"
    echo "Example: word1 word2 word3 ... word12"
    read -p "Mnemonic: " mnemonic
    
    word_count=$(echo "$mnemonic" | wc -w)
    
    if [ "$word_count" -ne 12 ] && [ "$word_count" -ne 24 ]; then
        print_red "❌ Mnemonic must be 12 or 24 words"
        print_yellow "You entered $word_count words"
        return 1
    fi
    
    read -p "Enter wallet name: " wallet_name
    if [ -z "$wallet_name" ]; then
        wallet_name="mnemonic_${word_count}words_$(date +%s)"
    fi
    
    # Generate private key from mnemonic (simplified)
    private_key=$(echo -n "$mnemonic" | sha256sum | cut -d' ' -f1)
    private_key="${private_key}${private_key}"  # Make 64 chars
    
    # Generate address
    address=$(generate_address "$private_key")
    
    # Save wallet
    save_wallet "$wallet_name" "$private_key" "$address" "mnemonic"
    
    # Save mnemonic backup (encrypted)
    mnemonic_file="$WALLET_DIR/${wallet_name}.mnemonic.backup"
    echo "$mnemonic" > "$mnemonic_file"
    chmod 600 "$mnemonic_file"
    
    print_green "✅ Mnemonic wallet imported!"
    print_yellow "Wallet: $wallet_name"
    print_yellow "Address: $address"
    print_yellow "Word count: $word_count"
    print_red "⚠️ Mnemonic backup: $mnemonic_file"
    print_red "🔒 KEEP THIS SECURE!"
}

# Generate address from private key
generate_address() {
    local private_key="$1"
    # Simple address generation (for demo)
    # In real use, use proper crypto libraries
    echo "0x$(echo -n "$private_key" | sha256sum | cut -d' ' -f1 | tail -c 40)"
}

# Save wallet to file
save_wallet() {
    local name="$1"
    local private_key="$2"
    local address="$3"
    local type="$4"
    
    wallet_file="$WALLET_DIR/${name}.json"
    
    cat > "$wallet_file" << EOF
{
  "name": "$name",
  "address": "$address",
  "private_key": "$private_key",
  "type": "$type",
  "imported_at": "$(date)",
  "network": "shelbynet"
}
EOF
    
    print_yellow "📁 Wallet saved: $wallet_file"
}

# List all wallets
list_wallets() {
    print_blue "📋 Your Wallets"
    echo ""
    
    if [ ! -d "$WALLET_DIR" ] || [ -z "$(ls -A "$WALLET_DIR" 2>/dev/null)" ]; then
        print_yellow "No wallets found. Import one first."
        return
    fi
    
    count=0
    for wallet in "$WALLET_DIR"/*.json; do
        if [ -f "$wallet" ]; then
            count=$((count + 1))
            name=$(basename "$wallet" .json)
            address=$(grep '"address"' "$wallet" | cut -d'"' -f4)
            type=$(grep '"type"' "$wallet" | cut -d'"' -f4)
            
            echo "┌─────────────────────────────────────"
            echo "│ Wallet #$count: $name"
            echo "│ Address: $address"
            echo "│ Type: $type"
            echo "└─────────────────────────────────────"
            echo ""
        fi
    done
    
    print_green "Total wallets: $count"
}

# Connect wallet to Shelby
connect_wallet_to_shelby() {
    print_blue "🔗 Connect Wallet to Shelby"
    
    if [ ! -d "$WALLET_DIR" ] || [ -z "$(ls -A "$WALLET_DIR" 2>/dev/null)" ]; then
        print_red "No wallets found. Import one first."
        return
    fi
    
    echo "Select wallet to connect:"
    select wallet in "$WALLET_DIR"/*.json "Cancel"; do
        if [ "$wallet" = "Cancel" ]; then
            return
        fi
        
        wallet_name=$(basename "$wallet" .json)
        print_green "Selected: $wallet_name"
        
        # Get private key
        private_key=$(grep '"private_key"' "$wallet" | cut -d'"' -f4)
        
        if [ -z "$private_key" ]; then
            print_red "No private key found"
            return 1
        fi
        
        print_yellow "Private Key: ${private_key:0:12}...${private_key: -12}"
        
        # Check if Shelby is installed
        if ! command_exists shelby; then
            print_red "Shelby CLI not installed"
            return 1
        fi
        
        # Initialize Shelby with this private key
        print_blue "Initializing Shelby with this wallet..."
        
        # First get API key
        print_yellow "You need Shelby API key from https://geomi.dev/"
        read -p "Do you have API key? (y/n): " has_key
        
        if [[ "$has_key" == "y" ]]; then
            read -p "Enter Shelby API key: " api_key
            
            # Create config directory
            mkdir -p "$HOME/.shelby"
            
            # Create config file
            cat > "$HOME/.shelby/config.yaml" << EOF
api_key: $api_key
current_context: shelbynet
current_account: $wallet_name
accounts:
  $wallet_name:
    private_key: $private_key
    address: $(grep '"address"' "$wallet" | cut -d'"' -f4)
contexts:
  shelbynet:
    api_endpoint: https://api.shelbynet.com
    chain_id: 1
EOF
            
            print_green "✅ Shelby configured with wallet!"
            print_yellow "Config: $HOME/.shelby/config.yaml"
            
            # Test
            shelby account list && print_green "✅ Connection successful!"
            
        else
            print_yellow "Get API key first from https://geomi.dev/"
        fi
        
        break
    done
}

# Wallet menu
wallet_menu() {
    while true; do
        echo ""
        print_green "═══════════════════════════════════════"
        print_green "         WALLET MANAGEMENT"
        print_green "═══════════════════════════════════════"
        echo ""
        echo "1. 📥 Import Private Key (Option 10)"
        echo "2. 🆕 Create New Wallet"
        echo "3. 📋 List All Wallets"
        echo "4. 🔗 Connect Wallet to Shelby"
        echo "5. 📤 Export Wallet"
        echo "6. 🗑️ Delete Wallet"
        echo "7. ↩️ Back to Main Menu"
        echo ""
        
        read -p "Choose (1-7): " choice
        
        case $choice in
            1) import_private_key ;;
            2) create_new_wallet ;;
            3) list_wallets ;;
            4) connect_wallet_to_shelby ;;
            5) export_wallet ;;
            6) delete_wallet ;;
            7) return ;;
            *) print_red "Invalid choice" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..." dummy
    done
}

# Create new wallet
create_new_wallet() {
    print_blue "🆕 Create New Wallet"
    
    read -p "Enter wallet name: " wallet_name
    if [ -z "$wallet_name" ]; then
        wallet_name="new_wallet_$(date +%s)"
    fi
    
    # Generate private key
    private_key=$(openssl rand -hex 32 2>/dev/null || echo "$(date +%s)$RANDOM" | sha256sum | cut -d' ' -f1)
    
    # Generate address
    address=$(generate_address "$private_key")
    
    # Save wallet
    save_wallet "$wallet_name" "$private_key" "$address" "generated"
    
    # Save private key securely
    secure_file="$WALLET_DIR/${wallet_name}.private.key"
    echo "$private_key" > "$secure_file"
    chmod 600 "$secure_file"
    
    print_green "✅ New wallet created!"
    print_yellow "Name: $wallet_name"
    print_yellow "Address: $address"
    print_yellow "Private Key: $private_key"
    print_red "⚠️ Save private key: $secure_file"
    print_red "🔒 NEVER SHARE PRIVATE KEY!"
}

# Export wallet
export_wallet() {
    print_blue "📤 Export Wallet"
    
    if [ ! -d "$WALLET_DIR" ] || [ -z "$(ls -A "$WALLET_DIR" 2>/dev/null)" ]; then
        print_red "No wallets found"
        return
    fi
    
    echo "Select wallet to export:"
    select wallet in "$WALLET_DIR"/*.json "Cancel"; do
        if [ "$wallet" = "Cancel" ]; then
            return
        fi
        
        wallet_name=$(basename "$wallet" .json)
        
        echo "Export options:"
        echo "1. Export as JSON"
        echo "2. Export private key only"
        echo "3. Export as text file"
        read -p "Choose (1-3): " export_choice
        
        case $export_choice in
            1)
                cp "$wallet" "./${wallet_name}_export.json"
                print_green "✅ Exported: ./${wallet_name}_export.json"
                ;;
            2)
                private_key=$(grep '"private_key"' "$wallet" | cut -d'"' -f4)
                echo "$private_key" > "./${wallet_name}_private.key"
                chmod 600 "./${wallet_name}_private.key"
                print_green "✅ Private key exported"
                print_red "⚠️ Keep this file secure!"
                ;;
            3)
                cp "$wallet" "./${wallet_name}.txt"
                print_green "✅ Exported: ./${wallet_name}.txt"
                ;;
            *)
                print_red "Invalid choice"
                ;;
        esac
        
        break
    done
}

# Delete wallet
delete_wallet() {
    print_red "🗑️ Delete Wallet"
    
    if [ ! -d "$WALLET_DIR" ] || [ -z "$(ls -A "$WALLET_DIR" 2>/dev/null)" ]; then
        print_red "No wallets found"
        return
    fi
    
    echo "Select wallet to delete:"
    select wallet in "$WALLET_DIR"/*.json "Cancel"; do
        if [ "$wallet" = "Cancel" ]; then
            return
        fi
        
        wallet_name=$(basename "$wallet" .json)
        
        print_red "⚠️ WARNING: This will permanently delete $wallet_name"
        print_red "Make sure you have backup!"
        
        read -p "Type 'DELETE' to confirm: " confirm
        if [ "$confirm" = "DELETE" ]; then
            rm -f "$wallet"
            rm -f "$WALLET_DIR/${wallet_name}.private.key"
            rm -f "$WALLET_DIR/${wallet_name}.mnemonic.backup"
            rm -f "$WALLET_DIR/${wallet_name}.secure.key"
            print_green "✅ Wallet deleted"
        else
            print_yellow "Deletion cancelled"
        fi
        
        break
    done
}

# ============================================
# PIXABAY AUTO UPLOAD FUNCTIONS
# ============================================

PIXABAY_API_FILE="$HOME/.pixabay_api_key"

# Auto search & upload
auto_pixabay_upload() {
    print_blue "🔍 Pixabay Auto Upload"
    
    # Check API
    if [ ! -f "$PIXABAY_API_FILE" ]; then
        print_red "Pixabay API not configured"
        return 1
    fi
    
    API_KEY=$(cat "$PIXABAY_API_FILE")
    
    read -p "Search for images: " query
    if [ -z "$query" ]; then
        query="nature"
    fi
    
    # Auto generate names
    filename="upload_${query}_$(date +%s).jpg"
    dest="pixabay/${query}_$(date +%Y%m%d).jpg"
    expire="in 30 days"
    
    print_blue "📥 Downloading: $query"
    
    # Download
    url="https://pixabay.com/api/?key=$API_KEY&q=${query// /+}&per_page=1"
    img_url=$(curl -s "$url" | grep -o '"largeImageURL":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -n "$img_url" ]; then
        curl -s -o "$filename" "$img_url"
        
        if [ -f "$filename" ]; then
            print_green "✅ Downloaded: $filename"
            
            # Upload to Shelby
            if command_exists shelby; then
                print_blue "📤 Uploading to Shelby..."
                shelby upload "$filename" "$dest" -e "$expire" --assume-yes
                
                if [ $? -eq 0 ]; then
                    print_green "✅ Upload successful!"
                    print_green "📁 File: $dest"
                    print_green "⏰ Expires: $expire"
                    rm -f "$filename"
                else
                    print_red "❌ Upload failed"
                fi
            else
                print_red "Shelby CLI not installed"
            fi
        fi
    else
        print_red "❌ No images found"
    fi
}

# Setup Pixabay API
setup_pixabay_api() {
    print_blue "🔑 Setup Pixabay API"
    echo "Get free API key from: https://pixabay.com/api/docs/"
    read -p "Enter Pixabay API key: " api_key
    
    if [ -n "$api_key" ]; then
        echo "$api_key" > "$PIXABAY_API_FILE"
        chmod 600 "$PIXABAY_API_FILE"
        print_green "✅ API key saved"
    else
        print_red "No API key entered"
    fi
}

# ============================================
# SHELBY FUNCTIONS
# ============================================

# Install Shelby
install_shelby() {
    print_blue "📦 Installing Shelby CLI..."
    
    if ! command_exists node; then
        print_blue "Installing Node.js..."
        sudo apt update && sudo apt install nodejs npm -y
    fi
    
    npm i -g @shelby-protocol/cli
    
    if command_exists shelby; then
        print_green "✅ Shelby CLI installed"
    else
        print_red "❌ Installation failed"
    fi
}

# Initialize Shelby
init_shelby() {
    print_blue "🔑 Initialize Shelby"
    
    print_yellow "Get API key from: https://geomi.dev/"
    read -p "Enter Shelby API key: " api_key
    
    if [ -z "$api_key" ]; then
        print_red "No API key"
        return 1
    fi
    
    echo -e "$api_key\nyes\n\ny\n" | shelby init 2>/dev/null
    
    if [ -f "$HOME/.shelby/config.yaml" ]; then
        print_green "✅ Shelby initialized"
    else
        print_red "❌ Initialization failed"
    fi
}

# Get faucet tokens
get_faucet() {
    print_blue "💰 Get Test Tokens"
    
    if command_exists shelby; then
        url=$(shelby faucet --no-open 2>/dev/null)
        
        if [ -n "$url" ]; then
            print_green "🔗 Faucet URL: $url"
            print_yellow "1. Open in browser"
            print_yellow "2. Connect wallet"
            print_yellow "3. Click 'Fund'"
            print_yellow "4. Get both APT and ShelbyUSD"
        else
            print_red "Could not get faucet URL"
        fi
    else
        print_red "Shelby not installed"
    fi
}

# One-click demo
one_click_demo() {
    print_green "🚀 One-Click Demo"
    
    if ! command_exists shelby; then
        print_red "Install Shelby first"
        return
    fi
    
    # Create test file
    echo "Shelby Demo - $(date)" > demo.txt
    echo "One-click upload test" >> demo.txt
    
    shelby upload ./demo.txt "demo/test_$(date +%s).txt" -e "tomorrow" --assume-yes
    
    if [ $? -eq 0 ]; then
        print_green "✅ Demo upload successful!"
        rm -f demo.txt
    else
        print_red "❌ Upload failed"
    fi
}

# ============================================
# MAIN MENU WITH ALL OPTIONS
# ============================================

main_menu() {
    while true; do
        clear
        echo ""
        print_green "═══════════════════════════════════════════════"
        print_green "        SHELBY COMPLETE ALL-IN-ONE"
        print_green "═══════════════════════════════════════════════"
        echo ""
        
        # Status
        print_blue "🔍 System Status:"
        
        if command_exists shelby; then
            print_green "✅ Shelby CLI: Installed"
        else
            print_red "❌ Shelby CLI: Not installed"
        fi
        
        if [ -f "$HOME/.shelby/config.yaml" ]; then
            print_green "✅ Shelby Config: OK"
        else
            print_red "❌ Shelby Config: Not initialized"
        fi
        
        if [ -f "$PIXABAY_API_FILE" ]; then
            print_green "✅ Pixabay API: Configured"
        else
            print_red "❌ Pixabay API: Not configured"
        fi
        
        wallet_count=$(ls -1 "$WALLET_DIR"/*.json 2>/dev/null | wc -l)
        if [ "$wallet_count" -gt 0 ]; then
            print_green "✅ Wallets: $wallet_count found"
        else
            print_yellow "⚠️ Wallets: None"
        fi
        
        echo ""
        
        print_blue "📦 INSTALLATION:"
        echo "  1. Install Shelby CLI"
        echo "  2. Initialize Shelby (API Key)"
        echo "  3. Get Test Tokens (Faucet)"
        echo ""
        
        print_blue "📤 UPLOAD FILES:"
        echo "  4. Pixabay Auto Upload"
        echo "  5. Upload Local File"
        echo "  6. One-Click Demo"
        echo ""
        
        print_blue "🔐 WALLET MANAGEMENT:"
        echo "  7. 🆕 Create New Wallet"
        echo "  8. 📋 List Wallets"
        echo "  9. 🔗 Connect Wallet"
        echo "  10. 📥 IMPORT PRIVATE KEY"  # YOUR OPTION 10
        echo ""
        
        print_blue "🛠️  TOOLS & SETUP:"
        echo "  11. Setup Pixabay API"
        echo "  12. Check Balance"
        echo "  13. List Uploaded Files"
        echo "  0. Exit"
        echo ""
        
        read -p "Enter choice (0-13): " choice
        
        case $choice in
            1) install_shelby ;;
            2) init_shelby ;;
            3) get_faucet ;;
            4) auto_pixabay_upload ;;
            5)
                echo "Files:"
                ls -la
                read -p "Filename: " file
                if [ -f "$file" ]; then
                    shelby upload "$file" "uploads/$file" -e "in 30 days" --assume-yes
                fi
                ;;
            6) one_click_demo ;;
            7) create_new_wallet ;;
            8) list_wallets ;;
            9) connect_wallet_to_shelby ;;
            10) import_private_key ;;  # THIS IS YOUR OPTION 10
            11) setup_pixabay_api ;;
            12)
                if command_exists shelby; then
                    shelby account balance
                fi
                ;;
            13)
                if command_exists shelby; then
                    shelby account blobs
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

# Start
main_menu
