# 🛡️ YouTube Blocker for Ubuntu

Một ứng dụng chặn YouTube hoàn toàn trên Ubuntu, chỉ cho phép các Chrome profile được whitelist truy cập.

## ⚡ Cài đặt nhanh (Quick Install)

**Một lệnh duy nhất:**

```bash
curl -sSL https://raw.githubusercontent.com/kenzouno1/Block-YT/main/quick-install.sh | sudo bash
```

Script này sẽ tự động:
- ✅ Clone repository
- ✅ Cài đặt dependencies
- ✅ Setup /etc/hosts blocking
- ✅ Khởi động backend service
- ✅ Dọn dẹp tự động

**Sau khi cài đặt:**
1. Mở Chrome: `chrome://extensions/`
2. Bật "Developer mode"
3. Click "Load unpacked"
4. Chọn folder: `Block-YT/build/youtube-blocker-extension/`

Hoặc download extension:
```bash
# Clone repo để lấy extension
git clone https://github.com/kenzouno1/Block-YT.git
cd Block-YT
# Load extension từ: build/youtube-blocker-extension/
```

## ⚡ Gỡ cài đặt nhanh (Quick Uninstall)

**Một lệnh duy nhất:**

```bash
curl -sSL https://raw.githubusercontent.com/kenzouno1/Block-YT/main/quick-uninstall.sh | sudo bash
```

Script này sẽ tự động:
- ✅ Download repository
- ✅ Dừng và xóa backend service
- ✅ Xóa /etc/hosts blocking
- ✅ Xóa installation files
- ✅ Dọn dẹp tự động

**Lưu ý**: Bạn vẫn cần tự xóa Chrome extension thủ công:
1. Mở Chrome: `chrome://extensions/`
2. Tìm "YouTube Blocker Whitelist"
3. Click "Remove"

## ✨ Tính năng

- ✅ **Tự động khởi động**: Ứng dụng tự động start cùng với hệ điều hành Ubuntu
- 🚫 **Chặn mặc định**: Mặc định chặn hoàn toàn truy cập vào YouTube trên toàn hệ thống
- 🔐 **Whitelist theo Chrome profile**: Chỉ các Chrome profile được thêm vào whitelist mới có thể truy cập YouTube
- 🔌 **Chrome Extension**: Extension Chrome để dễ dàng quản lý whitelist
- 🔒 **Bảo mật**: Sử dụng token để xác thực, mỗi profile có token riêng

## 📋 Yêu cầu hệ thống

- Ubuntu 18.04 trở lên (hoặc các distro Linux tương tự)
- Python 3.6+
- Google Chrome hoặc Chromium
- Quyền root/sudo để cài đặt

**Lưu ý cho Ubuntu 22.04+**: Script cài đặt sử dụng `apt` để cài packages (tuân thủ PEP 668), không dùng `pip` trực tiếp vào system Python.

## 🏗️ Kiến trúc hệ thống

```
┌─────────────────────────────────────────────────────────────┐
│                      Ubuntu System                          │
│                                                             │
│  ┌──────────────────┐          ┌───────────────────────┐   │
│  │   /etc/hosts     │          │  Systemd Service      │   │
│  │                  │          │  (Auto-start)         │   │
│  │  127.0.0.1       │◄─────────┤                       │   │
│  │  youtube.com     │          │  - API Server:9876    │   │
│  │  *.youtube.com   │          │  - Proxy Server:8888  │   │
│  └──────────────────┘          │  - Whitelist Manager  │   │
│                                └───────────┬───────────┘   │
│                                            │               │
│  ┌─────────────────────────────────────────┼─────────────┐ │
│  │           Chrome Browser                │             │ │
│  │                                         │             │ │
│  │  ┌──────────────────┐                   │             │ │
│  │  │ Chrome Extension │◄──────────────────┘             │ │
│  │  │                  │                                 │ │
│  │  │ - Detect Profile │                                 │ │
│  │  │ - Request Token  │                                 │ │
│  │  │ - Config Proxy   │                                 │ │
│  │  └──────────────────┘                                 │ │
│  │                                                        │ │
│  │  Profile 1 (Blocked) │ Profile 2 (Whitelisted) ✅     │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Cách hoạt động:

1. **Chặn mặc định**: Service thêm các domain YouTube vào `/etc/hosts` trỏ về `127.0.0.1`, chặn toàn bộ truy cập
2. **Proxy Server**: Chạy local proxy server trên port 8888, cho phép truy cập YouTube nhưng yêu cầu token hợp lệ
3. **Chrome Extension**:
   - Phát hiện Chrome profile đang dùng
   - Gửi request đến API server để đăng ký whitelist
   - Nhận token xác thực
   - Cấu hình proxy cho profile này sử dụng proxy server local
4. **Xác thực**: Mỗi request qua proxy được kiểm tra token, chỉ cho phép nếu profile nằm trong whitelist

## 🚀 Cài đặt

### 1. Clone repository

```bash
git clone https://github.com/kenzouno1/Block-YT.git
cd Block-YT
```

### 2. Cài đặt Backend Service

```bash
sudo ./install.sh
```

Script sẽ tự động:
- Cài đặt các dependencies (Python packages)
- Tạo systemd service
- Enable service để tự động start cùng OS
- Khởi động service
- Chặn YouTube trong `/etc/hosts`

### 3. Build và Cài đặt Chrome Extension

Extension được build riêng biệt:

```bash
./build-extension.sh
```

Sau khi build xong, cài đặt extension:

1. Mở Chrome và truy cập `chrome://extensions/`
2. Bật **Developer mode** (góc trên bên phải)
3. Click **Load unpacked**
4. Chọn thư mục `build/youtube-blocker-extension/`
5. Extension sẽ xuất hiện trên thanh công cụ Chrome

