#!/bin/bash

# Shelby Auto-Fixed Script with Auto Upload

echo "========================================="
echo "Shelby Auto Upload Script"
echo "========================================="
echo ""

# Color functions
print_green() { echo -e "\033[1;32m$1\033[0m"; }
print_red() { echo -e "\033[1;31m$1\033[0m"; }
print_yellow() { echo -e "\033[1;33m$1\033[0m"; }
print_blue() { echo -e "\033[1;34m$1\033[0m"; }

# Check commands
command_exists() { command -v "$1" >/dev/null 2>&1; }

# Pixabay API
PIXABAY_API_FILE="$HOME/.pixabay_api_key"

# ============================================
# AUTO UPLOAD FUNCTIONS
# ============================================

# Function 1: Auto Search & Upload
auto_search_upload() {
    print_blue "🔍 Auto Search & Upload from Pixabay"
    
    # Check API
    if [ ! -f "$PIXABAY_API_FILE" ]; then
        print_red "❌ Pixabay API not setup"
        print_yellow "Get free API key from: https://pixabay.com/api/docs/"
        read -p "Enter Pixabay API key: " api_key
        if [ -n "$api_key" ]; then
            echo "$api_key" > "$PIXABAY_API_FILE"
            chmod 600 "$PIXABAY_API_FILE"
            print_green "✅ API key saved"
        else
            return 1
        fi
    fi
    
    API_KEY=$(cat "$PIXABAY_API_FILE")
    
    # Get search query
    read -p "🔍 Search for images: " query
    if [ -z "$query" ]; then
        query="nature"  # default
    fi
    
    # Auto generate filename
    filename="pixabay_${query}_$(date +%Y%m%d_%H%M%S).jpg"
    
    # Auto destination path
    dest_path="pixabay/${query}_$(date +%Y%m%d).jpg"
    
    # Auto expiration
    expiration="in 30 days"
    
    print_blue "📥 Downloading: $query"
    print_blue "📁 Will save as: $filename"
    print_blue "📤 Will upload to: $dest_path"
    print_blue "⏰ Will expire: $expiration"
    
    # Download from Pixabay
    download_pixabay "$query" "$filename"
    
    if [ -f "$filename" ] && [ -s "$filename" ]; then
        print_green "✅ Downloaded: $filename"
        
        # Auto upload to Shelby
        auto_upload_to_shelby "$filename" "$dest_path" "$expiration"
    else
        print_red "❌ Download failed"
    fi
}

