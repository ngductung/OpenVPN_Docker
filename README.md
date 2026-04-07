# 🐳 OpenVPN to Burp Suite Transparent Proxy (Docker)

Dự án này cung cấp một Docker container chạy OpenVPN server. Nó tự động cấu hình `iptables` để chuyển tiếp toàn bộ luồng traffic web (cổng 80 và 443) từ VPN client sang máy chủ đang chạy Burp Suite thông qua cơ chế Transparent Proxy (DNAT).

Rất hữu ích khi bạn cần bắt request từ điện thoại (iOS/Android) hoặc máy ảo mà không thể cấu hình HTTP Proxy thủ công trên thiết bị, hoặc ứng dụng có cơ chế chặn proxy thông thường.

## ✨ Tính năng chính
- Tự động tạo và quản lý chứng chỉ (PKI/Certificates) bằng Easy-RSA.
- Tự động sinh file cấu hình `client.ovpn` và xuất ra máy Host.
- Tự động áp dụng rule `iptables` để forward traffic TCP 80/443 sang Burp Suite.
- Giữ lại cấu hình an toàn (Persistent Data): Không mất chứng chỉ và key khi xóa/tạo lại container.

## 🛠 Yêu cầu hệ thống
- Máy tính đã cài đặt **Docker** (Docker Desktop trên Windows/Mac hoặc Docker Engine trên Linux).
- **Burp Suite** đang chạy trên máy Host.

---

## 🚀 Hướng dẫn sử dụng

### Bước 1: Khởi chạy Server (Chọn 1 trong 2 cách)

Bạn cần cập nhật biến `PROXY_IP` thành IP mạng LAN thực tế của máy bạn (máy đang chạy Burp Suite, ví dụ: `192.168.100.1`).

#### Cách 1: Sử dụng Docker Compose (Khuyên dùng)
Sử dụng `docker-compose` giúp bạn không cần gõ lệnh dài dòng và tự động xử lý vấn đề tương thích đường dẫn giữa các hệ điều hành.

