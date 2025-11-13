#!/bin/bash

###############################################################################
# YouTube Blocker - Quick Uninstall Script
# Usage: curl -sSL https://raw.githubusercontent.com/kenzouno1/Block-YT/main/quick-uninstall.sh | sudo bash
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_message() {
    echo -e "${2}${1}${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_message "Error: This script must be run as root (use sudo)" "$RED"
    exit 1
fi

print_message "
╔════════════════════════════════════════════════════════════════╗
║        YouTube Blocker - Quick Uninstall                       ║
╚════════════════════════════════════════════════════════════════╝
" "$GREEN"

# Configuration
REPO_URL="https://github.com/kenzouno1/Block-YT.git"
BRANCH="main"
INSTALL_DIR="/tmp/block-yt-uninstall"

print_message "Step 1: Installing basic tools..." "$YELLOW"
apt-get update -qq

# Install only essential tools (no git needed for end users)
apt-get install -y curl wget unzip > /dev/null 2>&1
print_message "✅ Basic tools installed" "$GREEN"

print_message "\nStep 2: Downloading YouTube Blocker..." "$YELLOW"
# Remove old installation directory if exists
rm -rf "$INSTALL_DIR"

TEMP_ZIP="/tmp/block-yt-uninstall.zip"

# Download zip file (no git needed)
print_message "Downloading from GitHub..." "$YELLOW"
if command -v curl &> /dev/null; then
    curl -L -o "$TEMP_ZIP" "https://github.com/kenzouno1/Block-YT/archive/refs/heads/$BRANCH.zip" > /dev/null 2>&1
elif command -v wget &> /dev/null; then
    wget -O "$TEMP_ZIP" "https://github.com/kenzouno1/Block-YT/archive/refs/heads/$BRANCH.zip" > /dev/null 2>&1
else
    print_message "Error: Neither curl nor wget is available" "$RED"
    exit 1
fi

# Unzip
print_message "Extracting files..." "$YELLOW"
unzip -q "$TEMP_ZIP" -d /tmp/
mv "/tmp/Block-YT-$BRANCH" "$INSTALL_DIR"
rm -f "$TEMP_ZIP"

cd "$INSTALL_DIR"

print_message "✅ Repository downloaded" "$GREEN"

print_message "\nStep 3: Running uninstallation..." "$YELLOW"
# Run the main uninstaller
bash uninstall.sh

print_message "\n✅ Uninstallation complete!" "$GREEN"

# Cleanup
print_message "\nStep 4: Cleaning up..." "$YELLOW"
cd /
rm -rf "$INSTALL_DIR"
print_message "✅ Cleanup complete" "$GREEN"

print_message "
╔════════════════════════════════════════════════════════════════╗
║                      All Done! 👋                              ║
╚════════════════════════════════════════════════════════════════╝

YouTube Blocker has been removed from your system!

What was removed:
  ✅ /etc/hosts entries - YouTube unblocked
  ✅ Backend service - Stopped and removed
  ✅ Installation files - Deleted
  ✅ Systemd service - Disabled and removed

YouTube is now accessible from all browsers again.

Note: You may need to manually remove the Chrome extension:
  1. Go to chrome://extensions/
  2. Find 'YouTube Blocker Whitelist'
  3. Click 'Remove'

Thank you for using YouTube Blocker!
" "$GREEN"