# Function 2: Download from Pixabay
download_pixabay() {
    local query="$1"
    local filename="$2"
    
    API_KEY=$(cat "$PIXABAY_API_FILE" 2>/dev/null)
    
    if [ -z "$API_KEY" ]; then
        print_red "No API key found"
        return 1
    fi
    
    # Search Pixabay
    url="https://pixabay.com/api/?key=$API_KEY&q=${query// /+}&per_page=3&image_type=photo"
    
    print_blue "Searching Pixabay..."
    response=$(curl -s "$url")
    
    # Get first image URL
    image_url=$(echo "$response" | grep -o '"largeImageURL":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$image_url" ]; then
        # Try webformatURL
        image_url=$(echo "$response" | grep -o '"webformatURL":"[^"]*"' | head -1 | cut -d'"' -f4)
    fi
    
    if [ -z "$image_url" ]; then
        print_red "No images found for: $query"
        return 1
    fi
    
    print_blue "Downloading image..."
    curl -s -o "$filename" "$image_url"
    
    # Check if download successful
    if [ -f "$filename" ] && [ -s "$filename" ]; then
        size=$(stat -c%s "$filename")
        print_green "✅ Downloaded: $filename ($((size/1024)) KB)"
        return 0
    else
        print_red "❌ Download failed"
        return 1
    fi
}

# Function 3: Auto Upload to Shelby
auto_upload_to_shelby() {
    local file="$1"
    local dest="$2"
    local expire="$3"
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        print_red "File not found: $file"
        return 1
    fi
    
    # Check Shelby
    if ! command_exists shelby; then
        print_red "❌ Shelby CLI not installed"
        print_yellow "Installing Shelby CLI..."
        install_shelby
        return 1
    fi
    
    # Check if initialized
    if [ ! -f "$HOME/.shelby/config.yaml" ]; then
        print_red "❌ Shelby not initialized"
        print_yellow "Initializing Shelby..."
        init_shelby
        if [ ! -f "$HOME/.shelby/config.yaml" ]; then
            print_red "Still not initialized. Upload failed."
            return 1
        fi
    fi
    
    # Check balance
    print_blue "Checking balance..."
    balance=$(shelby account balance 2>&1)
    if echo "$balance" | grep -q "ShelbyUSD"; then
        print_green "✅ Account has balance"
    else
        print_red "❌ No ShelbyUSD tokens"
        print_yellow "Getting test tokens..."
        get_faucet
    fi
    
    # Upload the file
    print_blue "⬆️ Uploading to Shelby..."
    echo "Command: shelby upload \"$file\" \"$dest\" -e \"$expire\" --assume-yes"
    
    shelby upload "$file" "$dest" -e "$expire" --assume-yes
    
    if [ $? -eq 0 ]; then
        print_green "✅ Upload successful!"
        print_green "📁 File: $dest"
        print_green "⏰ Expires: $expire"
        
        # Delete local file
        rm -f "$file"
        print_yellow "🗑️ Local file deleted"
        
        # Show uploaded files
        print_blue "📋 Your files:"
        shelby account blobs | tail -5
    else
        print_red "❌ Upload failed"
        print_yellow "Keeping local file: $file"
    fi
}

# Function 4: Install Shelby
install_shelby() {
    print_blue "Installing Shelby CLI..."
    
    if ! command_exists node; then
        print_blue "Installing Node.js..."
        sudo apt update && sudo apt install nodejs npm -y
    fi
    
    npm i -g @shelby-protocol/cli
    
    if command_exists shelby; then
        print_green "✅ Shelby CLI installed"
    else
        print_red "❌ Shelby install failed"
    fi
}

# Function 5: Initialize Shelby
init_shelby() {
    print_blue "Initializing Shelby..."
    
    print_yellow "You need API key from: https://geomi.dev/"
    read -p "Enter Shelby API key: " api_key
    
    if [ -z "$api_key" ]; then
        print_red "No API key provided"
        return 1
    fi
    
    # Initialize with API key
    echo -e "$api_key\nyes\n\ny\n" | shelby init 2>/dev/null
    
    if [ -f "$HOME/.shelby/config.yaml" ]; then
        print_green "✅ Shelby initialized"
        return 0
    else
        print_red "❌ Initialization failed"
        print_yellow "Run manually: shelby init"
        return 1
    fi
}

# Function 6: Get Faucet Tokens
get_faucet() {
    print_blue "Getting test tokens..."
    
    if command_exists shelby; then
        url=$(shelby faucet --no-open 2>/dev/null)
        
        if [ -n "$url" ]; then
            print_green "🔗 Faucet URL: $url"
            print_yellow "1. Open this URL in browser"
            print_yellow "2. Connect wallet"
            print_yellow "3. Click 'Fund' to get both APT and ShelbyUSD"
            print_yellow "4. Come back here and press Enter"
            
            read -p "Press Enter after funding..." dummy
            
            # Check balance
            shelby account balance
        else
            print_red "Could not get faucet URL"
        fi
    fi
}

# Function 7: Quick Auto Upload (One Click)
quick_auto_upload() {
    print_green "🚀 Quick Auto Upload"
    
    # Default values
    query="nature"
    filename="auto_upload_$(date +%Y%m%d_%H%M%S).jpg"
    dest_path="auto/upload_$(date +%Y%m%d).jpg"
    expiration="in 7 days"
    
    print_blue "Using defaults:"
    print_blue "🔍 Search: $query"
    print_blue "📁 File: $filename"
    print_blue "📤 Destination: $dest_path"
    print_blue "⏰ Expire: $expiration"
    
    # Download
    download_pixabay "$query" "$filename"
    
    if [ -f "$filename" ]; then
        # Upload
        auto_upload_to_shelby "$filename" "$dest_path" "$expiration"
    fi
}

# Function 8: Bulk Auto Upload
bulk_auto_upload() {
    print_blue "📦 Bulk Auto Upload"
    
    read -p "Enter search terms (comma separated): " search_terms
    IFS=',' read -ra terms <<< "$search_terms"
    
    for term in "${terms[@]}"; do
        term=$(echo "$term" | xargs)  # trim spaces
        if [ -n "$term" ]; then
            print_green "📤 Processing: $term"
            auto_search_upload_single "$term"
            echo ""
        fi
    done
}

# Function 9: Single term auto upload
auto_search_upload_single() {
    local term="$1"
    
    filename="pixabay_${term}_$(date +%s).jpg"
    dest_path="pixabay/${term}_$(date +%Y%m%d).jpg"
    expiration="in 30 days"
    
    # Download
    download_pixabay "$term" "$filename"
    
    if [ -f "$filename" ]; then
        # Upload
        auto_upload_to_shelby "$filename" "$dest_path" "$expiration"
    fi
}

# Function 10: Check System Status
check_status() {
    print_blue "🔍 System Status"
    
    # Shelby
    if command_exists shelby; then
        print_green "✅ Shelby CLI: Installed"
        if [ -f "$HOME/.shelby/config.yaml" ]; then
            print_green "✅ Shelby Config: OK"
        else
            print_red "❌ Shelby Config: Not initialized"
        fi
    else
        print_red "❌ Shelby CLI: Not installed"
    fi
    
    # Pixabay API
    if [ -f "$PIXABAY_API_FILE" ]; then
        print_green "✅ Pixabay API: Configured"
    else
        print_red "❌ Pixabay API: Not configured"
    fi
    
    # Node.js
    if command_exists node; then
        print_green "✅ Node.js: Installed"
    else
        print_red "❌ Node.js: Not installed"
    fi
}

# ============================================
# MAIN MENU - SIMPLE
# ============================================

main_menu() {
    while true; do
        clear
        echo ""
        print_green "═══════════════════════════════════════"
        print_green "        AUTO UPLOAD SHELBY"
        print_green "═══════════════════════════════════════"
        echo ""
        
        check_status
        echo ""
        
        print_blue "🎯 AUTO UPLOAD OPTIONS:"
        echo "  1. 🔍 Search & Auto Upload (You just enter name)"
        echo "  2. 🚀 Quick Auto Upload (Fully automatic)"
        echo "  3. 📦 Bulk Upload (Multiple searches)"
        echo ""
        
        print_blue "⚙️  SETUP & TOOLS:"
        echo "  4. 📥 Install Shelby CLI"
        echo "  5. 🔑 Setup Shelby API Key"
        echo "  6. 🔑 Setup Pixabay API Key"
        echo "  7. 💰 Get Test Tokens"
        echo "  8. 📋 Check Balance"
        echo "  9. 📁 List Uploaded Files"
        echo "  0. 🚪 Exit"
        echo ""
        
        read -p "Choose option (0-9): " choice
        
        case $choice in
            1)
                # Search & Auto Upload
                auto_search_upload
                ;;
            2)
                # Quick Auto Upload
                quick_auto_upload
                ;;
            3)
                # Bulk Upload
                bulk_auto_upload
                ;;
            4)
                # Install Shelby
                install_shelby
                ;;
            5)
                # Setup Shelby API
                init_shelby
                ;;
            6)
                # Setup Pixabay API
                print_blue "Pixabay API Setup"
                echo "Get free key from: https://pixabay.com/api/docs/"
                read -p "Enter API key: " api_key
                if [ -n "$api_key" ]; then
                    echo "$api_key" > "$PIXABAY_API_FILE"
                    chmod 600 "$PIXABAY_API_FILE"
                    print_green "✅ API key saved"
                fi
                ;;
            7)
                # Get tokens
                get_faucet
                ;;
            8)
                # Check balance
                if command_exists shelby; then
                    shelby account balance
                fi
                ;;
            9)
                # List files
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

