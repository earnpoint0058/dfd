#!/bin/bash

# Shelby CLI with Pixabay Integration
# One-click installation and upload from Pixabay

echo "========================================="
echo "Shelby CLI + Pixabay Automated Setup"
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

# Function to install Python dependencies
install_python_deps() {
    print_blue "[1/6] Installing Python dependencies..."
    
    # Check if Python3 is installed
    if ! command_exists python3; then
        print_blue "Installing Python3..."
        sudo apt install python3 python3-pip -y
    fi
    
    # Install required Python packages
    pip3 install requests moviepy pillow --quiet
    
    # Check if ffmpeg is installed
    if ! command_exists ffmpeg; then
        print_blue "Installing ffmpeg..."
        sudo apt install ffmpeg -y
    fi
    
    print_green "✓ Python dependencies installed"
}

# Function to create Pixabay downloader script
create_pixabay_downloader() {
    print_blue "[2/6] Setting up Pixabay downloader..."
    
    PIXABAY_DOWNLOADER_PY="$HOME/pixabay_downloader.py"
    
    # Create the Pixabay downloader script
    cat << 'EOF' > "$PIXABAY_DOWNLOADER_PY"
import requests
import os
import sys
import time
import random
import string
import subprocess
import shutil
from datetime import datetime

try:
    from moviepy.editor import VideoFileClip, concatenate_videoclips
    MOVIEPY_AVAILABLE = True
except ImportError:
    MOVIEPY_AVAILABLE = False

try:
    from PIL import Image
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False

def format_size(bytes_size):
    """Format bytes to human readable size"""
    if bytes_size < 1024:
        return f"{bytes_size} B"
    elif bytes_size < 1024*1024:
        return f"{bytes_size/1024:.1f} KB"
    elif bytes_size < 1024*1024*1024:
        return f"{bytes_size/(1024*1024):.1f} MB"
    else:
        return f"{bytes_size/(1024*1024*1024):.2f} GB"

def format_time(seconds):
    """Format seconds to MM:SS"""
    mins = int(seconds // 60)
    secs = int(seconds % 60)
    return f"{mins:02d}:{secs:02d}"

def draw_progress_bar(progress, total, width=30):
    """Draw a progress bar"""
    percent = progress / total * 100
    filled = int(width * progress // total)
    bar = '█' * filled + '░' * (width - filled)
    return f"[{bar}] {percent:.1f}%"

def check_ffmpeg():
    """Check if ffmpeg is available"""
    return shutil.which("ffmpeg") is not None

def set_pixabay_api_key():
    """Set or update Pixabay API key"""
    api_key_file = os.path.expanduser('~/.pixabay_api_key')
    
    print("🔑 Pixabay API Key Setup")
    print("=" * 40)
    print("To get a Pixabay API key:")
    print("1. Go to https://pixabay.com/api/docs/")
    print("2. Sign up for a free account")
    print("3. Get your API key from dashboard")
    print("")
    
    if os.path.exists(api_key_file):
        with open(api_key_file, 'r') as f:
            current_key = f.read().strip()
        print(f"Current API key: {current_key[:8]}...{current_key[-4:]}")
        change = input("Do you want to change it? (y/n): ").lower()
        if change != 'y':
            return current_key
    
    api_key = input("Enter your Pixabay API key: ").strip()
    
    if not api_key:
        print("⚠️ No API key provided")
        return None
    
    with open(api_key_file, 'w') as f:
        f.write(api_key)
    
    print("✅ API key saved to ~/.pixabay_api_key")
    return api_key

def get_pixabay_api_key():
    """Get Pixabay API key from file"""
    api_key_file = os.path.expanduser('~/.pixabay_api_key')
    
    if not os.path.exists(api_key_file):
        print("⚠️ Pixabay API key not found!")
        key = set_pixabay_api_key()
        if not key:
            print("❌ API key is required")
            sys.exit(1)
        return key
    
    with open(api_key_file, 'r') as f:
        return f.read().strip()

def search_and_download_images(query, count=5, resolution="large"):
    """Search and download images from Pixabay"""
    api_key = get_pixabay_api_key()
    
    print(f"🔍 Searching Pixabay for: '{query}'")
    
    # Pixabay API endpoint for images
    url = f"https://pixabay.com/api/?key={api_key}&q={query}&per_page={count}&image_type=photo"
    
    try:
        response = requests.get(url, timeout=10)
        data = response.json()
        
        if response.status_code != 200:
            print(f"⚠️ API Error: {data.get('error', 'Unknown error')}")
            return []
        
        images = data.get('hits', [])
        
        if not images:
            print("⚠️ No images found for your search")
            return []
        
        print(f"✅ Found {len(images)} images")
        
        downloaded_files = []
        
        for i, img in enumerate(images):
            print(f"\n📸 Image {i+1}: {img.get('tags', 'Untitled')}")
            print(f"   User: {img.get('user', 'Unknown')}")
            print(f"   Views: {img.get('views', 0):,}")
            print(f"   Likes: {img.get('likes', 0):,}")
            
            # Get image URL based on resolution preference
            if resolution == "large" and img.get('largeImageURL'):
                img_url = img['largeImageURL']
            elif resolution == "medium" and img.get('webformatURL'):
                img_url = img['webformatURL']
            else:
                img_url = img.get('webformatURL', img.get('previewURL'))
            
            if not img_url:
                print("⚠️ No image URL available")
                continue
            
            # Download image
            file_ext = os.path.splitext(img_url)[1].split('?')[0]
            if not file_ext:
                file_ext = '.jpg'
            
            filename = f"pixabay_{query.replace(' ', '_')}_{i+1}_{datetime.now().strftime('%Y%m%d_%H%M%S')}{file_ext}"
            
            print(f"   Downloading: {filename}")
            
            try:
                img_response = requests.get(img_url, stream=True, timeout=15)
                img_response.raise_for_status()
                
                total_size = int(img_response.headers.get('content-length', 0))
                downloaded = 0
                start_time = time.time()
                
                with open(filename, 'wb') as f:
                    for chunk in img_response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                            downloaded += len(chunk)
                            
                            if total_size > 0:
                                percent = downloaded / total_size * 100
                                elapsed = time.time() - start_time
                                speed = downloaded / (1024 * elapsed) if elapsed > 0 else 0
                                
                                sys.stdout.write(f"\r   Progress: {draw_progress_bar(downloaded, total_size)} "
                                               f"({format_size(downloaded)}/{format_size(total_size)}) "
                                               f"{speed:.1f} KB/s")
                                sys.stdout.flush()
                
                print("\r   ✅ Download completed!")
                
                if os.path.exists(filename) and os.path.getsize(filename) > 0:
                    downloaded_files.append(filename)
                    print(f"   Saved as: {filename} ({format_size(os.path.getsize(filename))})")
                else:
                    print("⚠️ Download failed - file is empty")
                    if os.path.exists(filename):
                        os.remove(filename)
                        
            except Exception as e:
                print(f"\n⚠️ Download error: {str(e)}")
                if os.path.exists(filename):
                    os.remove(filename)
        
        return downloaded_files
        
    except Exception as e:
        print(f"⚠️ Search error: {str(e)}")
        return []

def search_and_download_videos(query, count=3, target_duration=60):
    """Search and download videos from Pixabay"""
    api_key = get_pixabay_api_key()
    
    print(f"🎬 Searching Pixabay videos for: '{query}'")
    
    # Pixabay API endpoint for videos
    url = f"https://pixabay.com/api/videos/?key={api_key}&q={query}&per_page={count}"
    
    try:
        response = requests.get(url, timeout=10)
        data = response.json()
        
        if response.status_code != 200:
            print(f"⚠️ API Error: {data.get('error', 'Unknown error')}")
            return []
        
        videos = data.get('hits', [])
        
        if not videos:
            print("⚠️ No videos found for your search")
            return []
        
        print(f"✅ Found {len(videos)} videos")
        
        downloaded_files = []
        total_duration = 0
        
        for i, video in enumerate(videos):
            print(f"\n🎥 Video {i+1}: {video.get('tags', 'Untitled')}")
            print(f"   Duration: {video.get('duration', 0)} seconds")
            print(f"   Views: {video.get('views', 0):,}")
            
            # Get best quality video URL
            video_url = None
            qualities = ['large', 'medium', 'small']
            
            for quality in qualities:
                if video.get('videos', {}).get(quality, {}).get('url'):
                    video_url = video['videos'][quality]['url']
                    print(f"   Quality: {quality}")
                    break
            
            if not video_url:
                print("⚠️ No video URL available")
                continue
            
            # Download video
            filename = f"pixabay_video_{query.replace(' ', '_')}_{i+1}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp4"
            
            print(f"   Downloading: {filename}")
            
            try:
                video_response = requests.get(video_url, stream=True, timeout=30)
                video_response.raise_for_status()
                
                total_size = int(video_response.headers.get('content-length', 0))
                downloaded = 0
                start_time = time.time()
                
                with open(filename, 'wb') as f:
                    for chunk in video_response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                            downloaded += len(chunk)
                            
                            if total_size > 0:
                                percent = downloaded / total_size * 100
                                elapsed = time.time() - start_time
                                speed = downloaded / (1024 * 1024 * elapsed) if elapsed > 0 else 0
                                
                                sys.stdout.write(f"\r   Progress: {draw_progress_bar(downloaded, total_size)} "
                                               f"({format_size(downloaded)}/{format_size(total_size)}) "
                                               f"{speed:.1f} MB/s")
                                sys.stdout.flush()
                
                print("\r   ✅ Download completed!")
                
                if os.path.exists(filename) and os.path.getsize(filename) > 0:
                    downloaded_files.append(filename)
                    total_duration += video.get('duration', 0)
                    print(f"   Saved as: {filename} ({format_size(os.path.getsize(filename))})")
                    
                    if total_duration >= target_duration:
                        print(f"\n🎯 Reached target duration: {total_duration} seconds")
                        break
                else:
                    print("⚠️ Download failed - file is empty")
                    if os.path.exists(filename):
                        os.remove(filename)
                        
            except Exception as e:
                print(f"\n⚠️ Download error: {str(e)}")
                if os.path.exists(filename):
                    os.remove(filename)
        
        return downloaded_files
        
    except Exception as e:
        print(f"⚠️ Search error: {str(e)}")
        return []

def concatenate_videos(video_files, output_file):
    """Concatenate multiple video files"""
    if not video_files:
        return False
    
    if len(video_files) == 1:
        os.rename(video_files[0], output_file)
        return True
    
    print(f"🔗 Concatenating {len(video_files)} videos...")
    
    # Try ffmpeg first
    if check_ffmpeg():
        try:
            # Create list file for ffmpeg
            list_file = 'concat_list.txt'
            with open(list_file, 'w') as f:
                for video_file in video_files:
                    f.write(f"file '{os.path.abspath(video_file)}'\n")
            
            # Concatenate using ffmpeg
            cmd = [
                'ffmpeg', '-f', 'concat', '-safe', '0',
                '-i', list_file, '-c', 'copy', output_file,
                '-y'  # Overwrite output file if exists
            ]
            
            print(f"   Running: {' '.join(cmd)}")
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if os.path.exists(list_file):
                os.remove(list_file)
            
            if result.returncode == 0 and os.path.exists(output_file):
                print(f"✅ Concatenation successful: {output_file}")
                
                # Clean up individual files
                for video_file in video_files:
                    if os.path.exists(video_file):
                        os.remove(video_file)
                
                return True
            else:
                print(f"⚠️ ffmpeg failed: {result.stderr}")
                
        except Exception as e:
            print(f"⚠️ ffmpeg error: {str(e)}")
    
    # Try moviepy if ffmpeg fails
    if MOVIEPY_AVAILABLE and len(video_files) > 0:
        try:
            clips = []
            for video_file in video_files:
                if os.path.exists(video_file):
                    clip = VideoFileClip(video_file)
                    clips.append(clip)
            
            if clips:
                final_clip = concatenate_videoclips(clips)
                final_clip.write_videofile(
                    output_file,
                    codec='libx264',
                    audio_codec='aac',
                    temp_audiofile='temp-audio.m4a',
                    remove_temp=True
                )
                
                for clip in clips:
                    clip.close()
                final_clip.close()
                
                if os.path.exists(output_file):
                    print(f"✅ Moviepy concatenation successful: {output_file}")
                    
                    # Clean up individual files
                    for video_file in video_files:
                        if os.path.exists(video_file):
                            os.remove(video_file)
                    
                    return True
                    
        except Exception as e:
            print(f"⚠️ Moviepy error: {str(e)}")
    
    print("⚠️ All concatenation methods failed")
    return False

def main():
    """Main function"""
    print("=" * 50)
    print("📸 PIXABAY DOWNLOADER")
    print("=" * 50)
    
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 pixabay_downloader.py image <query> [count] [resolution]")
        print("  python3 pixabay_downloader.py video <query> [count] [duration]")
        print("")
        print("Examples:")
        print("  python3 pixabay_downloader.py image nature 5 large")
        print("  python3 pixabay_downloader.py video sunset 3 60")
        print("")
        
        # Interactive mode
        print("Interactive Mode:")
        print("1. Download images")
        print("2. Download videos")
        print("3. Setup API key")
        
        choice = input("\nChoose (1-3): ").strip()
        
        if choice == '1':
            query = input("Search query: ").strip()
            count = input("Number of images (default 3): ").strip()
            count = int(count) if count.isdigit() else 3
            resolution = input("Resolution (large/medium, default large): ").strip().lower()
            resolution = resolution if resolution in ['large', 'medium'] else 'large'
            
            files = search_and_download_images(query, count, resolution)
            
        elif choice == '2':
            query = input("Search query: ").strip()
            count = input("Number of videos (default 2): ").strip()
            count = int(count) if count.isdigit() else 2
            duration = input("Target duration in seconds (default 30): ").strip()
            duration = int(duration) if duration.isdigit() else 30
            
            files = search_and_download_videos(query, count, duration)
            
            if len(files) > 1:
                combine = input("\nCombine all videos into one? (y/n): ").lower()
                if combine == 'y':
                    output_file = f"pixabay_{query.replace(' ', '_')}_combined_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp4"
                    if concatenate_videos(files, output_file):
                        files = [output_file]
            
        elif choice == '3':
            set_pixabay_api_key()
            return
        
        else:
            print("❌ Invalid choice")
            return
        
        if files:
            print(f"\n✅ Successfully downloaded {len(files)} file(s)")
            for f in files:
                print(f"   📄 {f}")
        else:
            print("\n⚠️ No files were downloaded")
        
        return
    
    # Command line mode
    mode = sys.argv[1].lower()
    
    if mode == 'image':
        query = sys.argv[2] if len(sys.argv) > 2 else 'nature'
        count = int(sys.argv[3]) if len(sys.argv) > 3 else 3
        resolution = sys.argv[4] if len(sys.argv) > 4 else 'large'
        
        files = search_and_download_images(query, count, resolution)
        
    elif mode == 'video':
        query = sys.argv[2] if len(sys.argv) > 2 else 'nature'
        count = int(sys.argv[3]) if len(sys.argv) > 3 else 2
        duration = int(sys.argv[4]) if len(sys.argv) > 4 else 30
        
        files = search_and_download_videos(query, count, duration)
        
        if len(files) > 1:
            output_file = f"pixabay_{query.replace(' ', '_')}_combined_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp4"
            if concatenate_videos(files, output_file):
                files = [output_file]
    
    elif mode == 'setup':
        set_pixabay_api_key()
        return
    
    else:
        print(f"❌ Unknown mode: {mode}")
        return
    
    if files:
        print(f"\n✅ Successfully downloaded {len(files)} file(s)")
    else:
        print("\n⚠️ No files were downloaded")

if __name__ == "__main__":
    main()
EOF
    
    # Make the script executable
    chmod +x "$PIXABAY_DOWNLOADER_PY"
    
    print_green "✓ Pixabay downloader created at: $PIXABAY_DOWNLOADER_PY"
    print_yellow "Note: You need a Pixabay API key (free from pixabay.com/api/docs)"
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
    
    print_yellow "📋 IMPORTANT: You need two API keys:"
    print_yellow "1. Shelby API key from https://geomi.dev/ (Shelbynet)"
    print_yellow "2. Pixabay API key from https://pixabay.com/api/docs/"
    echo ""
    
    # First setup Pixabay API key
    print_blue "🔑 Setting up Pixabay API key first..."
    python3 "$HOME/pixabay_downloader.py" setup
    
    # Then setup Shelby
    read -p "Do you have your Shelby API key from geomi.dev? (y/n): " has_shelby_key
    
    if [[ "$has_shelby_key" == "y" || "$has_shelby_key" == "Y" ]]; then
        read -p "Enter your Shelby API key: " shelby_key
        
        if [ -n "$shelby_key" ]; then
            echo "Initializing Shelby with your API key..."
            
            # Try to initialize automatically
            echo -e "$shelby_key\nyes\n\n\ny\n" | shelby init 2>/dev/null || {
                print_yellow "Manual initialization required. Please run:"
                print_yellow "  shelby init"
                print_yellow "And follow the prompts"
            }
            
            print_green "✓ Shelby initialization complete!"
        fi
    else
        print_yellow "Please get your Shelby API key from https://geomi.dev/"
    fi
}

# Function to setup funding
setup_funding() {
    print_blue "[6/6] Setting up account funding..."
    
    print_yellow "💰 You need to fund your account with:"
    print_yellow "1. APT tokens - for gas fees"
    print_yellow "2. ShelbyUSD tokens - for uploads/downloads"
    echo ""
    
    # Get faucet URL
    if command_exists shelby; then
        FAUCET_URL=$(shelby faucet --no-open 2>/dev/null || echo "")
        
        if [ -n "$FAUCET_URL" ]; then
            print_green "🔗 Faucet URL: $FAUCET_URL"
            print_yellow "Please open this in your browser and fund your account"
            echo ""
            
            read -p "Press Enter after funding your account..." dummy
            
            # Check balance
            print_blue "Checking your balance..."
            shelby account balance
        else
            print_yellow "Run 'shelby faucet --no-open' to get faucet URL"
        fi
    else
        print_red "Shelby CLI not found. Please install first."
    fi
}

# Function for Pixabay to Shelby upload
pixabay_to_shelby_upload() {
    echo ""
    print_green "========================================="
    print_green "     PIXABAY → SHELBY UPLOAD"
    print_green "========================================="
    
    while true; do
        echo ""
        echo "Choose what to upload from Pixabay:"
        echo "1. Search and upload images"
        echo "2. Search and upload videos"
        echo "3. Upload local files to Shelby"
        echo "4. Check Shelby balance"
        echo "5. List uploaded files"
        echo "6. Back to main menu"
        echo ""
        
        read -p "Enter choice (1-6): " choice
        
        case $choice in
            1)
                # Upload images from Pixabay
                read -p "Enter search query: " query
                read -p "Number of images (1-10): " count
                count=${count:-3}
                
                if ! [[ "$count" =~ ^[1-9][0-9]?$ ]] || [ "$count" -gt 10 ]; then
                    count=3
                fi
                
                print_blue "🔍 Searching Pixabay for '$query'..."
                
                # Download images
                FILES=$(python3 "$HOME/pixabay_downloader.py" image "$query" "$count" "large" 2>/dev/null | grep -E "^pixabay_.*\.(jpg|jpeg|png|webp)$" || echo "")
                
                if [ -z "$FILES" ]; then
                    # Try to find downloaded files
                    FILES=$(ls -1 pixabay_*.jpg pixabay_*.jpeg pixabay_*.png pixabay_*.webp 2>/dev/null | head -$count)
                fi
                
                if [ -n "$FILES" ]; then
                    echo ""
                    print_green "✅ Downloaded files:"
                    for FILE in $FILES; do
                        if [ -f "$FILE" ]; then
                            echo "   📄 $FILE ($(stat -c%s "$FILE") bytes)"
                        fi
                    done
                    
                    # Upload to Shelby
                    read -p "Upload to Shelby? (y/n): " upload_choice
                    
                    if [[ "$upload_choice" == "y" || "$upload_choice" == "Y" ]]; then
                        read -p "Set expiration (e.g., tomorrow, in 30 days): " expiration
                        expiration=${expiration:-"in 30 days"}
                        
                        for FILE in $FILES; do
                            if [ -f "$FILE" ]; then
                                print_blue "⬆️ Uploading $FILE to Shelby..."
                                shelby upload "./$FILE" "pixabay/images/$(basename "$FILE")" -e "$expiration" --assume-yes
                                
                                # Clean up local file after upload
                                rm -f "./$FILE"
                            fi
                        done
                        
                        print_green "✅ All files uploaded to Shelby!"
                    else
                        print_yellow "Files saved locally. Upload later with option 3."
                    fi
                else
                    print_red "❌ No images were downloaded"
                fi
                ;;
                
            2)
                # Upload videos from Pixabay
                read -p "Enter search query: " query
                read -p "Number of videos (1-5): " count
                count=${count:-2}
                
                if ! [[ "$count" =~ ^[1-5]$ ]]; then
                    count=2
                fi
                
                read -p "Target duration in seconds (30-300): " duration
                duration=${duration:-60}
                
                print_blue "🎬 Searching Pixabay videos for '$query'..."
                
                # Download videos
                OUTPUT_FILE="pixabay_video_${query// /_}_$(date +%Y%m%d_%H%M%S).mp4"
                python3 "$HOME/pixabay_downloader.py" video "$query" "$count" "$duration" > /dev/null 2>&1
                
                # Find downloaded video files
                VIDEO_FILES=$(ls -1 pixabay_video_*.mp4 2>/dev/null)
                
                if [ -n "$VIDEO_FILES" ]; then
                    echo ""
                    print_green "✅ Downloaded videos:"
                    for VIDEO in $VIDEO_FILES; do
                        if [ -f "$VIDEO" ]; then
                            SIZE=$(stat -c%s "$VIDEO")
                            echo "   🎥 $VIDEO ($(echo "scale=2; $SIZE/1024/1024" | bc) MB)"
                        fi
                    done
                    
                    # Upload to Shelby
                    read -p "Upload to Shelby? (y/n): " upload_choice
                    
                    if [[ "$upload_choice" == "y" || "$upload_choice" == "Y" ]]; then
                        read -p "Set expiration (e.g., tomorrow, in 30 days): " expiration
                        expiration=${expiration:-"in 30 days"}
                        
                        for VIDEO in $VIDEO_FILES; do
                            if [ -f "$VIDEO" ]; then
                                print_blue "⬆️ Uploading $VIDEO to Shelby..."
                                shelby upload "./$VIDEO" "pixabay/videos/$(basename "$VIDEO")" -e "$expiration" --assume-yes
                                
                                # Clean up local file after upload
                                rm -f "./$VIDEO"
                            fi
                        done
                        
                        print_green "✅ All videos uploaded to Shelby!"
                    else
                        print_yellow "Videos saved locally. Upload later with option 3."
                    fi
                else
                    print_red "❌ No videos were downloaded"
                fi
                ;;
                
            3)
                # Upload local files
                echo "Current directory files:"
                ls -la | grep -E "\.(jpg|jpeg|png|gif|bmp|mp4|mov|avi|txt|pdf)$" || echo "No common file types found"
                
                read -p "Enter filename to upload: " file_to_upload
                
                if [ -f "$file_to_upload" ]; then
                    read -p "Enter destination path in Shelby (e.g., myfiles/photo.jpg): " dest_path
                    read -p "Set expiration (e.g., tomorrow, in 30 days): " expiration
                    expiration=${expiration:-"in 30 days"}
                    
                    shelby upload "./$file_to_upload" "$dest_path" -e "$expiration" --assume-yes
                else
                    print_red "File not found: $file_to_upload"
                fi
                ;;
                
            4)
                # Check balance
                if command_exists shelby; then
                    shelby account balance
                else
                    print_red "Shelby CLI not found"
                fi
                ;;
                
            5)
                # List uploaded files
                if command_exists shelby; then
                    shelby account blobs
                else
                    print_red "Shelby CLI not found"
                fi
                ;;
                
            6)
                return
                ;;
                
            *)
                print_red "Invalid choice"
                ;;
        esac
    done
}

