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

    # Update package list
    apt-get update

    # Install Python packages from apt (Ubuntu 22.04+ uses PEP 668)
    print_message "$YELLOW" "Installing python3-flask, python3-flask-cors, python3-requests, python3-pil..."
    apt-get install -y \
        python3 \
        python3-flask \
        python3-flask-cors \
        python3-requests \
        python3-pil

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

# Show completion message
show_completion() {
    print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║                   Installation Complete! 🎉                    ║
╚════════════════════════════════════════════════════════════════╝

YouTube is now BLOCKED system-wide via iptables firewall.

✅ Firewall configured - All YouTube traffic blocked
✅ Backend service running - API & Proxy ready
✅ Localhost allowed - Proxy can bypass firewall

IMPORTANT - Install Chrome Extension:
=====================================
Chrome profiles need the extension to access YouTube.

1. Open Chrome: chrome://extensions/
2. Enable 'Developer mode' (top right)
3. Click 'Load unpacked'
4. Select: $PWD/build/youtube-blocker-extension/

The extension will:
  - Auto-enable on install (no click needed)
  - Configure proxy: 127.0.0.1:8888
  - Get token from backend
  - Send token in headers

Result:
  ✅ Chrome with extension → YouTube accessible
  ❌ Firefox/Edge/other browsers → YouTube blocked
  ❌ Chrome without extension → YouTube blocked

Verify Blocking:
================
# Test firewall (should be blocked)
curl https://youtube.com
# → Connection rejected ✅

# Check backend status
sudo ./start-backend.sh status

# Check firewall status
sudo ./setup-firewall.sh status

Service Management (if systemd available):
==========================================
  Status:   sudo systemctl status $SERVICE_NAME
  Restart:  sudo systemctl restart $SERVICE_NAME
  Logs:     sudo journalctl -u $SERVICE_NAME -f

Or Manual Control:
==================
  Status:   sudo ./start-backend.sh status
  Stop:     sudo ./start-backend.sh stop
  Start:    sudo ./start-backend.sh start
  Logs:     sudo ./start-backend.sh logs

Firewall Management:
====================
  Status:   sudo ./setup-firewall.sh status
  Test:     sudo ./setup-firewall.sh test
  Remove:   sudo ./setup-firewall.sh remove

Files:
======
  Backend:   $INSTALL_DIR/youtube_blocker.py
  Whitelist: /var/lib/youtube-blocker/whitelist.json
  Logs:      $LOG_FILE

Documentation:
==============
  README.md              - General overview
  QUICKSTART.md          - Quick installation guide
  FIREWALL-APPROACH.md   - Detailed firewall architecture
  TROUBLESHOOTING.md     - Common issues & solutions

Uninstall:
==========
  sudo ./uninstall.sh

Next Step: Install Chrome extension (see above) ⬆️
"
}

# Setup firewall rules
setup_firewall() {
    print_message "$YELLOW" "Setting up firewall to block YouTube..."

    if [ -f "./setup-firewall.sh" ]; then
        ./setup-firewall.sh setup
        print_message "$GREEN" "Firewall configured successfully"
    else
        print_message "$RED" "Error: setup-firewall.sh not found"
        exit 1
    fi
}

# Start backend manually (for non-systemd environments)
start_backend_manual() {
    print_message "$YELLOW" "Starting backend service manually..."

    if [ -f "./start-backend.sh" ]; then
        ./start-backend.sh start
        print_message "$GREEN" "Backend service started"
    else
        print_message "$RED" "Error: start-backend.sh not found"
        exit 1
    fi
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

    # Install dependencies
    install_dependencies

    # Create installation directory
    create_install_dir

    # Setup firewall (NEW - blocks YouTube system-wide)
    setup_firewall

    # Try to install and start systemd service
    # If systemd not available, start manually
    if command -v systemctl &> /dev/null; then
        install_service
        start_service
    else
        print_message "$YELLOW" "Systemd not available, starting backend manually..."
        start_backend_manual
    fi

    show_completion
}

# Run main function
main
