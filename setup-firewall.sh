#!/bin/bash

###############################################################################
# YouTube Blocker - Firewall Setup Script
# Blocks YouTube using iptables, allows only proxy server to access
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
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

# Resolve YouTube IPs
resolve_youtube_ips() {
    print_message "$YELLOW" "Resolving YouTube IP addresses..."

    # Check if hosts file has YouTube entries (would interfere with DNS)
    if grep -q "youtube" /etc/hosts 2>/dev/null; then
        print_message "$YELLOW" "⚠️  Warning: /etc/hosts has YouTube entries, using IP ranges only"
        print_message "$YELLOW" "   Run: sudo ./fix-after-uninstall.sh to clean up hosts file"
    fi

    local ips=()

    # Try to resolve IPs using getent (fallback to hardcoded ranges if fails)
    for domain in "${YOUTUBE_DOMAINS[@]}"; do
        # Use getent ahosts instead of dig (more portable)
        local domain_ips=$(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^127\.' | sort -u || true)

        if [ -n "$domain_ips" ]; then
            while IFS= read -r ip; do
                if [[ ! " ${ips[@]} " =~ " ${ip} " ]]; then
                    ips+=("$ip")
                    print_message "$GREEN" "  Found: $ip ($domain)"
                fi
            done <<< "$domain_ips"
        fi
    done

    # Always add YouTube IP ranges (Google's IP ranges)
    # These are more reliable than DNS resolution
    local google_ranges=(
        "172.217.0.0/16"
        "142.250.0.0/15"
        "216.58.192.0/19"
        "172.253.0.0/16"
        "142.251.0.0/16"
        "172.253.0.0/16"
    )

    for range in "${google_ranges[@]}"; do
        ips+=("$range")
        print_message "$GREEN" "  Added range: $range"
    done

    # If no IPs resolved at all, warn user
    if [ ${#ips[@]} -eq 0 ]; then
        print_message "$RED" "❌ Failed to resolve any YouTube IPs"
        print_message "$YELLOW" "   This might be due to network issues or DNS configuration"
        return 1
    fi

    echo "${ips[@]}"
}

# Setup iptables rules
setup_firewall() {
    print_message "$YELLOW" "Setting up firewall rules..."

    # Get YouTube IPs
    local youtube_ips=($(resolve_youtube_ips))

    if [ ${#youtube_ips[@]} -eq 0 ]; then
        print_message "$RED" "Error: No YouTube IPs resolved"
        exit 1
    fi

    # Create custom chain for YouTube blocking
    iptables -N YOUTUBE_BLOCK 2>/dev/null || iptables -F YOUTUBE_BLOCK

    # Block YouTube IPs in the custom chain
    for ip in "${youtube_ips[@]}"; do
        iptables -A YOUTUBE_BLOCK -d "$ip" -j REJECT --reject-with icmp-host-prohibited
    done

    # Insert rule at the beginning of OUTPUT chain
    # But ALLOW localhost connections (for proxy)
    iptables -C OUTPUT -o lo -j ACCEPT 2>/dev/null || \
        iptables -I OUTPUT 1 -o lo -j ACCEPT

    # Jump to YOUTUBE_BLOCK chain for non-localhost traffic
    iptables -C OUTPUT ! -o lo -j YOUTUBE_BLOCK 2>/dev/null || \
        iptables -I OUTPUT 2 ! -o lo -j YOUTUBE_BLOCK

    print_message "$GREEN" "✅ Firewall rules configured"
    print_message "$GREEN" "   - YouTube IPs blocked: ${#youtube_ips[@]}"
    print_message "$GREEN" "   - Localhost traffic allowed (for proxy)"
}

# Remove firewall rules
remove_firewall() {
    print_message "$YELLOW" "Removing firewall rules..."

    # Remove OUTPUT rules
    iptables -D OUTPUT -o lo -j ACCEPT 2>/dev/null || true
    iptables -D OUTPUT ! -o lo -j YOUTUBE_BLOCK 2>/dev/null || true

    # Flush and delete custom chain
    iptables -F YOUTUBE_BLOCK 2>/dev/null || true
    iptables -X YOUTUBE_BLOCK 2>/dev/null || true

    print_message "$GREEN" "✅ Firewall rules removed"
}

# Show current status
show_status() {
    print_message "$YELLOW" "Current firewall status..."

    if iptables -L YOUTUBE_BLOCK -n 2>/dev/null | grep -q "REJECT"; then
        print_message "$GREEN" "✅ YouTube blocking is ACTIVE"
        echo ""
        print_message "$YELLOW" "Blocked IPs/ranges:"
        iptables -L YOUTUBE_BLOCK -n --line-numbers | grep REJECT
    else
        print_message "$RED" "❌ YouTube blocking is NOT active"
    fi
}

# Test connectivity
test_blocking() {
    print_message "$YELLOW" "Testing YouTube connectivity..."

    # Test direct connection (should fail)
    if timeout 3 curl -s https://www.youtube.com > /dev/null 2>&1; then
        print_message "$RED" "❌ YouTube is accessible (blocking not working)"
    else
        print_message "$GREEN" "✅ YouTube is blocked (direct access fails)"
    fi

    # Test via proxy (should work if proxy is running)
    if timeout 3 curl -s --proxy http://127.0.0.1:$PROXY_PORT https://www.youtube.com > /dev/null 2>&1; then
        print_message "$GREEN" "✅ Proxy access works"
    else
        print_message "$YELLOW" "⚠️  Proxy access failed (proxy may not be running)"
    fi
}

# Save rules to persist across reboots
save_rules() {
    print_message "$YELLOW" "Saving firewall rules..."

    if command -v iptables-save > /dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
        iptables-save > /etc/iptables.rules 2>/dev/null || \
        print_message "$YELLOW" "⚠️  Could not save rules (install iptables-persistent)"

        print_message "$GREEN" "✅ Rules saved"
    fi
}

# Main menu
main() {
    check_root

    print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║         YouTube Blocker - Firewall Setup                       ║
╚════════════════════════════════════════════════════════════════╝
"

    case "${1:-}" in
        setup)
            setup_firewall
            save_rules
            test_blocking
            ;;
        remove)
            remove_firewall
            save_rules
            ;;
        status)
            show_status
            ;;
        test)
            test_blocking
            ;;
        *)
            print_message "$YELLOW" "Usage: sudo $0 {setup|remove|status|test}"
            echo ""
            echo "Commands:"
            echo "  setup   - Setup firewall rules to block YouTube"
            echo "  remove  - Remove firewall rules"
            echo "  status  - Show current firewall status"
            echo "  test    - Test if blocking works"
            echo ""
            show_status
            ;;
    esac
}

# Run main function
main "$@"