1. Mở file `docker-compose.yml` bằng trình soạn thảo văn bản.
2. Sửa giá trị `PROXY_IP=192.168.100.1` thành IP máy bạn.
3. Mở Terminal / Command Prompt / PowerShell tại thư mục này và chạy lệnh:
```bash
docker compose up -d
````

*(Lệnh này sẽ tự động build image và chạy container. Để dừng và xóa container, dùng lệnh `docker compose down`)*

#### Cách 2: Sử dụng Docker CLI truyền thống

Nếu bạn không muốn dùng Docker Compose, bạn có thể tự build và chạy bằng các lệnh sau:

**1. Build Docker Image:**

```cmd
docker build -t openvpn-burp .
```

**2. Chạy Container (chọn lệnh đúng với Shell của bạn):**

**Lưu ý quan trọng trước khi chạy:**
1. Cập nhật `PROXY_IP`: Thay `192.168.100.1` bằng IP mạng LAN thực tế của máy bạn (máy đang chạy Burp Suite).
2. Đường dẫn thư mục (Volumes): Bạn có thể dùng biến thư mục hiện tại (PWD) để khỏi hardcode đường dẫn tuyệt đối.

**PowerShell (Windows):**
```powershell
docker run -d --name vpn-burp --cap-add=NET_ADMIN --sysctl net.ipv4.ip_forward=1 --device=/dev/net/tun -p 1194:1194/udp -e PROXY_IP="192.168.100.1" -v "${PWD}\openvpn_data:/etc/openvpn" -v "${PWD}\output_config:/client_config" openvpn-burp
```

**Git Bash / WSL / Linux shell:**
```bash
docker run -d --name vpn-burp --cap-add=NET_ADMIN --sysctl net.ipv4.ip_forward=1 --device=/dev/net/tun -p 1194:1194/udp -e PROXY_IP="192.168.100.1" -v "$(pwd)/openvpn_data:/etc/openvpn" -v "$(pwd)/output_config:/client_config" openvpn-burp
```

**Nếu dùng CMD thuần (không phải PowerShell):**
```cmd
docker run -d --name vpn-burp --cap-add=NET_ADMIN --sysctl net.ipv4.ip_forward=1 --device=/dev/net/tun -p 1194:1194/udp -e PROXY_IP="192.168.100.1" -v "%cd%\openvpn_data:/etc/openvpn" -v "%cd%\output_config:/client_config" openvpn-burp
```

**Giải thích các cờ:**
- `--cap-add=NET_ADMIN`: Cấp quyền để cấu hình iptables.
- `--sysctl net.ipv4.ip_forward=1`: Bật tính năng định tuyến (routing) bên trong container.
- `--device=/dev/net/tun`: Map card mạng ảo TUN từ host vào container (bắt buộc để OpenVPN hoạt động).
- `-v .../openvpn_data:/etc/openvpn`: Lưu trữ dữ liệu chứng chỉ/server để không bị mất khi xóa container.
- `-v .../output_config:/client_config`: Thư mục để container xuất file `client.ovpn` ra ngoài cho bạn sử dụng.

### Bước 2: Bật Invisible Proxy trên Burp Suite (RẤT QUAN TRỌNG)
Vì chúng ta đang dùng iptables để ép luồng traffic ở tầng mạng (DNAT), Burp Suite cần được bật tính năng Invisible Proxy để biết cách xử lý các request này.

1. Mở **Burp Suite** > Bấm vào biểu tượng bánh răng **Settings** ở góc phải (hoặc nhấn `Ctrl + Shift + S`).
2. Điều hướng đến **Tools** > **Proxy**.
3. Trong mục *Proxy listeners*, đảm bảo bạn có một listener đang chạy ở cổng `8080` và IP được bind là IP mạng LAN (ví dụ `192.168.100.1`) hoặc `All interfaces`. Chọn listener đó và bấm **Edit**.
4. Chuyển sang tab **Request handling**.
5. Tick vào ô **Support invisible proxying (enable only if needed)**.
6. Bấm **OK** để lưu cấu hình. Cột *Invisible* của listener lúc này sẽ hiện dấu tick xanh.

### Bước 3: Kết nối Client
1. Mở thư mục `output_config` trên máy tính của bạn.
2. Lấy file **`client.ovpn`** bên trong.
3. Chuyển file này sang thiết bị Client (Điện thoại thật, máy ảo Android, v.v.) và import vào app OpenVPN Connect.
4. Bấm kết nối. Toàn bộ traffic web của thiết bị sẽ bay thẳng vào Burp Suite của bạn!
*(Lưu ý: Để bắt được traffic HTTPS, thiết bị client phải được cài đặt chứng chỉ PortSwigger CA từ Burp Suite vào mục Trusted Credentials)*

---

## 🧰 Xử lý sự cố (Troubleshooting)

- **Lỗi `Cannot open TUN/TAP dev /dev/net/tun` khi xem log:** Đảm bảo bạn đã thêm cờ `--device=/dev/net/tun` khi chạy lệnh `docker run`.
- **Lỗi `includes invalid characters for a local volume name` trên Windows:** Thường do dùng sai biến theo shell. `$(pwd)` dùng cho Bash/WSL, `${PWD}` dùng cho PowerShell, còn CMD thì dùng đường dẫn tuyệt đối `C:\...`.
- **Client đã báo connected nhưng không có mạng / Burp không bắt được request:**
  Kiểm tra lại xem IP điền trong `PROXY_IP` có đúng là IP mạng LAN hiện tại của máy host hay không. Nếu IP bị sai, bạn cần xóa container (`docker rm -f vpn-burp`), xóa file `client.ovpn` cũ, sửa lại IP trong lệnh `docker run` và chạy lại.
