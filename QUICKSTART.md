# 🚀 Hướng dẫn nhanh - Quick Start

## Cài đặt trong 3 bước

### Bước 1: Cài đặt Backend Service

```bash
# Clone repository
git clone https://github.com/kenzouno1/Block-YT.git
cd Block-YT

# Chạy script cài đặt (cần quyền sudo)
sudo ./install.sh
```

Đợi cho đến khi thấy thông báo "Installation Complete! 🎉"

### Bước 2: Cài đặt Chrome Extension

1. Mở Chrome browser
2. Vào `chrome://extensions/`
3. Bật **"Developer mode"** (góc trên bên phải)
4. Click **"Load unpacked"**
5. Chọn thư mục `chrome-extension` trong thư mục Block-YT

### Bước 3: Kích hoạt YouTube cho Chrome Profile

1. Click vào icon **YouTube Blocker** 🛡️ trên thanh Chrome
2. Click nút **"✅ Enable YouTube Access"**
3. Đợi vài giây để thấy trạng thái chuyển sang "YouTube Access Enabled"
4. Vào YouTube và enjoy! 🎉

---

## Kiểm tra nhanh

### Service đang chạy?

```bash
sudo systemctl status youtube-blocker
```

Phải thấy: `Active: active (running)`

### Xem logs

```bash
sudo journalctl -u youtube-blocker -f
```

### Test API

```bash
curl http://127.0.0.1:9876/api/health
```

Phải trả về: `{"status":"ok","service":"youtube-blocker"}`

---

## Các lệnh hay dùng

```bash
# Khởi động lại service
sudo systemctl restart youtube-blocker

# Xem logs
sudo tail -f /var/log/youtube-blocker.log

# Kiểm tra whitelist
sudo cat /var/lib/youtube-blocker/whitelist.json

# Kiểm tra hosts file
grep -A 10 "YouTube Blocker" /etc/hosts
```

---

## Lỗi thường gặp

### 1. Extension không kết nối được

**Giải pháp:**
```bash
# Kiểm tra service
sudo systemctl status youtube-blocker

# Nếu không chạy, start lại
sudo systemctl start youtube-blocker
```

### 2. YouTube vẫn bị chặn sau khi enable

**Giải pháp:**
1. Mở extension popup
2. Click "🚫 Disable YouTube Access"
3. Đợi 3 giây
4. Click "✅ Enable YouTube Access"
5. Refresh trang YouTube

### 3. Service không start được

**Giải pháp:**
```bash
# Cài đặt dependencies thủ công
sudo pip3 install flask flask-cors requests

# Restart service
sudo systemctl restart youtube-blocker
```

---

## Gỡ cài đặt

```bash
sudo ./uninstall.sh
```

Sau đó vào `chrome://extensions/` và xóa extension.

---

## Cần trợ giúp?

- Xem file **README.md** để biết chi tiết
- Kiểm tra **logs**: `sudo journalctl -u youtube-blocker -n 100`
- Tạo issue trên GitHub

---

**Chúc bạn sử dụng vui vẻ! 🎉**
