#!/bin/bash

###############################################################################
# YouTube Blocker - Chrome Extension Build Script
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
EXTENSION_DIR="chrome-extension"
BUILD_DIR="build"
EXTENSION_NAME="youtube-blocker-extension"

# Print colored message
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if python3-pil is installed
check_dependencies() {
    print_message "$YELLOW" "Checking dependencies..."

    if ! python3 -c "import PIL" 2>/dev/null; then
        print_message "$RED" "Error: python3-pil is not installed!"
        print_message "$YELLOW" "Installing python3-pil..."

        if [ "$EUID" -ne 0 ]; then
            print_message "$YELLOW" "Requires sudo for installation..."
            sudo apt-get update
            sudo apt-get install -y python3-pil
        else
            apt-get update
            apt-get install -y python3-pil
        fi
    fi

    print_message "$GREEN" "Dependencies OK"
}

# Generate extension icons
generate_icons() {
    print_message "$YELLOW" "Generating extension icons..."

    cd "$EXTENSION_DIR"
    python3 generate_icons.py
    cd ..

    print_message "$GREEN" "Icons generated successfully"
}

# Create build directory and package extension
package_extension() {
    print_message "$YELLOW" "Packaging extension..."

    # Create build directory
    mkdir -p "$BUILD_DIR"

    # Create a clean copy of extension
    rm -rf "$BUILD_DIR/$EXTENSION_NAME"
    mkdir -p "$BUILD_DIR/$EXTENSION_NAME"

    # Copy extension files
    cp -r "$EXTENSION_DIR"/* "$BUILD_DIR/$EXTENSION_NAME/"

    # Remove unnecessary files
    rm -f "$BUILD_DIR/$EXTENSION_NAME/generate_icons.py"

    print_message "$GREEN" "Extension packaged to: $BUILD_DIR/$EXTENSION_NAME"
}

# Create zip file
create_zip() {
    print_message "$YELLOW" "Creating zip file..."

    cd "$BUILD_DIR"
    zip -r "$EXTENSION_NAME.zip" "$EXTENSION_NAME" > /dev/null
    cd ..

    print_message "$GREEN" "Zip created: $BUILD_DIR/$EXTENSION_NAME.zip"
}

# Show completion message
show_completion() {
    print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║              Extension Build Complete! 🎉                      ║
╚════════════════════════════════════════════════════════════════╝

Extension has been built and packaged.

Files created:
  📁 $BUILD_DIR/$EXTENSION_NAME/          - Unpacked extension
  📦 $BUILD_DIR/$EXTENSION_NAME.zip       - Packaged extension

Installation options:

1. Load Unpacked (Development):
   - Open Chrome: chrome://extensions/
   - Enable 'Developer mode'
   - Click 'Load unpacked'
   - Select: $BUILD_DIR/$EXTENSION_NAME/

2. Chrome Web Store (Production):
   - Upload $BUILD_DIR/$EXTENSION_NAME.zip to Chrome Web Store
   - Follow Chrome Web Store publishing guidelines

Usage:
  - Click the extension icon in Chrome
  - Click 'Enable YouTube Access' to whitelist your profile
  - Only whitelisted profiles can access YouTube
"
}

# Main build process
main() {
    print_message "$GREEN" "
╔════════════════════════════════════════════════════════════════╗
║         YouTube Blocker - Extension Build Script               ║
╚════════════════════════════════════════════════════════════════╝
"

    print_message "$YELLOW" "Starting build...\n"

    check_dependencies
    generate_icons
    package_extension
    create_zip

    show_completion
}

# Run main function
main
