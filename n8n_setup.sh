#!/bin/bash

# Thông báo bắt đầu cài đặt
echo "Bắt đầu cài đặt n8n..."

# Yêu cầu người dùng nhập thông tin
read -p "Nhập tên miền của bạn (ví dụ: n8n.example.com): " DOMAIN
read -p "Nhập email để cấp chứng chỉ SSL (Let's Encrypt): " EMAIL
read -p "Nhập tên database PostgreSQL: " DB_NAME
read -p "Nhập tên người dùng database PostgreSQL: " DB_USER
read -s -p "Nhập mật khẩu database PostgreSQL: " DB_PASSWORD
echo "" # Thêm dòng mới sau khi nhập mật khẩu

# Cập nhật hệ thống
echo "Cập nhật hệ thống..."
sudo apt update -y
sudo apt upgrade -y

# Cài đặt Docker và Docker Compose
echo "Cài đặt Docker và Docker Compose..."
sudo apt install docker.io docker-compose-plugin -y
sudo systemctl start docker
sudo systemctl enable docker

# Cài đặt PostgreSQL
echo "Cài đặt PostgreSQL..."
sudo apt install postgresql postgresql-contrib -y

# Cấu hình PostgreSQL
echo "Cấu hình PostgreSQL..."
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# Tạo thư mục lưu trữ dữ liệu n8n và chứng chỉ SSL
echo "Tạo thư mục lưu trữ dữ liệu n8n và chứng chỉ SSL..."
sudo mkdir -p /opt/n8n/data
sudo mkdir -p /opt/letsencrypt

# Tạo file docker-compose.yml
echo "Tạo file docker-compose.yml..."
cat <<EOF | sudo tee /opt/n8n/docker-compose.yml
version: "3.8"

services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=n8n
      - N8N_BASIC_AUTH_PASSWORD=n8n
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=host.docker.internal
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=$DB_NAME
      - DB_POSTGRESDB_USER=$DB_USER
      - DB_POSTGRESDB_PASSWORD=$DB_PASSWORD
      - N8N_HOST=$DOMAIN
      - N8N_PROTOCOL=https
      - N8N_PORT=443
      - GENERIC_WEBHOOK_URL=https://$DOMAIN/
      - WEBHOOK_TUNNEL_URL=https://$DOMAIN/
    volumes:
      - /opt/n8n/data:/home/node/.n8n

  reverse-proxy:
    image: traefik:v2.9
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=$EMAIL"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - "443:443"
      - "8080:8080"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "/opt/letsencrypt:/letsencrypt"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(\`$DOMAIN\`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls=true"
      - "traefik.http.routers.n8n.tls.certresolver=myresolver"
EOF

# Mở cổng 80 và 443 trên tường lửa
echo "Mở cổng 80 và 443 trên tường lửa..."
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable

# Khởi động n8n
echo "Khởi động n8n..."
sudo docker compose -f /opt/n8n/docker-compose.yml up -d

# Hiển thị thông tin quan trọng
echo "Cài đặt n8n thành công!"
echo "Truy cập n8n tại: https://$DOMAIN"
echo "File cấu hình docker-compose.yml: /opt/n8n/docker-compose.yml"
echo "Thư mục lưu trữ dữ liệu n8n: /opt/n8n/data"
echo "Thư mục lưu trữ chứng chỉ SSL: /opt/letsencrypt"
echo "Tên người dùng mặc định n8n: n8n"
echo "Mật khẩu mặc định n8n: n8n"
echo "Cần hỗ trợ cài đặt (có phí), vui lòng liên hệ Telegram @haduyson"
