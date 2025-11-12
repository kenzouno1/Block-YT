#!/bin/bash

###############################################################################
# YouTube Blocker - Uninstallation Script
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

# Stop and disable service
stop_service() {
    print_message "$YELLOW" "Stopping YouTube Blocker service..."

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
    fi

    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl disable "$SERVICE_NAME"
    fi

    print_message "$GREEN" "Service stopped and disabled"
}

# Remove service file
remove_service() {
    print_message "$YELLOW" "Removing systemd service..."

    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    fi

    systemctl daemon-reload

    print_message "$GREEN" "Service removed"
}

# Remove installation files
remove_files() {
    print_message "$YELLOW" "Removing installation files..."

    # Remove installation directory
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi

    # Remove log file
    if [ -f "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
    fi

    print_message "$GREEN" "Installation files removed"
}

# Remove firewall rules
remove_firewall() {
    print_message "$YELLOW" "Removing firewall rules..."

    if [ -f "./setup-firewall.sh" ]; then
        ./setup-firewall.sh remove
        print_message "$GREEN" "Firewall rules removed"
    else
        print_message "$YELLOW" "setup-firewall.sh not found, skipping"
    fi
}

# Stop backend manually if running
stop_backend_manual() {
    print_message "$YELLOW" "Stopping backend service..."

    if [ -f "./start-backend.sh" ]; then
        ./start-backend.sh stop 2>/dev/null || print_message "$YELLOW" "Backend not running"
    fi
}

# Ask about keeping data
remove_data() {
    print_message "$YELLOW" "Remove whitelist data? (y/N)"
    read -p "" -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -d "/var/lib/youtube-blocker" ]; then
            rm -rf /var/lib/youtube-blocker
            print_message "$GREEN" "Data removed"
        fi
    else
        print_message "$YELLOW" "Whitelist data preserved at /var/lib/youtube-blocker"
    fi
}

# Show completion message
show_completion() {
    print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║                 Uninstallation Complete! 👋                    ║
╚════════════════════════════════════════════════════════════════╝

YouTube Blocker has been removed from your system.

What was removed:
  ✅ Firewall rules (iptables) - YouTube unblocked
  ✅ Backend service - Stopped and removed
  ✅ Installation files - Deleted
  ✅ Systemd service - Disabled and removed

YouTube is now accessible from all browsers again.

Note: You may need to manually remove the Chrome extension:
  1. Go to chrome://extensions/
  2. Find 'YouTube Blocker Whitelist'
  3. Click 'Remove'

If you kept whitelist data, it's still in:
  /var/lib/youtube-blocker/whitelist.json
"
}

# Main uninstallation process
main() {
    print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║           YouTube Blocker - Uninstallation Script              ║
╚════════════════════════════════════════════════════════════════╝
"

    check_root

    print_message "$YELLOW" "Starting uninstallation...\n"

    # Stop services
    stop_service              # Stop systemd service if exists
    stop_backend_manual       # Stop manual backend if running

    # Remove components
    remove_service            # Remove systemd service
    remove_firewall           # Remove iptables firewall rules
    remove_files              # Remove installation files

    # Ask about data
    remove_data               # Ask to remove whitelist data

    show_completion
}

# Run main function
main
