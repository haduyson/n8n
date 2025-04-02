#!/bin/bash

echo "--------- Bắt đầu cài đặt Docker -----------"
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt-cache policy docker-ce
sudo apt install -y docker-ce

echo "--------- Hoàn thành cài đặt Docker -----------"

echo "--------- Nhập thông tin cấu hình -----------"
read -p "Nhập domain của bạn (ví dụ: n8n.example.com): " USER_DOMAIN
read -p "Nhập email của bạn (để cấp SSL): " USER_EMAIL

echo "Domain bạn nhập là: $USER_DOMAIN"
echo "Email bạn nhập là: $USER_EMAIL"

echo "--------- Bắt đầu tạo thư mục -----------"
cd ~
mkdir vol_n8n
sudo chown -R 1000:1000 vol_n8n
sudo chmod -R 755 vol_n8n
echo "--------- Hoàn thành tạo thư mục -----------"

echo "--------- Tải file Docker Compose -----------"
wget https://raw.githubusercontent.com/haduyson/n8n/refs/heads/main/compose_noai.yaml -O compose.yaml

echo "--------- Cấu hình domain vào Docker Compose -----------"
sed -i "s/N8N_HOST=.*/N8N_HOST=$USER_DOMAIN/" compose.yaml
sed -i "s/N8N_PROTOCOL=.*/N8N_PROTOCOL=https/" compose.yaml
sed -i "s/N8N_PORT=.*/N8N_PORT=5678/" compose.yaml
sed -i "s/VIRTUAL_HOST=.*/VIRTUAL_HOST=$USER_DOMAIN/" compose.yaml
sed -i "s/VIRTUAL_PORT=.*/VIRTUAL_PORT=5678/" compose.yaml
sed -i "s/LETSENCRYPT_HOST=.*/LETSENCRYPT_HOST=$USER_DOMAIN/" compose.yaml
sed -i "s/LETSENCRYPT_EMAIL=.*/LETSENCRYPT_EMAIL=$USER_EMAIL/" compose.yaml

echo "--------- Khởi động Docker Compose -----------"
export EXTERNAL_IP=http://"$(hostname -I | cut -f1 -d' ')"
export CURR_DIR=$(pwd)
sudo -E docker compose up -d

echo "--------- Cài đặt hoàn tất! -----------"
echo "Vui lòng đợi vài phút và kiểm tra tại: https://$USER_DOMAIN"
