#!/bin/bash

###############################################################################
# YouTube Blocker - Installation Script
# This script installs and configures the YouTube Blocker service on Ubuntu
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/youtube-blocker"
SERVICE_NAME="youtube-blocker"
LOG_FILE="/var/log/youtube-blocker.log"

# Print colored message
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_message "$RED" "Error: This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check Ubuntu version
check_ubuntu() {
    if [ ! -f /etc/os-release ]; then
        print_message "$RED" "Error: Cannot detect OS version"
        exit 1
    fi

    . /etc/os-release
    if [ "$ID" != "ubuntu" ]; then
        print_message "$YELLOW" "Warning: This script is designed for Ubuntu. Your OS: $ID"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    print_message "$GREEN" "OS: $PRETTY_NAME"
}

# Install Python dependencies
install_dependencies() {
    print_message "$YELLOW" "Installing Python dependencies..."

    # Install pip if not present
    if ! command -v pip3 &> /dev/null; then
        apt-get update
        apt-get install -y python3-pip
    fi

    # Install required packages
    pip3 install flask flask-cors requests

    print_message "$GREEN" "Dependencies installed successfully"
}

# Create installation directory
create_install_dir() {
    print_message "$YELLOW" "Creating installation directory..."

    # Create directory
    mkdir -p "$INSTALL_DIR"

    # Copy files
    cp backend/youtube_blocker.py "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/youtube_blocker.py"

    # Create log file
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    # Create data directory
    mkdir -p /var/lib/youtube-blocker
    chmod 755 /var/lib/youtube-blocker

    print_message "$GREEN" "Installation directory created"
}

# Install systemd service
install_service() {
    print_message "$YELLOW" "Installing systemd service..."

    # Copy service file
    cp backend/youtube-blocker.service /etc/systemd/system/

    # Reload systemd
    systemctl daemon-reload

    # Enable service
    systemctl enable "$SERVICE_NAME"

    print_message "$GREEN" "Systemd service installed and enabled"
}

# Start service
start_service() {
    print_message "$YELLOW" "Starting YouTube Blocker service..."

    systemctl start "$SERVICE_NAME"

    # Wait for service to start
    sleep 2

    # Check status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_message "$GREEN" "Service started successfully!"
    else
        print_message "$RED" "Error: Service failed to start"
        print_message "$YELLOW" "Check logs with: sudo journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
}

# Generate extension icons
generate_icons() {
    print_message "$YELLOW" "Generating Chrome extension icons..."

    cd chrome-extension
    python3 generate_icons.py
    cd ..

    print_message "$GREEN" "Icons generated successfully"
}

# Show completion message
show_completion() {
    print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║                   Installation Complete! 🎉                    ║
╚════════════════════════════════════════════════════════════════╝

YouTube is now blocked system-wide by default.

Next steps:
1. Install the Chrome extension:
   - Open Chrome and go to chrome://extensions/
   - Enable 'Developer mode' (top right)
   - Click 'Load unpacked'
   - Select the 'chrome-extension' folder from this repository

2. Use the extension:
   - Click the extension icon in Chrome
   - Click 'Enable YouTube Access' to whitelist this Chrome profile
   - Only whitelisted profiles can access YouTube

Service Management:
  Status:  sudo systemctl status $SERVICE_NAME
  Stop:    sudo systemctl stop $SERVICE_NAME
  Start:   sudo systemctl start $SERVICE_NAME
  Restart: sudo systemctl restart $SERVICE_NAME
  Logs:    sudo journalctl -u $SERVICE_NAME -f

Files:
  Service:   $INSTALL_DIR/youtube_blocker.py
  Config:    /var/lib/youtube-blocker/whitelist.json
  Logs:      $LOG_FILE

Uninstall:
  Run: sudo ./uninstall.sh
"
}

# Main installation process
main() {
    print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║              YouTube Blocker - Installation Script             ║
╚════════════════════════════════════════════════════════════════╝
"

    check_root
    check_ubuntu

    print_message "$YELLOW" "Starting installation...\n"

    install_dependencies
    create_install_dir
    install_service
    generate_icons
    start_service

    show_completion
}

# Run main function
main
