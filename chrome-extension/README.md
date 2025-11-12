# YouTube Blocker - Chrome Extension

Chrome extension để quản lý whitelist và cho phép các Chrome profile cụ thể truy cập YouTube.

## Build Extension

Chạy script build để tạo extension:

```bash
cd ..
./build-extension.sh
```

Script sẽ:
- Cài đặt dependencies (python3-pil)
- Generate icons
- Package extension vào thư mục `build/`
- Tạo file zip để publish

## Cài đặt Extension

### Phương pháp 1: Load Unpacked (Development)

1. Build extension trước:
   ```bash
   ./build-extension.sh
   ```

2. Mở Chrome và truy cập `chrome://extensions/`

3. Bật **Developer mode** (góc trên bên phải)

4. Click **Load unpacked**

5. Chọn thư mục `build/youtube-blocker-extension/`

### Phương pháp 2: Chrome Web Store (Production)

1. Build extension:
   ```bash
   ./build-extension.sh
   ```

2. Upload file `build/youtube-blocker-extension.zip` lên Chrome Web Store

3. Follow Chrome Web Store publishing guidelines

## Cấu trúc Files

```
chrome-extension/
├── manifest.json           # Extension manifest (v3)
├── background.js          # Service worker
├── popup.html             # Extension popup UI
├── popup.js              # Popup logic
├── generate_icons.py     # Script tạo icons
├── icons/                # Extension icons (generated)
│   ├── icon16.png
│   ├── icon48.png
│   └── icon128.png
└── README.md             # File này
```

## Sử dụng

1. **Enable YouTube Access**:
   - Click icon extension
   - Click "✅ Enable YouTube Access"
   - Profile hiện tại sẽ được whitelist

2. **Disable YouTube Access**:
   - Click icon extension
   - Click "🚫 Disable YouTube Access"
   - Profile sẽ bị xóa khỏi whitelist

3. **Check Status**:
   - Click icon extension để xem trạng thái hiện tại

## Yêu cầu

- Backend service phải đang chạy (cài qua `install.sh`)
- Chrome/Chromium browser
- Extension chỉ hoạt động trên localhost (127.0.0.1)

## API Endpoints

Extension giao tiếp với backend qua:

- `http://127.0.0.1:9876/api/health` - Health check
- `http://127.0.0.1:9876/api/whitelist/add` - Thêm profile
- `http://127.0.0.1:9876/api/whitelist/remove` - Xóa profile
- `http://127.0.0.1:9876/api/validate/<token>` - Validate token

## Permissions

Extension yêu cầu các permissions:

- `storage` - Lưu token và settings
- `proxy` - Cấu hình proxy cho whitelisted profiles
- `webRequest` - Thêm authentication headers

## Troubleshooting

### Extension không kết nối được backend

```bash
# Kiểm tra backend đang chạy
sudo systemctl status youtube-blocker

# Kiểm tra API
curl http://127.0.0.1:9876/api/health
```

### Proxy không hoạt động

1. Kiểm tra proxy settings:
   - Chrome Settings → System → Open proxy settings

2. Clear và reconfigure:
   - Click "Disable YouTube Access"
   - Đợi 2 giây
   - Click "Enable YouTube Access"

### Icons không hiển thị

```bash
# Generate lại icons
python3 generate_icons.py

# Hoặc chạy build script
cd ..
./build-extension.sh
```

## Development

### Modify và test

1. Sửa code trong `chrome-extension/`
2. Vào `chrome://extensions/`
3. Click reload icon trên extension
4. Test thay đổi

### Debug

1. Mở `chrome://extensions/`
2. Click "Errors" để xem lỗi
3. Click "Inspect views: service worker" để debug background.js
4. Right-click extension icon → Inspect popup để debug popup

## License

MIT License - Xem file LICENSE ở root directory
