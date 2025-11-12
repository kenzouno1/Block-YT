# Firewall-Based YouTube Blocking

## Tổng quan

Approach này sử dụng **iptables firewall** để chặn YouTube system-wide, chỉ cho phép truy cập qua **local proxy server** với **token validation**.

## Tại sao cần Firewall thay vì Hosts file?

### Vấn đề với Hosts file (/etc/hosts)

❌ **Hosts file là system-wide**:
- Block → TẤT CẢ browsers bị chặn
- Unblock → TẤT CẢ browsers đều truy cập được
- **Không thể whitelist theo Chrome profile**

✅ **Firewall + Proxy approach**:
- Firewall block TẤT CẢ traffic to YouTube IPs
- Localhost (127.0.0.1) được phép (cho proxy)
- Proxy server validate token trước khi forward
- **Chỉ Chrome profiles có extension + valid token được truy cập**

## Kiến trúc

```
┌──────────────────────────────────────────────────────────────┐
│                     Ubuntu System                            │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │          iptables Firewall Rules                       │ │
│  │                                                        │ │
│  │  OUTPUT chain:                                         │ │
│  │  1. ACCEPT    -o lo (localhost traffic)               │ │
│  │  2. JUMP      → YOUTUBE_BLOCK chain                   │ │
│  │                                                        │ │
│  │  YOUTUBE_BLOCK chain:                                  │ │
│  │  - REJECT     172.217.0.0/16 (Google/YouTube)         │ │
│  │  - REJECT     142.250.0.0/15 (Google/YouTube)         │ │
│  │  - REJECT     ... (all YouTube IP ranges)             │ │
│  └────────────────────────────────────────────────────────┘ │
│                           ↓                                  │
│         All browsers BLOCKED    ↓ Localhost ALLOWED         │
│                                 ↓                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │    Proxy Server (127.0.0.1:8888)                      │ │
│  │                                                        │ │
│  │    1. Receive CONNECT request                         │ │
│  │    2. Extract X-YT-Blocker-Token header               │ │
│  │    3. Validate token in whitelist                     │ │
│  │    4. If valid → Forward to YouTube                   │ │
│  │    5. If invalid → Return 403 Forbidden               │ │
│  │                                                        │ │
│  │    Uses localhost → Bypasses firewall! ✅              │ │
│  └────────────────────────────────────────────────────────┘ │
│                           ↑                                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │    Chrome Browser with Extension                      │ │
│  │                                                        │ │
│  │    Extension auto-configures:                         │ │
│  │    - Proxy: http://127.0.0.1:8888                     │ │
│  │    - Adds header: X-YT-Blocker-Token: <token>         │ │
│  │                                                        │ │
│  │    Result: YouTube accessible! ✅                      │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Other browsers (Firefox, Edge, etc):                       │
│  → No proxy configured                                      │
│  → Direct connection to YouTube                             │
│  → Blocked by firewall ❌                                    │
└──────────────────────────────────────────────────────────────┘
```

## Cách hoạt động

### 1. Firewall Block YouTube IPs

```bash
# Firewall rules block YouTube IP ranges
iptables -A YOUTUBE_BLOCK -d 172.217.0.0/16 -j REJECT
iptables -A YOUTUBE_BLOCK -d 142.250.0.0/15 -j REJECT
# ... more ranges

# But ALLOW localhost traffic
iptables -I OUTPUT 1 -o lo -j ACCEPT

# All other traffic goes through YOUTUBE_BLOCK chain
iptables -I OUTPUT 2 ! -o lo -j YOUTUBE_BLOCK
```

**Kết quả:**
- ❌ Firefox truy cập youtube.com → **REJECTED**
- ❌ Edge truy cập youtube.com → **REJECTED**
- ❌ Chrome (no extension) → **REJECTED**
- ✅ Localhost traffic (proxy) → **ALLOWED**

### 2. Proxy Server với Token Validation

Proxy server chạy trên `127.0.0.1:8888`:

```python
def handle_proxy_client(client_socket):
    # 1. Parse request
    request = client_socket.recv(4096)

    # 2. Extract token from X-YT-Blocker-Token header
    token = extract_token(request)

    # 3. Validate token
    if not whitelist_manager.is_whitelisted(token):
        return send_403(client_socket)

    # 4. Forward to YouTube (uses localhost → bypasses firewall!)
    forward_to_youtube(request)
```

**Kết quả:**
- Request từ localhost → Firewall cho phép
- Proxy kiểm tra token → Chỉ valid tokens được forward
- Forward đến YouTube → Success!

### 3. Chrome Extension Auto-Configure Proxy

Extension tự động:

```javascript
// 1. Get token from backend
const response = await fetch('http://127.0.0.1:9876/api/whitelist/add', {
    method: 'POST',
    body: JSON.stringify({ profile_id, profile_name })
});
const { token } = await response.json();

// 2. Configure proxy
chrome.proxy.settings.set({
    value: {
        mode: "fixed_servers",
        rules: {
            singleProxy: {
                scheme: "http",
                host: "127.0.0.1",
                port: 8888
            }
        }
    }
});

// 3. Add token to all requests via declarativeNetRequest
chrome.declarativeNetRequest.updateDynamicRules({
    addRules: [{
        action: {
            type: 'modifyHeaders',
            requestHeaders: [{
                header: 'X-YT-Blocker-Token',
                value: token
            }]
        }
    }]
});
```

**Kết quả:**
- Chrome profile có extension → Proxy configured
- Mọi YouTube requests → Qua proxy với token
- Proxy validate token → Forward đến YouTube
- **YouTube accessible!** ✅

## Installation

### Bước 1: Setup Firewall

```bash
sudo ./setup-firewall.sh setup
```

