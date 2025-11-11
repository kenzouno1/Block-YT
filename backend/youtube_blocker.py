#!/usr/bin/env python3
"""
YouTube Blocker Service
Blocks YouTube access by default and allows whitelisted Chrome profiles through a proxy
"""

import os
import json
import logging
import socket
import threading
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
import secrets

# Configuration
WHITELIST_FILE = '/var/lib/youtube-blocker/whitelist.json'
HOSTS_FILE = '/etc/hosts'
LOG_FILE = '/var/log/youtube-blocker.log'
API_PORT = 9876
PROXY_PORT = 8888

# YouTube domains to block
YOUTUBE_DOMAINS = [
    'www.youtube.com',
    'youtube.com',
    'youtu.be',
    'm.youtube.com',
    'youtube-ui.l.google.com',
    'youtubei.googleapis.com',
]

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('YouTubeBlocker')

app = Flask(__name__)
CORS(app)

class WhitelistManager:
    """Manages whitelisted Chrome profiles"""

    def __init__(self):
        self.whitelist = {}
        self.load_whitelist()

    def load_whitelist(self):
        """Load whitelist from file"""
        try:
            if os.path.exists(WHITELIST_FILE):
                with open(WHITELIST_FILE, 'r') as f:
                    self.whitelist = json.load(f)
                logger.info(f"Loaded {len(self.whitelist)} whitelisted profiles")
            else:
                # Create directory if it doesn't exist
                os.makedirs(os.path.dirname(WHITELIST_FILE), exist_ok=True)
                self.whitelist = {}
                self.save_whitelist()
        except Exception as e:
            logger.error(f"Error loading whitelist: {e}")
            self.whitelist = {}

    def save_whitelist(self):
        """Save whitelist to file"""
        try:
            with open(WHITELIST_FILE, 'w') as f:
                json.dump(self.whitelist, f, indent=2)
            logger.info("Whitelist saved successfully")
        except Exception as e:
            logger.error(f"Error saving whitelist: {e}")

    def add_profile(self, profile_id, profile_name):
        """Add a Chrome profile to whitelist"""
        token = secrets.token_urlsafe(32)
        self.whitelist[token] = {
            'profile_id': profile_id,
            'profile_name': profile_name,
            'added_at': datetime.now().isoformat()
        }
        self.save_whitelist()
        logger.info(f"Added profile to whitelist: {profile_name} ({profile_id})")
        return token

    def remove_profile(self, token):
        """Remove a Chrome profile from whitelist"""
        if token in self.whitelist:
            profile = self.whitelist.pop(token)
            self.save_whitelist()
            logger.info(f"Removed profile from whitelist: {profile['profile_name']}")
            return True
        return False

    def is_whitelisted(self, token):
        """Check if a token is whitelisted"""
        return token in self.whitelist

    def get_all(self):
        """Get all whitelisted profiles"""
        return self.whitelist

class HostsFileManager:
    """Manages /etc/hosts file to block YouTube"""

    MARKER_START = "# YouTube Blocker - START"
    MARKER_END = "# YouTube Blocker - END"

    @staticmethod
    def block_youtube():
        """Add YouTube domains to hosts file"""
        try:
            # Read current hosts file
            with open(HOSTS_FILE, 'r') as f:
                lines = f.readlines()

            # Remove existing YouTube blocker entries
            new_lines = []
            skip = False
            for line in lines:
                if HostsFileManager.MARKER_START in line:
                    skip = True
                    continue
                if HostsFileManager.MARKER_END in line:
                    skip = False
                    continue
                if not skip:
                    new_lines.append(line)

            # Add new YouTube blocker entries
            new_lines.append(f"\n{HostsFileManager.MARKER_START}\n")
            for domain in YOUTUBE_DOMAINS:
                new_lines.append(f"127.0.0.1 {domain}\n")
            new_lines.append(f"{HostsFileManager.MARKER_END}\n")

            # Write back to hosts file
            with open(HOSTS_FILE, 'w') as f:
                f.writelines(new_lines)

            logger.info("YouTube domains blocked in hosts file")
            return True
        except Exception as e:
            logger.error(f"Error blocking YouTube in hosts file: {e}")
            return False

    @staticmethod
    def unblock_youtube():
        """Remove YouTube domains from hosts file"""
        try:
            # Read current hosts file
            with open(HOSTS_FILE, 'r') as f:
                lines = f.readlines()

            # Remove YouTube blocker entries
            new_lines = []
            skip = False
            for line in lines:
                if HostsFileManager.MARKER_START in line:
                    skip = True
                    continue
                if HostsFileManager.MARKER_END in line:
                    skip = False
                    continue
                if not skip:
                    new_lines.append(line)

            # Write back to hosts file
            with open(HOSTS_FILE, 'w') as f:
                f.writelines(new_lines)

            logger.info("YouTube domains unblocked in hosts file")
            return True
        except Exception as e:
            logger.error(f"Error unblocking YouTube in hosts file: {e}")
            return False

# Initialize managers
whitelist_manager = WhitelistManager()
hosts_manager = HostsFileManager()

# API Routes
@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'service': 'youtube-blocker'})

