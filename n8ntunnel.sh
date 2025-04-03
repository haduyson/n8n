#!/bin/bash

# Nhập thông tin từ người dùng
echo "Nhập domain của bạn (ví dụ: n8n.yourdomain.com):"
read DOMAIN
echo "Nhập tên database PostgreSQL:"
read DB_NAME
echo "Nhập username database PostgreSQL:"
read DB_USER
echo "Nhập password database PostgreSQL:"
read -s DB_PASS
echo "Nhập Cloudflare Tunnel Token:"
read -s CF_TUNNEL_TOKEN

# Cài đặt Docker và Docker Compose
apt update && apt install -y docker.io docker-compose
systemctl enable --now docker

# Tạo thư mục chứa dữ liệu\mkdir -p /opt/n8n && cd /opt/n8n

# Tạo file docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:15
    restart: always
    environment:
      POSTGRES_DB: $DB_NAME
      POSTGRES_USER: $DB_USER
      POSTGRES_PASSWORD: $DB_PASS
    volumes:
      - postgres_data:/var/lib/postgresql/data

  n8n:
    image: n8nio/n8n
    restart: always
    depends_on:
      - postgres
    environment:
      DB_TYPE: postgres
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: $DB_NAME
      DB_POSTGRESDB_USER: $DB_USER
      DB_POSTGRESDB_PASSWORD: $DB_PASS
      N8N_HOST: $DOMAIN
      N8N_PROTOCOL: https
      WEBHOOK_TUNNEL_URL: https://$DOMAIN/
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n

  cloudflared:
    image: cloudflare/cloudflared:latest
    restart: always
    command: tunnel --no-autoupdate run --token $CF_TUNNEL_TOKEN

volumes:
  postgres_data:
  n8n_data:
EOF

# Khởi động các container
docker-compose up -d

# Mở port firewall
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
