#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root (sudo)."
  exit 1
fi

# Cập nhật hệ thống
echo "Đang cập nhật hệ thống..."
apt update && apt upgrade -y

# Yêu cầu người dùng nhập thông tin
read -p "Nhập tên miền của bạn (ví dụ: example.com): " DOMAIN
read -p "Nhập email của bạn để cấp SSL (ví dụ: admin@example.com): " EMAIL
read -p "Nhập tên database cho n8n (ví dụ: n8n_db): " DB_NAME
read -p "Nhập username cho database (ví dụ: n8n_user): " DB_USER
read -s -p "Nhập password cho database: " DB_PASS
echo ""

# Cài đặt các công cụ cần thiết
echo "Đang cài đặt các công cụ cần thiết..."
apt install -y curl nginx certbot python3-certbot-nginx postgresql postgresql-contrib

# Cài đặt Docker
echo "Đang cài đặt Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Cài đặt Docker Compose
echo "Đang cài đặt Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Tạo user và database PostgreSQL cho n8n
echo "Đang cấu hình PostgreSQL..."
sudo -u postgres psql <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

# Tạo thư mục cho n8n và file docker-compose.yml
echo "Đang tạo cấu hình Docker cho n8n..."
mkdir -p /opt/n8n
cd /opt/n8n
cat > docker-compose.yml <<EOF
version: "3.8"

services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=\${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=localhost
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=$DB_NAME
      - DB_POSTGRESDB_USER=$DB_USER
      - DB_POSTGRESDB_PASSWORD=$DB_PASS
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
EOF

# Cấu hình Nginx
echo "Đang cấu hình Nginx..."
cat > /etc/nginx/sites-available/n8n <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

# Kích hoạt cấu hình Nginx
ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Cài đặt SSL với Let's Encrypt
echo "Đang cài đặt chứng chỉ SSL với Let's Encrypt..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $EMAIL

# Khởi động n8n với Docker Compose
echo "Đang khởi động n8n với Docker..."
export DOMAIN=$DOMAIN
docker-compose up -d

# Hiển thị thông tin quan trọng
echo ""
echo "========================================"
echo "Cài đặt hoàn tất! Dưới đây là thông tin quan trọng:"
echo "========================================"
echo "Link truy cập n8n: https://$DOMAIN"
echo "Tên database: $DB_NAME"
echo "Username database: $DB_USER"
echo "Password database: $DB_PASS"
echo "Đường dẫn file cấu hình Docker: /opt/n8n/docker-compose.yml"
echo "Đường dẫn file cấu hình Nginx: /etc/nginx/sites-available/n8n"
echo "========================================"
echo "Vui lòng lưu lại thông tin trên để sử dụng khi cần!"
echo "Bạn có thể kiểm tra trạng thái n8n bằng lệnh: 'cd /opt/n8n && docker-compose ps'"
