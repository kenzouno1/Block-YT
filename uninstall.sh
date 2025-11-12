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

# Stop and disable systemd service
stop_service() {
    print_message "$YELLOW" "Stopping YouTube Blocker service..."

    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            systemctl stop "$SERVICE_NAME"
        fi

        if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
            systemctl disable "$SERVICE_NAME"
        fi

        print_message "$GREEN" "Systemd service stopped and disabled"
    else
        print_message "$YELLOW" "Systemd not available, skipping"
    fi
}

# Stop backend manually if running
stop_backend_manual() {
    print_message "$YELLOW" "Stopping backend service..."

    # Check PID file
    if [ -f "/tmp/youtube-blocker.pid" ]; then
        local pid=$(cat /tmp/youtube-blocker.pid)
        if ps -p "$pid" > /dev/null 2>&1; then
            print_message "$YELLOW" "Killing backend process (PID: $pid)..."
            kill "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true

            # Wait for process to stop
            for i in {1..5}; do
                if ! ps -p "$pid" > /dev/null 2>&1; then
                    break
                fi
                sleep 1
            done

            # Force kill if still running
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null || true
            fi

            print_message "$GREEN" "Backend stopped"
        fi
        rm -f /tmp/youtube-blocker.pid
    else
        # Try to find and kill any running instances
        pkill -f "youtube_blocker.py" 2>/dev/null || true
        print_message "$GREEN" "No backend process found or stopped"
    fi
}

# Remove systemd service file
remove_service() {
    print_message "$YELLOW" "Removing systemd service..."

    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
        if command -v systemctl &> /dev/null; then
            systemctl daemon-reload
        fi
        print_message "$GREEN" "Service removed"
    else
        print_message "$YELLOW" "Service file not found, skipping"
    fi
}

# Clean up hosts file
cleanup_hosts_file() {
    print_message "$YELLOW" "Removing YouTube entries from /etc/hosts..."

    if grep -q "YouTube Blocker" /etc/hosts 2>/dev/null; then
        # Remove YouTube Blocker entries
        sed -i '/# YouTube Blocker - START/,/# YouTube Blocker - END/d' /etc/hosts

        print_message "$GREEN" "✅ YouTube entries removed from /etc/hosts"

        # Restore from backup if exists
        if [ -f /etc/hosts.backup ]; then
            print_message "$YELLOW" "Backup found at /etc/hosts.backup (kept for safety)"
        fi
    else
        print_message "$GREEN" "✅ No YouTube entries found in /etc/hosts"
    fi
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

    # Remove temporary log file
    if [ -f "/tmp/youtube-blocker.log" ]; then
        rm -f "/tmp/youtube-blocker.log"
    fi

    print_message "$GREEN" "Installation files removed"
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
  ✅ /etc/hosts entries - YouTube unblocked
  ✅ Backend service - Stopped and removed
  ✅ Installation files - Deleted
  ✅ Systemd service - Disabled and removed

YouTube is now accessible from all browsers again.

Note: You may need to manually remove the Chrome extension:
  1. Go to chrome://extensions/
  2. Find 'YouTube Blocker Whitelist'
  3. Click 'Remove'

Backup files kept (for safety):
  - /etc/hosts.backup (original hosts file)

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
    cleanup_hosts_file        # Clean up hosts file entries
    remove_files              # Remove installation files

    # Ask about data
    remove_data               # Ask to remove whitelist data

    show_completion
}

# Run main function
main