Xem thêm hướng dẫn chi tiết tại [chrome-extension/README.md](chrome-extension/README.md)

## 📱 Sử dụng

### Kích hoạt YouTube cho Chrome profile hiện tại

1. Click vào icon **YouTube Blocker** trên thanh công cụ Chrome
2. Click nút **"✅ Enable YouTube Access"**
3. Extension sẽ:
   - Đăng ký profile với backend service
   - Nhận token xác thực
   - Cấu hình proxy tự động
4. Giờ bạn có thể truy cập YouTube từ profile này!

### Vô hiệu hóa YouTube cho profile hiện tại

1. Click vào icon **YouTube Blocker**
2. Click nút **"🚫 Disable YouTube Access"**
3. Profile sẽ bị xóa khỏi whitelist và không thể truy cập YouTube

### Kiểm tra trạng thái

- Click vào icon extension để xem trạng thái hiện tại
- Màu xanh (✅): Profile được phép truy cập YouTube
- Màu đỏ (🚫): Profile bị chặn

## 🔧 Quản lý Service

### Kiểm tra trạng thái service

```bash
sudo systemctl status youtube-blocker
```

### Xem logs

```bash
# Real-time logs
sudo journalctl -u youtube-blocker -f

# Last 50 lines
sudo journalctl -u youtube-blocker -n 50

# Log file
sudo tail -f /var/log/youtube-blocker.log
```

### Khởi động lại service

```bash
sudo systemctl restart youtube-blocker
```

### Dừng service

```bash
sudo systemctl stop youtube-blocker
```

### Vô hiệu hóa auto-start

```bash
sudo systemctl disable youtube-blocker
```

## 📂 Cấu trúc thư mục

```
Block-YT/
├── backend/
│   ├── youtube_blocker.py        # Backend service chính
│   ├── youtube-blocker.service   # Systemd service file
│   └── requirements.txt          # Python dependencies
├── chrome-extension/
│   ├── manifest.json            # Extension manifest
│   ├── background.js            # Background service worker
│   ├── popup.html               # Extension popup UI
│   ├── popup.js                 # Popup logic
│   ├── generate_icons.py        # Script tạo icons
│   └── icons/                   # Extension icons
├── install.sh                   # Script cài đặt
├── uninstall.sh                 # Script gỡ cài đặt
└── README.md                    # File này
```

## 🗂️ Files và Cấu hình

### Service files

- **Binary**: `/opt/youtube-blocker/youtube_blocker.py`
- **Systemd**: `/etc/systemd/system/youtube-blocker.service`
- **Logs**: `/var/log/youtube-blocker.log`
- **Whitelist**: `/var/lib/youtube-blocker/whitelist.json`

### API Endpoints

Service chạy trên `http://127.0.0.1:9876`:

- `GET /api/health` - Health check
- `POST /api/whitelist/add` - Thêm profile vào whitelist
- `POST /api/whitelist/remove` - Xóa profile khỏi whitelist
- `GET /api/whitelist/list` - Liệt kê các profile đã whitelist
- `GET /api/validate/<token>` - Kiểm tra token có hợp lệ không

