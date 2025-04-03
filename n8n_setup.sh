#!/bin/bash
exec > >(tee -a /var/log/setupn8n.log) 2>&1
#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root (sudo)."
  exit 1
fi

# Cập nhật hệ thống
echo "Cập nhật hệ thống..."
apt update && apt upgrade -y

# Cài đặt Docker
echo "Cài đặt Docker..."
apt install -y docker.io
systemctl start docker
systemctl enable docker

# Cài đặt Docker Compose
echo "Cài đặt Docker Compose..."
apt install -y docker-compose

# Cài đặt Nginx và Certbot
echo "Cài đặt Nginx và Certbot..."
apt install -y nginx certbot python3-certbot-nginx

# Yêu cầu người dùng nhập thông tin
read -p "Nhập domain cho n8n (ví dụ: n8n.example.com): " DOMAIN
read -p "Nhập email để cấp SSL: " EMAIL
read -p "Nhập tên database cho n8n: " DB_NAME
read -p "Nhập username cho database: " DB_USER
read -s -p "Nhập password cho database: " DB_PASSWORD
echo

# Tạo thư mục cho n8n
mkdir -p /opt/n8n
cd /opt/n8n

# Tạo file docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    environment:
      - N8N_HOST=\${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=\${DB_NAME}
      - DB_POSTGRESDB_USER=\${DB_USER}
      - DB_POSTGRESDB_PASSWORD=\${DB_PASSWORD}
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - postgres

  postgres:
    image: postgres:16
    restart: always
    environment:
      - POSTGRES_USER=\${DB_USER}
      - POSTGRES_PASSWORD=\${DB_PASSWORD}
      - POSTGRES_DB=\${DB_NAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  n8n_data:
  postgres_data:
EOF

# Tạo file .env để lưu biến môi trường
cat <<EOF > .env
DOMAIN=$DOMAIN
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF

# Khởi động Docker Compose
echo "Khởi động n8n và PostgreSQL..."
docker-compose up -d

# Cấu hình Nginx
cat <<EOF > /etc/nginx/sites-available/n8n
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Kích hoạt cấu hình Nginx
ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Cấp chứng chỉ SSL với Certbot
echo "Cấp chứng chỉ SSL với Let's Encrypt..."
certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive

# Mở cổng 80 và 443 trên firewall (nếu dùng ufw)
if command -v ufw &> /dev/null; then
    echo "Mở cổng 80 và 443 trên firewall..."
    ufw allow 80
    ufw allow 443
    ufw reload
fi

# Hiển thị thông tin sau khi cài đặt
echo "========================================"
echo "Cài đặt n8n hoàn tất!"
echo "Thông tin quan trọng:"
echo "- Domain: $DOMAIN"
echo "- Email SSL: $EMAIL"
echo "- Tên database: $DB_NAME"
echo "- Username database: $DB_USER"
echo "- Password database: $DB_PASSWORD"
echo "- File cấu hình Docker: /opt/n8n/docker-compose.yml"
echo "- File biến môi trường: /opt/n8n/.env"
echo "- File cấu hình Nginx: /etc/nginx/sites-available/n8n"
echo "Truy cập n8n tại: https://$DOMAIN"
echo "========================================"
