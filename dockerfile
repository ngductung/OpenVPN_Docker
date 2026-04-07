FROM alpine:latest

# Cài đặt OpenVPN, iptables, bash và easy-rsa
RUN apk add --no-cache openvpn iptables bash easy-rsa

# Thiết lập thư mục làm việc
WORKDIR /etc/openvpn

# Copy script khởi động vào container
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Chạy script khi container start
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]