### Proxy Server

- **Port**: `8888`
- **Host**: `127.0.0.1`
- **Chức năng**: Cho phép truy cập YouTube với token hợp lệ

## 🔍 Troubleshooting

### Service không start

```bash
# Kiểm tra logs
sudo journalctl -u youtube-blocker -n 100

# Kiểm tra Python dependencies (Ubuntu 22.04+)
sudo apt-get install python3-flask python3-flask-cors python3-requests

# Hoặc cho Ubuntu cũ hơn (nếu apt packages không có)
# pip3 install flask flask-cors requests --break-system-packages

# Thử start thủ công
sudo python3 /opt/youtube-blocker/youtube_blocker.py
```

### Extension không kết nối được

1. Kiểm tra service đang chạy:
   ```bash
   sudo systemctl status youtube-blocker
   ```

2. Kiểm tra port đang mở:
   ```bash
   sudo netstat -tlnp | grep 9876
   ```

3. Kiểm tra logs của extension:
   - Mở `chrome://extensions/`
   - Click "Errors" trên extension
   - Xem console logs

### YouTube vẫn bị chặn sau khi whitelist

1. Kiểm tra proxy đã được cấu hình:
   - Mở `chrome://settings/system`
   - Xem phần "Open your computer's proxy settings"

2. Kiểm tra token trong extension:
   - Mở extension popup
   - Mở Developer Tools (F12)
   - Chạy: `chrome.storage.local.get(['whitelistToken'], console.log)`

3. Thử disable và enable lại:
   - Click "Disable YouTube Access"
   - Đợi 2 giây
   - Click "Enable YouTube Access"

### Reset hoàn toàn

```bash
# Gỡ cài đặt
sudo ./uninstall.sh

# Xóa dữ liệu cũ
sudo rm -rf /var/lib/youtube-blocker

# Cài đặt lại
sudo ./install.sh
```

## 🗑️ Gỡ cài đặt

### Cách 1: Quick Uninstall (Khuyến nghị)

Gỡ cài đặt nhanh chóng với một lệnh duy nhất:

```bash
curl -sSL https://raw.githubusercontent.com/kenzouno1/Block-YT/main/quick-uninstall.sh | sudo bash
```

### Cách 2: Manual Uninstall

Nếu bạn đã clone repository:

```bash
sudo ./uninstall.sh
```

Script sẽ:
- Dừng và disable service
- Xóa service files
- Xóa YouTube entries khỏi `/etc/hosts`
- Hỏi có muốn xóa whitelist data không

**Lưu ý**: Bạn cần tự xóa Chrome extension:
1. Vào `chrome://extensions/`
2. Tìm "YouTube Blocker Whitelist"
3. Click "Remove"

## 🔐 Bảo mật

- Service chạy với quyền root (cần thiết để sửa `/etc/hosts`)
- API server chỉ lắng nghe trên `127.0.0.1` (localhost only)
- Mỗi profile có token riêng, được sinh ngẫu nhiên
- Token được lưu trong Chrome storage, không gửi qua network
- Proxy chỉ chấp nhận kết nối từ localhost

## ⚙️ Tùy chỉnh

### Thay đổi ports

Edit file `/opt/youtube-blocker/youtube_blocker.py`:

```python
API_PORT = 9876    # Port cho API server
PROXY_PORT = 8888  # Port cho Proxy server
```

Sau đó restart service:
```bash
sudo systemctl restart youtube-blocker
```

### Thêm/bớt YouTube domains

Edit file `/opt/youtube-blocker/youtube_blocker.py`:

```python
YOUTUBE_DOMAINS = [
    'www.youtube.com',
    'youtube.com',
    'youtu.be',
    'm.youtube.com',
    # Thêm domains khác tại đây
]
```

## 🤝 Đóng góp

Contributions, issues và feature requests đều được chào đón!

## 📝 License

MIT License - Xem file LICENSE để biết thêm chi tiết

## 👨‍💻 Tác giả

**kenzouno1**

## 🙏 Credits

- Sử dụng Flask cho API server
- Chrome Extension Manifest V3
- Python proxy server implementation

---

**Lưu ý**: Ứng dụng này được thiết kế cho mục đích kiểm soát truy cập YouTube trong môi trường gia đình hoặc giáo dục. Sử dụng có trách nhiệm!
