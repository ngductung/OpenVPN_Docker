#!/bin/bash
set -e

# Kiểm tra xem IP đã được truyền vào chưa
if [ -z "$PROXY_IP" ]; then
    echo "LỖI: Bạn phải cấu hình biến môi trường PROXY_IP lúc run docker."
    exit 1
fi

OVPN_DIR="/etc/openvpn"
CLIENT_DIR="/client_config"

# Khởi tạo PKI và Certificates nếu chưa tồn tại
if [ ! -d "$OVPN_DIR/easy-rsa/pki" ]; then
    echo "[*] Đang khởi tạo Certificates và Keys..."
    cp -r /usr/share/easy-rsa $OVPN_DIR/easy-rsa
    cd $OVPN_DIR/easy-rsa
    
    export EASYRSA_BATCH=1 # Chạy không cần prompt hỏi xác nhận
    ./easyrsa init-pki
    ./easyrsa build-ca nopass
    ./easyrsa gen-dh
    ./easyrsa build-server-full server nopass
    ./easyrsa build-client-full client nopass
    openvpn --genkey secret ./pki/ta.key
fi

# Tạo file cấu hình cho Server OpenVPN
echo "[*] Đang tạo server.conf..."
cat > $OVPN_DIR/server.conf <<EOF
port 1194
proto udp
dev tun
ca $OVPN_DIR/easy-rsa/pki/ca.crt
cert $OVPN_DIR/easy-rsa/pki/issued/server.crt
key $OVPN_DIR/easy-rsa/pki/private/server.key
dh $OVPN_DIR/easy-rsa/pki/dh.pem
tls-auth $OVPN_DIR/easy-rsa/pki/ta.key 0
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-CBC
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

# Tự động tạo file client.ovpn lưu vào thư mục map với Host
echo "[*] Đang tạo file client.ovpn cho IP: $PROXY_IP..."
mkdir -p $CLIENT_DIR
cat > $CLIENT_DIR/client.ovpn <<EOF
client
dev tun
proto udp
remote $PROXY_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
key-direction 1
verb 3
<ca>
$(cat $OVPN_DIR/easy-rsa/pki/ca.crt)
</ca>
<cert>
$(cat $OVPN_DIR/easy-rsa/pki/issued/client.crt)
</cert>
<key>
$(cat $OVPN_DIR/easy-rsa/pki/private/client.key)
</key>
<tls-auth>
$(cat $OVPN_DIR/easy-rsa/pki/ta.key)
</tls-auth>
EOF
echo "[*] File client.ovpn đã được tạo thành công!"

# Cấu hình iptables để forward traffic về Burp Suite
echo "[*] Đang cấu hình iptables NAT rules..."
# Cho phép traffic đi ra internet
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

# Forward port 80 và 443 từ client (tun0) về IP của host chạy Burp Suite
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 80 -j DNAT --to-destination ${PROXY_IP}:8080
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 443 -j DNAT --to-destination ${PROXY_IP}:8080

# Khởi động OpenVPN Server
echo "[*] Bắt đầu chạy OpenVPN Server..."
cd $OVPN_DIR
exec openvpn --config server.conf