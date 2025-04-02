#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root (sudo)."
  exit 1
fi

# Dừng và xóa container n8n
echo "Đang dừng và xóa container n8n..."
cd /opt/n8n || {
  echo "Thư mục /opt/n8n không tồn tại, bỏ qua bước dừng container."
}
if [ -f docker-compose.yml ]; then
  docker-compose down
  echo "Đã dừng container n8n."
else
  echo "Không tìm thấy docker-compose.yml, bỏ qua."
fi

# Xóa thư mục n8n
echo "Đang xóa thư mục /opt/n8n..."
rm -rf /opt/n8n
echo "Đã xóa /opt/n8n."

# Xóa cấu hình Nginx
echo "Đang xóa cấu hình Nginx..."
rm -f /etc/nginx/sites-available/n8n
rm -f /etc/nginx/sites-enabled/n8n
nginx -t && systemctl reload nginx
echo "Đã xóa cấu hình Nginx."

# Xóa database và user PostgreSQL
echo "Đang xóa database và user PostgreSQL..."
read -p "Nhập tên database đã tạo cho n8n (ví dụ: n8n_db): " DB_NAME
read -p "Nhập username database đã tạo (ví dụ: n8n_user): " DB_USER

sudo -u postgres psql <<EOF
DROP DATABASE $DB_NAME;
DROP USER $DB_USER;
EOF
echo "Đã xóa database $DB_NAME và user $DB_USER."

# (Tùy chọn) Gỡ cài đặt Docker, Nginx, PostgreSQL
read -p "Bạn có muốn gỡ cài đặt Docker, Nginx và PostgreSQL không? (y/n): " REMOVE_ALL
if [ "$REMOVE_ALL" = "y" ]; then
  echo "Đang gỡ cài đặt Docker..."
  apt purge -y docker.io docker-compose
  rm -rf /var/lib/docker

  echo "Đang gỡ cài đặt Nginx..."
  apt purge -y nginx nginx-common
  rm -rf /etc/nginx

  echo "Đang gỡ cài đặt PostgreSQL..."
  apt purge -y postgresql postgresql-contrib
  rm -rf /var/lib/postgresql

  echo "Đang dọn dẹp các gói không cần thiết..."
  apt autoremove -y
  apt autoclean
fi

# Xóa chứng chỉ SSL (nếu có)
read -p "Bạn có muốn xóa chứng chỉ SSL của Let's Encrypt không? (y/n): " REMOVE_SSL
if [ "$REMOVE_SSL" = "y" ]; then
  read -p "Nhập tên miền đã dùng (ví dụ: example.com): " DOMAIN
  certbot delete --cert-name $DOMAIN
  echo "Đã xóa chứng chỉ SSL cho $DOMAIN."
fi

echo "========================================"
echo "Đã xóa n8n và các thành phần liên quan khỏi server!"
echo "========================================"
