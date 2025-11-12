#!/bin/bash

###############################################################################
# YouTube Blocker - Start Backend Service Manually
# For environments without systemd (containers, WSL, etc.)
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKEND_DIR="backend"
LOG_FILE="/tmp/youtube-blocker.log"
PID_FILE="/tmp/youtube-blocker.pid"

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

# Check if backend is already running
check_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0  # Running
        else
            rm -f "$PID_FILE"  # Stale PID file
        fi
    fi
    return 1  # Not running
}

# Start backend
start_backend() {
    print_message "$YELLOW" "Starting YouTube Blocker backend service..."

    # Check if already running
    if check_running; then
        print_message "$YELLOW" "Backend is already running (PID: $(cat $PID_FILE))"
        print_message "$YELLOW" "Use: sudo $0 stop   to stop it first"
        return
    fi

    # Check dependencies
    if ! python3 -c "import flask" 2>/dev/null; then
        print_message "$RED" "Error: flask is not installed!"
        print_message "$YELLOW" "Install with: sudo apt-get install python3-flask python3-flask-cors python3-requests"
        exit 1
    fi

    # Start backend in background
    nohup python3 "$BACKEND_DIR/youtube_blocker.py" > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"

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
                print_message "$YELLOW" "   tail -f $LOG_FILE"
            fi
        fi
    else
        print_message "$RED" "❌ Failed to start backend service"
        print_message "$YELLOW" "Check logs: tail -f $LOG_FILE"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Stop backend
stop_backend() {
    print_message "$YELLOW" "Stopping YouTube Blocker backend service..."

    if ! check_running; then
        print_message "$YELLOW" "Backend is not running"
        return
    fi

    local pid=$(cat "$PID_FILE")
    kill "$pid" 2>/dev/null || true

    # Wait for process to stop
    for i in {1..5}; do
        if ! ps -p "$pid" > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    # Force kill if still running
    if ps -p "$pid" > /dev/null 2>&1; then
        print_message "$YELLOW" "Force killing backend..."
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$PID_FILE"
    print_message "$GREEN" "✅ Backend service stopped"
}

# Show status
show_status() {
    print_message "$YELLOW" "Checking backend service status..."

    if check_running; then
        local pid=$(cat "$PID_FILE")
        print_message "$GREEN" "✅ Backend is RUNNING"
        print_message "$GREEN" "   PID: $pid"

        # Test API
        if curl -s http://127.0.0.1:9876/api/health > /dev/null 2>&1; then
            print_message "$GREEN" "   API: http://127.0.0.1:9876 ✅"

            # Get whitelist count
            local count=$(curl -s http://127.0.0.1:9876/api/whitelist/list 2>/dev/null | grep -o '"profile_id"' | wc -l || echo "0")
            print_message "$GREEN" "   Whitelisted profiles: $count"
        else
            print_message "$RED" "   API: Not responding ❌"
        fi

        # Show resource usage
        ps -p "$pid" -o pid,ppid,%cpu,%mem,etime,cmd 2>/dev/null || true
    else
        print_message "$RED" "❌ Backend is NOT running"
        print_message "$YELLOW" "   Start with: sudo $0 start"
    fi
}

# Show logs
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        print_message "$YELLOW" "Last 50 lines of logs:"
        tail -n 50 "$LOG_FILE"
    else
        print_message "$YELLOW" "No logs found"
    fi
}

# Restart backend
restart_backend() {
    stop_backend
    sleep 1
    start_backend
}

# Main menu
main() {
    check_root

    print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║        YouTube Blocker - Backend Service Manager              ║
╚════════════════════════════════════════════════════════════════╝
"

    case "${1:-}" in
        start)
            start_backend
            ;;
        stop)
            stop_backend
            ;;
        restart)
            restart_backend
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        *)
            print_message "$YELLOW" "Usage: sudo $0 {start|stop|restart|status|logs}"
            echo ""
            echo "Commands:"
            echo "  start    - Start the backend service"
            echo "  stop     - Stop the backend service"
            echo "  restart  - Restart the backend service"
            echo "  status   - Show service status"
            echo "  logs     - Show service logs"
            echo ""
            show_status
            ;;
    esac
}

# Run main function
main "$@"