@app.route('/api/whitelist/add', methods=['POST'])
def add_to_whitelist():
    """Add a Chrome profile to whitelist"""
    try:
        data = request.json
        profile_id = data.get('profile_id')
        profile_name = data.get('profile_name', 'Unknown')

        if not profile_id:
            return jsonify({'error': 'profile_id is required'}), 400

        token = whitelist_manager.add_profile(profile_id, profile_name)

        return jsonify({
            'success': True,
            'token': token,
            'proxy_url': f'http://127.0.0.1:{PROXY_PORT}',
            'message': 'Profile added to whitelist'
        })
    except Exception as e:
        logger.error(f"Error adding to whitelist: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/whitelist/remove', methods=['POST'])
def remove_from_whitelist():
    """Remove a Chrome profile from whitelist"""
    try:
        data = request.json
        token = data.get('token')

        if not token:
            return jsonify({'error': 'token is required'}), 400

        success = whitelist_manager.remove_profile(token)

        if success:
            return jsonify({'success': True, 'message': 'Profile removed from whitelist'})
        else:
            return jsonify({'error': 'Token not found'}), 404
    except Exception as e:
        logger.error(f"Error removing from whitelist: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/whitelist/list', methods=['GET'])
def list_whitelist():
    """List all whitelisted profiles"""
    try:
        return jsonify({
            'success': True,
            'profiles': whitelist_manager.get_all()
        })
    except Exception as e:
        logger.error(f"Error listing whitelist: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/validate/<token>', methods=['GET'])
def validate_token(token):
    """Validate if a token is whitelisted"""
    try:
        is_valid = whitelist_manager.is_whitelisted(token)
        return jsonify({
            'valid': is_valid
        })
    except Exception as e:
        logger.error(f"Error validating token: {e}")
        return jsonify({'error': str(e)}), 500

def run_api_server():
    """Run the Flask API server"""
    logger.info(f"Starting API server on port {API_PORT}")
    app.run(host='127.0.0.1', port=API_PORT, debug=False)

def handle_proxy_client(client_socket, client_address):
    """Handle a proxy client connection"""
    try:
        # Receive the request
        request_data = client_socket.recv(4096)
        if not request_data:
            client_socket.close()
            return

        # Parse the request to extract the token
        request_str = request_data.decode('utf-8', errors='ignore')
        lines = request_str.split('\n')

        # Look for X-YT-Blocker-Token header
        token = None
        for line in lines:
            if line.startswith('X-YT-Blocker-Token:'):
                token = line.split(':', 1)[1].strip()
                break

        # Validate token
        if not token or not whitelist_manager.is_whitelisted(token):
            # Send 403 Forbidden
            response = "HTTP/1.1 403 Forbidden\r\n"
            response += "Content-Type: text/plain\r\n"
            response += "\r\n"
            response += "YouTube access denied. Profile not whitelisted.\r\n"
            client_socket.sendall(response.encode())
            client_socket.close()
            return

        # Extract target host and port
        first_line = lines[0]
        if first_line.startswith('CONNECT'):
            # HTTPS CONNECT method
            parts = first_line.split()
            if len(parts) >= 2:
                host_port = parts[1]
                if ':' in host_port:
                    host, port = host_port.rsplit(':', 1)
                    port = int(port)
                else:
                    host = host_port
                    port = 443

                # Connect to the target server
                try:
                    target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    target_socket.connect((host, port))

                    # Send connection established response
                    response = "HTTP/1.1 200 Connection Established\r\n\r\n"
                    client_socket.sendall(response.encode())

                    # Forward data between client and target
                    def forward(src, dst):
                        try:
                            while True:
                                data = src.recv(4096)
                                if not data:
                                    break
                                dst.sendall(data)
                        except:
                            pass
                        finally:
                            src.close()
                            dst.close()

                    # Start forwarding threads
                    t1 = threading.Thread(target=forward, args=(client_socket, target_socket))
                    t2 = threading.Thread(target=forward, args=(target_socket, client_socket))
                    t1.start()
                    t2.start()
                    t1.join()
                    t2.join()
                except Exception as e:
                    logger.error(f"Error connecting to target: {e}")
                    client_socket.close()
        else:
            # Regular HTTP request - forward it
            # Parse target from request
            for line in lines:
                if line.startswith('Host:'):
                    host = line.split(':', 1)[1].strip()
                    break
            else:
                client_socket.close()
                return

            try:
                # Connect to target server
                target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                target_socket.connect((host, 80))
                target_socket.sendall(request_data)

                # Forward response
                while True:
                    data = target_socket.recv(4096)
                    if not data:
                        break
                    client_socket.sendall(data)

                target_socket.close()
                client_socket.close()
            except Exception as e:
                logger.error(f"Error forwarding HTTP request: {e}")
                client_socket.close()
    except Exception as e:
        logger.error(f"Error handling proxy client: {e}")
        try:
            client_socket.close()
        except:
            pass

def run_proxy_server():
    """Run the proxy server"""
    logger.info(f"Starting proxy server on port {PROXY_PORT}")

    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind(('127.0.0.1', PROXY_PORT))
    server_socket.listen(5)

    logger.info(f"Proxy server listening on 127.0.0.1:{PROXY_PORT}")

    while True:
        try:
            client_socket, client_address = server_socket.accept()
            # Handle each client in a separate thread
            client_thread = threading.Thread(
                target=handle_proxy_client,
                args=(client_socket, client_address)
            )
            client_thread.daemon = True
            client_thread.start()
        except Exception as e:
            logger.error(f"Error accepting proxy connection: {e}")

def main():
    """Main entry point"""
    logger.info("YouTube Blocker Service starting...")

    # Block YouTube in hosts file
    hosts_manager.block_youtube()

    # Start proxy server in a separate thread
    proxy_thread = threading.Thread(target=run_proxy_server)
    proxy_thread.daemon = True
    proxy_thread.start()

    # Start API server (blocking)
    run_api_server()

if __name__ == '__main__':
    main()