# One-click demo upload
one_click_demo() {
    print_green "========================================="
    print_green "     ONE-CLICK PIXABAY → SHELBY DEMO"
    print_green "========================================="
    
    # Check if Shelby is initialized
    if ! command_exists shelby; then
        print_red "Shelby CLI not found. Please install first."
        return
    fi
    
    # Check balance
    print_blue "Checking account balance..."
    BALANCE_OUTPUT=$(shelby account balance 2>/dev/null)
    
    if echo "$BALANCE_OUTPUT" | grep -q "ShelbyUSD"; then
        print_green "✅ Account has balance"
    else
        print_red "❌ Account needs funding"
        print_yellow "Please fund your account with ShelbyUSD tokens first"
        return
    fi
    
    # Download one image from Pixabay
    print_blue "🌅 Downloading sample image from Pixabay..."
    
    # Try to download a nature image
    python3 "$HOME/pixabay_downloader.py" image "nature" 1 "large" > /dev/null 2>&1
    
    # Find downloaded image
    IMAGE_FILE=$(ls -1 pixabay_*.jpg pixabay_*.jpeg pixabay_*.png 2>/dev/null | head -1)
    
    if [ -f "$IMAGE_FILE" ]; then
        print_green "✅ Downloaded: $IMAGE_FILE"
        
        # Upload to Shelby
        print_blue "⬆️ Uploading to Shelby..."
        
        shelby upload "./$IMAGE_FILE" "demo/$(basename "$IMAGE_FILE")" -e "in 7 days" --assume-yes
        
        if [ $? -eq 0 ]; then
            print_green "✅ Demo upload successful!"
            
            # Show uploaded files
            print_blue "📋 Your Shelby files:"
            shelby account blobs | grep -A5 -B5 "demo/"
            
            # Clean up
            rm -f "./$IMAGE_FILE"
        else
            print_red "❌ Upload failed"
            print_yellow "Keeping local file: $IMAGE_FILE"
        fi
    else
        print_red "❌ Could not download sample image"
        print_yellow "Please check your Pixabay API key"
    fi
}