Lệnh này sẽ:
- Resolve YouTube IPs
- Tạo iptables rules
- Block tất cả traffic đến YouTube
- Allow localhost (cho proxy)

### Bước 2: Start Backend Service

```bash
sudo ./start-backend.sh start
```

Service cung cấp:
- API server: `http://127.0.0.1:9876`
- Proxy server: `http://127.0.0.1:8888`

### Bước 3: Install Chrome Extension

```bash
cd build/youtube-blocker-extension/
# Load unpacked vào Chrome
```

Extension tự động:
- Gọi API để get token
- Configure proxy
- Add token header vào requests

### Bước 4: Test

```bash
# Test firewall blocking
sudo ./setup-firewall.sh test

# Expected:
# ❌ Direct YouTube access → BLOCKED
# ✅ Proxy access → WORKING
```

## Verify hoạt động

### Test 1: Direct connection (should fail)

```bash
curl https://www.youtube.com
# Expected: Connection timeout/rejected
```

### Test 2: Via proxy without token (should fail)

```bash
curl --proxy http://127.0.0.1:8888 https://www.youtube.com
# Expected: 403 Forbidden
```

### Test 3: Via proxy with token (should work)

```bash
TOKEN="your-token-here"
curl --proxy http://127.0.0.1:8888 \
     -H "X-YT-Blocker-Token: $TOKEN" \
     https://www.youtube.com
# Expected: YouTube homepage HTML
```

### Test 4: Chrome with extension

1. Cài extension
2. Vào `chrome://extensions/` → Check service worker console
3. Should see: "✅ Auto-enabled successfully!"
4. Mở `https://youtube.com` → Should load!

### Test 5: Other browsers

1. Mở Firefox/Edge
2. Vào `https://youtube.com`
3. Expected: **Connection failed** (blocked by firewall)

## Troubleshooting

### YouTube vẫn accessible từ Firefox/Edge

```bash
# Check firewall rules
sudo ./setup-firewall.sh status

# Should see: "YouTube blocking is ACTIVE"

# If not active:
sudo ./setup-firewall.sh setup
```

### Chrome with extension vẫn bị block

1. **Check backend running:**
   ```bash
   sudo ./start-backend.sh status
   ```

2. **Check proxy configuration:**
   - `chrome://settings/system`
   - Should see proxy: `127.0.0.1:8888`

3. **Check extension console:**
   - `chrome://extensions/`
   - Click "service worker"
   - Look for errors

4. **Check token:**
   ```bash
   # Get token from extension storage
   chrome.storage.local.get(['whitelistToken'], console.log)

   # Test token
   curl http://127.0.0.1:9876/api/validate/<token>
   # Should return: {"valid": true}
   ```

### Firewall not blocking

```bash
# Check if iptables rules exist
sudo iptables -L YOUTUBE_BLOCK -n

# If empty or not found:
sudo ./setup-firewall.sh setup

# Make persistent across reboots:
sudo apt-get install iptables-persistent
sudo netfilter-persistent save
```

## Persist Firewall Across Reboots

### Option 1: iptables-persistent

```bash
sudo apt-get install iptables-persistent
sudo netfilter-persistent save
```

### Option 2: rc.local

Add to `/etc/rc.local`:

```bash
#!/bin/bash
/path/to/Block-YT/setup-firewall.sh setup
exit 0
```

### Option 3: systemd service

Create `/etc/systemd/system/youtube-blocker-firewall.service`:

```ini
[Unit]
Description=YouTube Blocker Firewall Rules
After=network.target

[Service]
Type=oneshot
ExecStart=/path/to/Block-YT/setup-firewall.sh setup
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Enable:
```bash
sudo systemctl enable youtube-blocker-firewall
```

## Uninstall

```bash
# Remove firewall rules
sudo ./setup-firewall.sh remove

# Stop backend
sudo ./start-backend.sh stop

# Remove extension from Chrome
chrome://extensions/ → Remove
```

## Advantages

✅ **True per-profile whitelist**:
- Chỉ Chrome profiles có extension mới access được
- Firefox, Edge, other browsers: BLOCKED
- Chrome profiles khác (no extension): BLOCKED

✅ **System-wide blocking**:
- Không thể bypass bằng cách đổi DNS
- Không thể bypass bằng cách dùng browser khác
- Chỉ có thể bypass qua proxy với valid token

✅ **Secure**:
- Token-based authentication
- Proxy chỉ forward requests có valid token
- Mỗi profile có token riêng

## Disadvantages

⚠️ **Phức tạp hơn hosts file approach**:
- Cần setup firewall
- Cần maintain IP lists
- Proxy server thêm latency

⚠️ **YouTube IPs có thể thay đổi**:
- Cần update firewall rules định kỳ
- Script tự động resolve IPs, nhưng không realtime

⚠️ **Requires root**:
- Cần sudo để setup firewall
- Backend service cần run as root (để modify whitelist)

## So sánh Approaches

| Feature | Hosts File | Firewall + Proxy |
|---------|-----------|------------------|
| Block system-wide | ✅ | ✅ |
| Whitelist per-profile | ❌ | ✅ |
| Block other browsers | ❌ | ✅ |
| Setup complexity | Easy | Medium |
| Performance | Fast | Good (proxy overhead) |
| Maintenance | Low | Medium (IP updates) |
| Security | Basic | High (token-based) |

## Kết luận

Firewall + Proxy approach là giải pháp duy nhất để:
- Chặn YouTube **hoàn toàn** system-wide
- Whitelist **chỉ** Chrome profiles có extension
- Block **tất cả** browsers/apps khác

Trade-off: Phức tạp hơn hosts file, nhưng đạt được mục tiêu whitelist per-profile.
