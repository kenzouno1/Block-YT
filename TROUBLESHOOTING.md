# Troubleshooting - YouTube Blocker

## YouTube vẫn truy cập được sau khi block

### Nguyên nhân phổ biến

#### 1. Browser DNS Cache

Browser có thể cache DNS records. **Giải pháp:**

- **Chrome/Chromium:**
  ```
  1. Vào chrome://net-internals/#dns
  2. Click "Clear host cache"
  3. Restart browser
  ```

- **Firefox:**
  ```
  1. Vào about:networking#dns
  2. Click "Clear DNS Cache"
  3. Restart browser
  ```

- **Hoặc đơn giản:** Restart browser hoàn toàn

#### 2. DNS over HTTPS (DoH)

Chrome và Firefox mặc định bật DoH, bypass /etc/hosts file.

**Disable DoH trong Chrome:**
```
1. Vào chrome://settings/security
2. Scroll xuống "Advanced" → "Use secure DNS"
3. Tắt "Use secure DNS"
4. Restart browser
```

**Disable DoH trong Firefox:**
```
1. Vào about:preferences#general
2. Scroll xuống "Network Settings"
3. Click "Settings"
4. Bỏ check "Enable DNS over HTTPS"
5. Click OK và restart browser
```

#### 3. Browser sử dụng proxy khác

Kiểm tra Chrome không dùng proxy khác:
```
1. chrome://settings/system
2. "Open your computer's proxy settings"
3. Đảm bảo không có proxy nào được cấu hình
```

#### 4. HTTPS Cache

Browser có thể cache trang YouTube. **Giải pháp:**

```
Ctrl + Shift + Delete (hoặc Cmd + Shift + Delete trên Mac)
→ Clear cache và cookies
→ Restart browser
```

#### 5. Service worker cache

YouTube sử dụng service workers. **Giải pháp:**

```
Chrome:
1. F12 (Developer Tools)
2. Application tab
3. Service Workers
4. Unregister tất cả service workers
5. Reload page
```

### Kiểm tra nhanh

#### Test 1: Kiểm tra hosts file

```bash
sudo grep -A 10 "YouTube Blocker" /etc/hosts
```

Phải thấy:
```
# YouTube Blocker - START
127.0.0.1 www.youtube.com
127.0.0.1 youtube.com
...
```

#### Test 2: Kiểm tra DNS resolution

```bash
getent hosts youtube.com
```

Phải trả về: `127.0.0.1       youtube.com`

Nếu không phải `127.0.0.1`, chạy:
```bash
sudo ./test-blocking.sh block
```

#### Test 3: Test bằng curl

```bash
curl -I youtube.com
```

Phải lỗi kết nối hoặc connection refused.

### Service không chạy (Môi trường không có systemd)

Nếu bạn ở trong container hoặc môi trường không có systemd:

```bash
# Block YouTube thủ công
sudo ./test-blocking.sh block

# Kiểm tra status
sudo ./test-blocking.sh status

# Unblock (nếu cần test)
sudo ./test-blocking.sh unblock
```

### Flush DNS cache hệ thống

#### Ubuntu/Debian với systemd-resolved:
```bash
sudo systemd-resolve --flush-caches
# hoặc
sudo resolvectl flush-caches
```

#### Ubuntu/Debian với nscd:
```bash
sudo /etc/init.d/nscd restart
```

#### macOS:
```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Test trong Incognito/Private Mode

Test trong chế độ ẩn danh để tránh cache:

```
Chrome: Ctrl + Shift + N
Firefox: Ctrl + Shift + P
```

### Kiểm tra network tools

Một số extension hoặc tools có thể bypass hosts:

- VPN extensions
- Proxy extensions
- DNS changer extensions
- Anti-censorship tools

Disable tất cả extensions và test lại.

## Backend service không start

### Lỗi: No systemd

```bash
# Chạy backend thủ công
sudo python3 backend/youtube_blocker.py
```

### Lỗi: Port already in use

```bash
# Tìm process đang dùng port 9876
sudo lsof -i :9876
sudo lsof -i :8888

# Kill process
sudo kill -9 <PID>
```

### Lỗi: Permission denied

```bash
# Đảm bảo chạy với sudo
sudo python3 backend/youtube_blocker.py
```

## Extension không kết nối

### Lỗi: Cannot connect to backend

1. Kiểm tra backend đang chạy:
   ```bash
   curl http://127.0.0.1:9876/api/health
   ```

2. Nếu không chạy:
   ```bash
   # Với systemd
   sudo systemctl start youtube-blocker

   # Không có systemd
   sudo python3 backend/youtube_blocker.py
   ```

3. Kiểm tra firewall:
   ```bash
   sudo ufw allow 9876/tcp
   sudo ufw allow 8888/tcp
   ```

### Extension error: "Profile not whitelisted"

1. Click extension icon
2. Click "Enable YouTube Access"
3. Đợi 2-3 giây
4. Refresh trang YouTube

## Vấn đề khác

### YouTube chậm sau khi whitelist

Proxy có thể làm chậm. Giải pháp:

1. Disable proxy khi không cần:
   - Click extension → "Disable YouTube Access"

2. Hoặc whitelist permanent trong code

### Một số video vẫn bị block

YouTube có nhiều CDN domains. Thêm vào `backend/youtube_blocker.py`:

```python
YOUTUBE_DOMAINS = [
    'www.youtube.com',
    'youtube.com',
    'youtu.be',
    'm.youtube.com',
    'youtube-ui.l.google.com',
    'youtubei.googleapis.com',
    'i.ytimg.com',           # Thêm
    'yt3.ggpht.com',         # Thêm
    's.ytimg.com',           # Thêm
]
```

## Cần thêm trợ giúp?

1. Kiểm tra logs:
   ```bash
   sudo journalctl -u youtube-blocker -n 100
   # hoặc
   sudo tail -f /var/log/youtube-blocker.log
   ```

2. Chạy debug mode:
   ```bash
   sudo python3 backend/youtube_blocker.py
   ```

3. Tạo issue trên GitHub với:
   - Output của `sudo ./test-blocking.sh status`
   - Browser version
   - OS version
   - Error messages
