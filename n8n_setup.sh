#!/bin/bash

echo "--------- Bắt đầu cài đặt/cấu hình n8n -----------"

# Nhập thông tin cấu hình
read -p "Nhập domain của bạn (ví dụ: n8n.example.com): " USER_DOMAIN
read -p "Nhập email của bạn (để cấp SSL - sẽ được dùng cho cấu hình sau này): " USER_EMAIL

echo "Domain bạn nhập là: $USER_DOMAIN"
echo "Email bạn nhập là: $USER_EMAIL"

echo "--------- Bắt đầu tạo thư mục -----------"
cd ~
mkdir -p vol_n8n
sudo chown -R 1000:1000 vol_n8n
sudo chmod -R 755 vol_n8n
echo "--------- Hoàn thành tạo thư mục -----------"

echo "--------- Tải file Docker Compose -----------"
wget https://raw.githubusercontent.com/haduyson/n8n/refs/heads/main/compose_noai.yaml -O compose.yaml

echo "--------- Cấu hình domain vào Docker Compose -----------"

# Thay đổi N8N_EDITOR_BASE_URL và WEBHOOK_URL
sed -i "s#N8N_EDITOR_BASE_URL=.*#N8N_EDITOR_BASE_URL=https://${USER_DOMAIN}#g" compose.yaml
sed -i "s#WEBHOOK_URL=.*#WEBHOOK_URL=https://${USER_DOMAIN}#g" compose.yaml

# Thay đổi port mapping nếu cần (ví dụ, nếu bạn muốn n8n chạy trực tiếp trên port 443 cho HTTPS)
# Lưu ý: Việc chạy trực tiếp trên port 443 thường yêu cầu quyền root hoặc cấu hình capabilities.
# Để đơn giản, chúng ta sẽ giữ port 80 và bạn sẽ cần cấu hình reverse proxy bên ngoài hoặc truy cập qua port 80.
# Nếu bạn muốn chạy HTTPS trực tiếp, bạn cần cấu hình thêm SSL trong container n8n (khó khăn hơn).
# Ví dụ (nếu bạn muốn thử chạy HTTP trên một domain cụ thể trên port 80):
# sed -i "s#\"80:5678\"#\"80:5678\"#g" compose.yaml
# Nếu bạn muốn thử chạy HTTPS trực tiếp (cần cấu hình SSL trong n8n):
# sed -i "s#\"80:5678\"#\"443:5678\"#g" compose.yaml
# Và bạn cần cấu hình các biến môi trường SSL của n8n.

echo "--------- Cấu hình hoàn tất file Docker Compose -----------"

echo "--------- Khởi động Docker Compose -----------"
export EXTERNAL_IP=http://"$(hostname -I | cut -f1 -d' ')"
export CURR_DIR=$(pwd)
sudo -E docker compose up -d

echo "--------- Cài đặt hoàn tất! -----------"
echo "Vui lòng truy cập n8n tại: http://${USER_DOMAIN} (hoặc port bạn đã cấu hình)."
echo "Lưu ý: Cấu hình này chưa bao gồm HTTPS/SSL tự động. Bạn cần tự cấu hình SSL hoặc sử dụng một reverse proxy bên ngoài."
echo "Email bạn đã nhập ($USER_EMAIL) có thể được sử dụng để cấu hình SSL thủ công sau này."
