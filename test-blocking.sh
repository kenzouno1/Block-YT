#!/bin/bash

###############################################################################
# YouTube Blocker - Manual Test Script
# For environments without systemd
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKEND_DIR="backend"
HOSTS_FILE="/etc/hosts"

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

# YouTube domains to block
YOUTUBE_DOMAINS=(
    "www.youtube.com"
    "youtube.com"
    "youtu.be"
    "m.youtube.com"
    "youtube-ui.l.google.com"
    "youtubei.googleapis.com"
)

# Block YouTube in hosts file
block_youtube() {
    print_message "$YELLOW" "Blocking YouTube in /etc/hosts..."

    # Check if already blocked
    if grep -q "# YouTube Blocker - START" "$HOSTS_FILE"; then
        print_message "$YELLOW" "YouTube already blocked in hosts file"
        return
    fi

    # Backup hosts file
    cp "$HOSTS_FILE" "${HOSTS_FILE}.backup"

    # Add YouTube blocker entries
    {
        echo ""
        echo "# YouTube Blocker - START"
        for domain in "${YOUTUBE_DOMAINS[@]}"; do
            echo "127.0.0.1 $domain"
        done
        echo "# YouTube Blocker - END"
    } >> "$HOSTS_FILE"

    print_message "$GREEN" "YouTube blocked successfully!"
}

# Unblock YouTube
unblock_youtube() {
    print_message "$YELLOW" "Unblocking YouTube..."

    if ! grep -q "# YouTube Blocker - START" "$HOSTS_FILE"; then
        print_message "$YELLOW" "YouTube is not blocked"
        return
    fi

    # Remove YouTube blocker entries
    sed -i '/# YouTube Blocker - START/,/# YouTube Blocker - END/d' "$HOSTS_FILE"

    print_message "$GREEN" "YouTube unblocked!"
}

# Test blocking
test_block() {
    print_message "$YELLOW" "Testing YouTube block..."

    # Try to resolve youtube.com
    if host youtube.com 2>/dev/null | grep -q "127.0.0.1"; then
        print_message "$GREEN" "✅ YouTube is blocked (resolves to 127.0.0.1)"
    else
        print_message "$RED" "❌ YouTube is NOT blocked"
        print_message "$YELLOW" "DNS might be cached. Try:"
        print_message "$YELLOW" "  - Restart browser"
        print_message "$YELLOW" "  - Run: sudo systemd-resolve --flush-caches (if available)"
        print_message "$YELLOW" "  - Wait a few seconds and test again"
    fi
}

# Show current status
show_status() {
    print_message "$YELLOW" "Checking current status..."

    if grep -q "# YouTube Blocker - START" "$HOSTS_FILE"; then
        print_message "$GREEN" "YouTube is currently BLOCKED"
        echo ""
        print_message "$YELLOW" "Blocked domains:"
        grep -A 10 "# YouTube Blocker - START" "$HOSTS_FILE" | grep "127.0.0.1"
    else
        print_message "$RED" "YouTube is currently ALLOWED"
    fi
}

# Main menu
main() {
    check_root

    print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║           YouTube Blocker - Manual Test Script                ║
╚════════════════════════════════════════════════════════════════╝
"

    if [ "$1" == "block" ]; then
        block_youtube
        test_block
    elif [ "$1" == "unblock" ]; then
        unblock_youtube
    elif [ "$1" == "test" ]; then
        test_block
    elif [ "$1" == "status" ]; then
        show_status
    else
        print_message "$YELLOW" "Usage:"
        echo "  sudo $0 block    - Block YouTube"
        echo "  sudo $0 unblock  - Unblock YouTube"
        echo "  sudo $0 test     - Test if YouTube is blocked"
        echo "  sudo $0 status   - Show current status"
        echo ""
        show_status
    fi
}

# Run main function
main "$@"
