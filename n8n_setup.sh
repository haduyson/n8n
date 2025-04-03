#!/bin/bash
exec > >(tee -a /var/log/setupn8n.log) 2>&1

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

# Cài đặt Nginx
echo "Đang cài đặt Nginx..."
apt install -y nginx

# Tạo file cấu hình Nginx
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

# Kích hoạt cấu hình Nginx
ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Cài đặt Certbot và cấu hình SSL
echo "Đang cài đặt Certbot và cấu hình SSL..."
apt install -y certbot python3-certbot-nginx
certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN}

# Cấu hình tường lửa UFW
echo "Đang cấu hình tường lửa..."
apt install -y ufw
ufw allow 80
ufw allow 443
ufw --force enable

# Hoàn tất
echo "Cài đặt hoàn tất!"
echo "Truy cập n8n tại: https://${DOMAIN}"
echo "Dữ liệu n8n được lưu trong ~/n8n/n8n_data"
echo "Dữ liệu PostgreSQL được lưu trong ~/n8n/postgres_data"
