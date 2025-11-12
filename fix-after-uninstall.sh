#!/bin/bash

###############################################################################
# Fix After Uninstall - Clean up hosts file and restart
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_message "$RED" "Error: This script must be run as root (use sudo)"
        exit 1
    fi
}

print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║              Fix After Uninstall - Cleanup Script              ║
╚════════════════════════════════════════════════════════════════╝
"

check_root

# Step 1: Remove YouTube entries from /etc/hosts
print_message "$YELLOW" "Step 1: Removing YouTube entries from /etc/hosts..."

if grep -q "youtube" /etc/hosts 2>/dev/null; then
    # Backup hosts file
    cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)

    # Remove YouTube entries
    sed -i '/youtube/d' /etc/hosts
    sed -i '/googlevideo/d' /etc/hosts
    sed -i '/ytimg/d' /etc/hosts

    print_message "$GREEN" "✅ YouTube entries removed from /etc/hosts"
else
    print_message "$GREEN" "✅ No YouTube entries in /etc/hosts"
fi

# Step 2: Stop old backend
print_message "$YELLOW" "\nStep 2: Stopping old backend service..."

if [ -f "/tmp/youtube-blocker.pid" ]; then
    PID=$(cat /tmp/youtube-blocker.pid)
    if ps -p "$PID" > /dev/null 2>&1; then
        kill "$PID" 2>/dev/null || kill -9 "$PID" 2>/dev/null || true
        rm -f /tmp/youtube-blocker.pid
        print_message "$GREEN" "✅ Old backend stopped"
    else
        rm -f /tmp/youtube-blocker.pid
        print_message "$YELLOW" "⚠️  Backend was not running"
    fi
else
    # Try to find and kill any running instances
    pkill -f "youtube_blocker.py" 2>/dev/null || true
    print_message "$GREEN" "✅ Cleaned up any running instances"
fi

# Step 3: Start new backend
print_message "$YELLOW" "\nStep 3: Starting new backend with firewall approach..."

cd "$(dirname "$0")"
nohup python3 backend/youtube_blocker.py > /tmp/youtube-blocker.log 2>&1 &
NEW_PID=$!
echo $NEW_PID > /tmp/youtube-blocker.pid

sleep 2

if ps -p "$NEW_PID" > /dev/null 2>&1; then
    print_message "$GREEN" "✅ New backend started (PID: $NEW_PID)"

    # Test API
    if curl -s http://127.0.0.1:9876/api/health > /dev/null 2>&1; then
        print_message "$GREEN" "✅ API is responding"
    else
        print_message "$YELLOW" "⚠️  Waiting for API..."
        sleep 2
    fi
else
    print_message "$RED" "❌ Failed to start backend"
    print_message "$YELLOW" "Check logs: tail -f /tmp/youtube-blocker.log"
    exit 1
fi

# Step 4: Test YouTube access
print_message "$YELLOW" "\nStep 4: Testing YouTube access..."

if timeout 3 curl -s https://www.youtube.com > /dev/null 2>&1; then
    print_message "$GREEN" "✅ YouTube is now accessible (firewall not active yet)"
else
    print_message "$RED" "❌ YouTube still blocked (check network or DNS)"
fi

print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║                      Cleanup Complete!                         ║
╚════════════════════════════════════════════════════════════════╝

What was done:
  ✅ Removed YouTube entries from /etc/hosts
  ✅ Stopped old backend service
  ✅ Started new backend (firewall approach)

YouTube should now be accessible.

Next Steps:
===========

To BLOCK YouTube again with firewall approach:
  sudo ./setup-firewall.sh setup

To check backend status:
  sudo ./start-backend.sh status

To view backend logs:
  tail -f /tmp/youtube-blocker.log

Note: The new version uses iptables firewall instead of /etc/hosts.
This allows per-profile whitelisting via Chrome extension.
"
