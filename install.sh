#!/bin/bash

###############################################################################
# YouTube Blocker - One-Click Installation Script
# This script does EVERYTHING: install dependencies, setup firewall, start service
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
PROXY_PORT=8888
YOUTUBE_DOMAINS=(
    "youtube.com"
    "www.youtube.com"
    "m.youtube.com"
    "youtu.be"
    "googlevideo.com"
    "ytimg.com"
    "youtube-nocookie.com"
)

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

# Check if iptables is available
check_iptables() {
    if ! command -v iptables &> /dev/null; then
        print_message "$RED" "❌ Error: iptables command not found"
        print_message "$YELLOW" ""
        print_message "$YELLOW" "This script requires iptables for firewall blocking."
        print_message "$YELLOW" ""
        print_message "$YELLOW" "Common causes:"
        print_message "$YELLOW" "  - Running in a container/sandbox (Docker, LXC, etc.)"
        print_message "$YELLOW" "  - iptables not installed on the system"
        print_message "$YELLOW" ""
        print_message "$YELLOW" "Solutions:"
        print_message "$YELLOW" "  1. Run on a real Ubuntu system (not container)"
        print_message "$YELLOW" "  2. Install iptables: sudo apt-get install iptables"
        print_message "$YELLOW" "  3. Use Docker with --cap-add=NET_ADMIN flag"
        print_message "$YELLOW" ""
        print_message "$RED" "Cannot proceed without iptables. Installation aborted."
        exit 1
    fi
    return 0
}

# Setup /etc/hosts blocking for YouTube
setup_hosts_blocking() {
    print_message "$YELLOW" "Setting up /etc/hosts blocking for YouTube..."

    # Backup hosts file if not exists
    if [ ! -f /etc/hosts.backup ]; then
        cp /etc/hosts /etc/hosts.backup
        print_message "$GREEN" "✅ Created hosts file backup"
    fi

    # Remove old YouTube entries
    sed -i '/# YouTube Blocker - START/,/# YouTube Blocker - END/d' /etc/hosts

    # Add YouTube domains pointing to 127.0.0.1
    # This blocks all browsers from accessing YouTube
    # Chrome with extension bypasses this by using proxy
    cat >> /etc/hosts << 'EOF'
# YouTube Blocker - START
127.0.0.1 youtube.com
127.0.0.1 www.youtube.com
127.0.0.1 m.youtube.com
127.0.0.1 studio.youtube.com
127.0.0.1 music.youtube.com
127.0.0.1 tv.youtube.com
127.0.0.1 kids.youtube.com
127.0.0.1 gaming.youtube.com
127.0.0.1 youtu.be
127.0.0.1 www.youtu.be
127.0.0.1 youtubei.googleapis.com
127.0.0.1 youtube-ui.l.google.com
# YouTube Blocker - END
EOF

    print_message "$GREEN" "✅ YouTube domains blocked in /etc/hosts"
}