# ============================================
# EXTRA: SIMPLE ONE-LINE AUTO UPLOAD
# ============================================

# Create a simple auto-upload script
create_auto_script() {
    cat > ~/auto_upload.sh << 'EOF'
#!/bin/bash
# Auto Upload Script - Just enter search term

echo "🔍 Enter search term (e.g., nature, car, cat): "
read query

if [ -z "$query" ]; then
    query="nature"
fi

# Auto names
filename="upload_${query}_$(date +%s).jpg"
dest="auto/${query}_$(date +%Y%m%d).jpg"
expire="in 30 days"

echo "📥 Downloading: $query"
echo "📤 Will upload to: $dest"

# Check API
API_FILE="$HOME/.pixabay_api_key"
if [ ! -f "$API_FILE" ]; then
    echo "❌ No Pixabay API key"
    exit 1
fi

API_KEY=$(cat "$API_FILE")

# Download
url="https://pixabay.com/api/?key=$API_KEY&q=${query// /+}&per_page=1"
img_url=$(curl -s "$url" | grep -o '"largeImageURL":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$img_url" ]; then
    curl -s -o "$filename" "$img_url"
    
    if [ -f "$filename" ]; then
        echo "✅ Downloaded: $filename"
        
        # Upload if shelby exists
        if command -v shelby &> /dev/null; then
            shelby upload "$filename" "$dest" -e "$expire" --assume-yes && \
            echo "✅ Uploaded to Shelby!" && \
            rm -f "$filename"
        else
            echo "⚠️ Shelby not installed. File saved: $filename"
        fi
    fi
else
    echo "❌ No images found"
fi
EOF
    
    chmod +x ~/auto_upload.sh
    print_green "✅ Auto script created: ~/auto_upload.sh"
    print_yellow "Usage: ./auto_upload.sh"
}

# Start
main_menu
