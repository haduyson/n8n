#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root (sudo)."
  exit 1
fi

# Cập nhật hệ thống
echo "Đang cập nhật hệ thống..."
apt update && apt upgrade -y

# Cài đặt các gói cần thiết
echo "Đang cài đặt các gói cơ bản..."
apt install -y ca-certificates curl gnupg lsb-release

# Nhập thông tin từ người dùng
echo "Vui lòng nhập các thông tin cần thiết:"
read -p "Domain của bạn (ví dụ: example.com): " DOMAIN
read -p "Tên database cho n8n (mặc định: n8n): " DB_NAME
DB_NAME=${DB_NAME:-n8n}
read -p "Username cho database (mặc định: n8n): " DB_USER
DB_USER=${DB_USER:-n8n}
read -s -p "Password cho database: " DB_PASSWORD
echo ""
read -s -p "Xác nhận lại password: " DB_PASSWORD_CONFIRM
echo ""

# Kiểm tra password có khớp không
if [ "$DB_PASSWORD" != "$DB_PASSWORD_CONFIRM" ]; then
  echo "Password không khớp. Thoát script."
  exit 1
fi

# Cài đặt Docker
echo "Đang cài đặt Docker..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io

# Cài đặt Docker Compose
echo "Đang cài đặt Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Tạo thư mục cho n8n
echo "Đang tạo thư mục và file cấu hình..."
mkdir -p ~/n8n
cd ~/n8n

# Tạo file docker-compose.yml
cat <<EOF > docker-compose.yml
version: "3.8"

services:
  postgres:
    image: postgres:16
    restart: always
    environment:
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=${DB_NAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - n8n_network

  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${DOMAIN}/
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${DB_NAME}
      - DB_POSTGRESDB_USER=${DB_USER}
      - DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - postgres
    networks:
      - n8n_network

volumes:
  n8n_data:
  postgres_data:

networks:
  n8n_network:
    driver: bridge
EOF

# Khởi động Docker Compose
echo "Đang khởi động n8n và PostgreSQL..."
docker-compose up -d

# Cài đặt Nginx (dùng cục bộ để proxy tới n8n)
echo "Đang cài đặt Nginx..."
apt install -y nginx
cat <<EOF > /etc/nginx/sites-available/n8n
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Cài đặt Cloudflare Tunnel (cloudflared)
echo "Đang cài đặt Cloudflare Tunnel..."
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb
rm cloudflared-linux-amd64.deb

# Đăng nhập vào Cloudflare và tạo tunnel
echo "Đang tạo Cloudflare Tunnel..."
cloudflared login
cloudflared tunnel create n8n-tunnel
TUNNEL_ID=$(ls /root/.cloudflared/*.json | grep -o '[a-f0-9-]\{36\}') # Lấy tunnel ID từ file .json

# Tạo file cấu hình cho tunnel
cat <<EOF > ~/.cloudflared/config.yml
tunnel: n8n-tunnel
credentials-file: /root/.cloudflared/${TUNNEL_ID}.json
ingress:
  - hostname: ${DOMAIN}
    service: http://localhost:80
  - service: http_status:404
EOF

# Cài đặt cloudflared như một dịch vụ systemd
echo "Đang cấu hình Cloudflare Tunnel chạy tự động..."
cloudflared service install /root/.cloudflared/${TUNNEL_ID}.json
systemctl enable cloudflared
systemctl start cloudflared

# Cấu hình tường lửa UFW (mở port 80 và 443 cục bộ)
echo "Đang cấu hình tường lửa..."
apt install -y ufw
ufw allow 80
ufw allow 443
ufw --force enable

# Hướng dẫn người dùng cấu hình DNS trên Cloudflare
echo "Cài đặt hoàn tất!"
echo "Truy cập n8n tại: https://${DOMAIN} (sau khi hoàn tất cấu hình DNS)"
echo "Dữ liệu n8n được lưu trong ~/n8n/n8n_data"
echo "Dữ liệu PostgreSQL được lưu trong ~/n8n/postgres_data"
echo ""
echo "HƯỚNG DẪN CẤU HÌNH DNS TRÊN CLOUDFLARE:"
echo "1. Đăng nhập vào dashboard Cloudflare (https://dash.cloudflare.com)."
echo "2. Chọn domain '${DOMAIN}'."
echo "3. Vào mục 'DNS' > 'Records'."
echo "4. Thêm một bản ghi CNAME:"
echo "   - Name: ${DOMAIN}"
echo "   - Target: Copy giá trị 'Tunnel ID' từ file ~/.cloudflared/n8n-tunnel.json (thường là một chuỗi UUID) và thêm '.cfargotunnel.com' (ví dụ: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.cfargotunnel.com)."
echo "   - Proxy status: Bật ( Proxied )."
echo "5. Lưu bản ghi và chờ DNS cập nhật (thường mất vài phút)."
echo "Sau khi hoàn tất, bạn có thể truy cập https://${DOMAIN} từ bên ngoài."
