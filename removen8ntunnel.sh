#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root (sudo)."
  exit 1
fi

# Dừng và xóa các container Docker
echo "Đang dừng và xóa các container Docker..."
cd ~/n8n || {
  echo "Thư mục ~/n8n không tồn tại. Bỏ qua bước này."
}
if [ -f docker-compose.yml ]; then
  docker-compose down
else
  echo "Không tìm thấy file docker-compose.yml."
fi

# Xóa thư mục n8n và dữ liệu
echo "Đang xóa thư mục và dữ liệu n8n..."
rm -rf ~/n8n

# Gỡ cài đặt Docker
echo "Đang gỡ cài đặt Docker..."
apt purge -y docker-ce docker-ce-cli containerd.io
rm -rf /etc/apt/sources.list.d/docker.list
rm -rf /etc/apt/keyrings/docker.gpg

# Gỡ cài đặt Docker Compose
echo "Đang gỡ cài đặt Docker Compose..."
rm -f /usr/local/bin/docker-compose

# Gỡ cài đặt Nginx
echo "Đang gỡ cài đặt Nginx..."
systemctl stop nginx
apt purge -y nginx nginx-common nginx-full
rm -f /etc/nginx/sites-available/n8n
rm -f /etc/nginx/sites-enabled/n8n

# Dừng và gỡ cài đặt Cloudflare Tunnel
echo "Đang dừng và gỡ cài đặt Cloudflare Tunnel..."
systemctl stop cloudflared
systemctl disable cloudflared
rm -f /etc/systemd/system/cloudflared.service
cloudflared tunnel delete n8n-tunnel || echo "Không thể xóa tunnel (có thể đã bị xóa trước đó)."
rm -rf ~/.cloudflared
apt purge -y cloudflared

# Đóng port trên tường lửa và gỡ UFW (nếu không cần nữa)
echo "Đang đóng port trên tường lửa..."
ufw delete allow 80
ufw delete allow 443
# Nếu muốn gỡ hoàn toàn UFW, bỏ comment dòng dưới
# apt purge -y ufw

# Xóa các gói không cần thiết
echo "Đang dọn dẹp hệ thống..."
apt autoremove -y
apt autoclean

# Hoàn tất
echo "Đã xóa toàn bộ cài đặt n8n và Cloudflare Tunnel!"
echo "Lưu ý: Bạn cần xóa thủ công bản ghi DNS trên Cloudflare dashboard nếu không còn sử dụng domain."