# Main menu
main_menu() {
    echo ""
    print_green "========================================="
    print_green "   SHELBY CLI + PIXABAY INTEGRATION"
    print_green "========================================="
    echo ""
    echo "Choose an option:"
    echo "1. Complete automated installation (Everything)"
    echo "2. Install Pixabay downloader only"
    echo "3. Install Shelby CLI only"
    echo "4. Setup API keys (Pixabay + Shelby)"
    echo "5. Fund account with tokens"
    echo "6. Pixabay → Shelby upload interface"
    echo "7. One-click demo upload"
    echo "8. Quick commands reference"
    echo "9. Exit"
    echo ""
    
    read -p "Enter choice (1-9): " main_choice
    
    case $main_choice in
        1)
            print_green "🚀 Starting complete installation..."
            install_python_deps
            create_pixabay_downloader
            install_node_npm
            install_shelby_cli
            print_green "✓ Installation complete!"
            print_yellow "Next: Run option 4 to setup API keys"
            ;;
        2)
            install_python_deps
            create_pixabay_downloader
            print_green "✓ Pixabay downloader ready!"
            print_yellow "Run: python3 ~/pixabay_downloader.py"
            ;;
        3)
            install_node_npm
            install_shelby_cli
            print_green "✓ Shelby CLI installed!"
            ;;
        4)
            initialize_shelby
            ;;
        5)
            setup_funding
            ;;
        6)
            pixabay_to_shelby_upload
            ;;
        7)
            one_click_demo
            ;;
        8)
            echo ""
            print_green "📋 QUICK COMMANDS REFERENCE"
            print_green "==========================="
            echo ""
            echo "Pixabay commands:"
            echo "  python3 ~/pixabay_downloader.py image nature 5"
            echo "  python3 ~/pixabay_downloader.py video sunset 3 60"
            echo "  python3 ~/pixabay_downloader.py setup"
            echo ""
            echo "Shelby commands:"
            echo "  shelby init"
            echo "  shelby account balance"
            echo "  shelby account blobs"
            echo "  shelby upload file.txt destination.txt -e 'in 30 days' --assume-yes"
            echo "  shelby download blob.txt local.txt"
            echo "  shelby faucet --no-open"
            echo ""
            echo "Upload from Pixabay to Shelby:"
            echo "  1. Download: python3 ~/pixabay_downloader.py image cats 3"
            echo "  2. Upload: shelby upload pixabay_*.jpg pixabay/cats/ -e 'tomorrow' --assume-yes"
            echo ""
            ;;
        9)
            print_green "👋 Goodbye! Happy uploading!"
            exit 0
            ;;
        *)
            print_red "❌ Invalid choice"
            ;;
    esac
    
    # Return to menu
    main_menu
}

# Check system
echo "System check..."
if ! grep -qi microsoft /proc/version 2>/dev/null; then
    print_yellow "⚠️ Warning: This is optimized for WSL"
    read -p "Continue anyway? (y/n): " continue_anyway
    if [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]]; then
        exit 0
    fi
fi

# Start main menu
main_menu