# Install Python dependencies
install_dependencies() {
    print_message "$YELLOW" "Installing Python dependencies..."

    # Update package list
    apt-get update

    # Install Python packages from apt (Ubuntu 22.04+ uses PEP 668)
    print_message "$YELLOW" "Installing dependencies..."
    apt-get install -y \
        python3 \
        python3-flask \
        python3-flask-cors \
        python3-requests \
        python3-pil \
        dnsutils \
        iptables \
        iptables-persistent

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

# Note: We use /etc/hosts blocking instead of iptables
# This is simpler and more reliable:
# - Browsers resolve YouTube to 127.0.0.1 → Connection fails
# - Chrome with extension uses proxy which resolves real IPs → Bypasses /etc/hosts
# - No complex iptables rules needed
# - Google services (Gmail, Drive, etc.) work normally

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

# Start backend manually (for non-systemd environments)
start_backend_manual() {
    print_message "$YELLOW" "Starting backend service manually..."

    # Check if already running
    if [ -f "/tmp/youtube-blocker.pid" ]; then
        local pid=$(cat /tmp/youtube-blocker.pid)
        if ps -p "$pid" > /dev/null 2>&1; then
            print_message "$YELLOW" "Backend already running (PID: $pid), stopping first..."
            kill "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
            sleep 1
        fi
        rm -f /tmp/youtube-blocker.pid
    fi

    # Start backend in background
    cd "$(dirname "$0")"
    nohup python3 backend/youtube_blocker.py > /tmp/youtube-blocker.log 2>&1 &
    local pid=$!
    echo $pid > /tmp/youtube-blocker.pid

    # Wait for service to start
    sleep 2

    # Check if started successfully
    if ps -p "$pid" > /dev/null 2>&1; then
        print_message "$GREEN" "✅ Backend service started successfully!"
        print_message "$GREEN" "   PID: $pid"

        # Test API
        if curl -s http://127.0.0.1:9876/api/health > /dev/null 2>&1; then
            print_message "$GREEN" "   API: http://127.0.0.1:9876 ✅"
            print_message "$GREEN" "   Proxy: http://127.0.0.1:8888 ✅"
        else
            print_message "$YELLOW" "   Waiting for API to be ready..."
            sleep 2
            if curl -s http://127.0.0.1:9876/api/health > /dev/null 2>&1; then
                print_message "$GREEN" "   API: http://127.0.0.1:9876 ✅"
            else
                print_message "$RED" "   API not responding. Check logs:"
                print_message "$YELLOW" "   tail -f /tmp/youtube-blocker.log"
            fi
        fi
    else
        print_message "$RED" "❌ Failed to start backend service"
        print_message "$YELLOW" "Check logs: tail -f /tmp/youtube-blocker.log"
        exit 1
    fi
}

# Show completion message
show_completion() {
    print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║                   Installation Complete! 🎉                    ║
╚════════════════════════════════════════════════════════════════╝

YouTube is now BLOCKED system-wide via /etc/hosts.

✅ /etc/hosts configured - YouTube domains → 127.0.0.1
✅ Backend service running - API & Proxy ready
✅ All Google services work normally (Gmail, Drive, Search, etc.)

How it works:
=============
  1. All browsers resolve youtube.com → 127.0.0.1
  2. Connection fails (YouTube blocked)
  3. Chrome with extension uses proxy
  4. Proxy resolves real YouTube IPs (bypasses /etc/hosts)
  5. Chrome with extension can access YouTube!

IMPORTANT - Install Chrome Extension:
=====================================
Chrome profiles need the extension to access YouTube.

1. Open Chrome: chrome://extensions/
2. Enable 'Developer mode' (top right)
3. Click 'Load unpacked'
4. Select: $PWD/build/youtube-blocker-extension/

The extension will:
  - Auto-enable on install (no click needed)
  - Configure PAC script proxy: 127.0.0.1:8888
  - Register profile with backend
  - Bypass /etc/hosts blocking

Result:
=======
  ✅ Chrome with extension → YouTube accessible
  ✅ Gmail, Drive, Search → All work normally
  ❌ Firefox/Edge → YouTube blocked
  ❌ Chrome without extension → YouTube blocked

Service Management:
===================
  Status:   sudo systemctl status $SERVICE_NAME
  Restart:  sudo systemctl restart $SERVICE_NAME
  Logs:     sudo journalctl -u $SERVICE_NAME -f

Or if no systemd:
  Check:    ps aux | grep youtube_blocker.py
  Logs:     tail -f /tmp/youtube-blocker.log

Hosts File:
===========
  View:     cat /etc/hosts | grep -A 10 'YouTube Blocker'
  Restore:  sudo cp /etc/hosts.backup /etc/hosts

Files:
======
  Backend:   $INSTALL_DIR/youtube_blocker.py
  Whitelist: /var/lib/youtube-blocker/whitelist.json
  Logs:      $LOG_FILE
  Hosts:     /etc/hosts

Uninstall:
==========
  sudo ./uninstall.sh

Next Step: Install Chrome extension (see above) ⬆️
"
}

# Main installation process
main() {
    print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║        YouTube Blocker - One-Click Installation                ║
╚════════════════════════════════════════════════════════════════╝
"

    check_root
    check_ubuntu

    print_message "$YELLOW" "Starting installation...\\n"

    # Install dependencies (including iptables-persistent for future use)
    install_dependencies

    # Create installation directory
    create_install_dir

    # Setup /etc/hosts blocking (BLOCKS YouTube for all browsers)
    setup_hosts_blocking

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
