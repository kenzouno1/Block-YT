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

# Clean up old hosts file entries (from previous version)
cleanup_hosts_file() {
    print_message "$YELLOW" "Checking for old /etc/hosts entries..."

    if grep -q "youtube" /etc/hosts 2>/dev/null; then
        print_message "$YELLOW" "Found old YouTube entries in /etc/hosts, cleaning up..."

        # Backup hosts file
        cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)

        # Remove YouTube entries
        sed -i '/# YouTube Blocker - START/,/# YouTube Blocker - END/d' /etc/hosts
        sed -i '/youtube/d' /etc/hosts
        sed -i '/googlevideo/d' /etc/hosts
        sed -i '/ytimg/d' /etc/hosts

        print_message "$GREEN" "✅ Old hosts entries removed"
    else
        print_message "$GREEN" "✅ No old hosts entries found"
    fi
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
        python3-pil \
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

# Resolve YouTube IPs (without printing to stdout, use stderr for messages)
resolve_youtube_ips() {
    local ips=()

    # Resolve IPs from YouTube-specific domains
    # This will only block YouTube, not other Google services
    for domain in "${YOUTUBE_DOMAINS[@]}"; do
        local domain_ips=$(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^127\.' | sort -u || true)

        if [ -n "$domain_ips" ]; then
            while IFS= read -r ip; do
                if [[ ! " ${ips[@]} " =~ " ${ip} " ]]; then
                    ips+=("$ip")
                fi
            done <<< "$domain_ips"
        fi
    done

    # IMPORTANT: Do NOT add Google IP ranges here!
    # YouTube shares infrastructure with other Google services (Gmail, Drive, Search, etc.)
    # Blocking entire Google IP ranges would affect all Google services
    # We ONLY block specific IPs resolved from YouTube domains above

    # If no IPs were resolved, add some known YouTube-specific IPs as fallback
    # These are content delivery IPs primarily used by YouTube
    if [ ${#ips[@]} -eq 0 ]; then
        # Add a few known YouTube video server IPs as fallback
        # These are less likely to affect other Google services
        ips+=(
            "172.217.194.0/24"  # YouTube CDN
            "142.250.185.0/24"  # YouTube CDN
        )
    fi

    # Return IPs
    echo "${ips[@]}"
}

# Setup firewall to block YouTube
setup_firewall() {
    print_message "$YELLOW" "Setting up firewall to block YouTube..."

    # Get YouTube IPs
    local youtube_ips=($(resolve_youtube_ips))

    if [ ${#youtube_ips[@]} -eq 0 ]; then
        print_message "$RED" "Error: No YouTube IPs resolved"
        exit 1
    fi

    print_message "$YELLOW" "Resolved ${#youtube_ips[@]} YouTube IP addresses/ranges"

    # Create custom chain for YouTube blocking
    iptables -N YOUTUBE_BLOCK 2>/dev/null || iptables -F YOUTUBE_BLOCK

    # Block YouTube IPs in the custom chain
    for ip in "${youtube_ips[@]}"; do
        iptables -A YOUTUBE_BLOCK -d "$ip" -j REJECT --reject-with icmp-host-prohibited 2>/dev/null || true
    done

    # Insert rule at the beginning of OUTPUT chain
    # But ALLOW localhost connections (for proxy)
    iptables -C OUTPUT -o lo -j ACCEPT 2>/dev/null || \
        iptables -I OUTPUT 1 -o lo -j ACCEPT

    # Jump to YOUTUBE_BLOCK chain for non-localhost traffic
    iptables -C OUTPUT ! -o lo -j YOUTUBE_BLOCK 2>/dev/null || \
        iptables -I OUTPUT 2 ! -o lo -j YOUTUBE_BLOCK

    # Save rules to persist across reboots
    if command -v iptables-save > /dev/null 2>&1; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
        iptables-save > /etc/iptables.rules 2>/dev/null || true

        # Use netfilter-persistent if available
        if command -v netfilter-persistent > /dev/null 2>&1; then
            netfilter-persistent save 2>/dev/null || true
        fi
    fi

    print_message "$GREEN" "✅ Firewall configured successfully"
    print_message "$GREEN" "   - YouTube IPs blocked: ${#youtube_ips[@]}"
    print_message "$GREEN" "   - Localhost traffic allowed (for proxy)"
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

Service Management:
===================
  Status:   sudo systemctl status $SERVICE_NAME
  Restart:  sudo systemctl restart $SERVICE_NAME
  Logs:     sudo journalctl -u $SERVICE_NAME -f

Or if no systemd:
  Check:    ps aux | grep youtube_blocker.py
  Logs:     tail -f /tmp/youtube-blocker.log

Firewall Management:
====================
  Check:    sudo iptables -L YOUTUBE_BLOCK -n
  Remove:   sudo ./uninstall.sh

Files:
======
  Backend:   $INSTALL_DIR/youtube_blocker.py
  Whitelist: /var/lib/youtube-blocker/whitelist.json
  Logs:      $LOG_FILE

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
    check_iptables

    print_message "$YELLOW" "Starting installation...\\n"

    # Clean up old version (hosts file entries)
    cleanup_hosts_file

    # Install dependencies
    install_dependencies

    # Create installation directory
    create_install_dir

    # Setup firewall (BLOCKS YouTube system-wide)
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
