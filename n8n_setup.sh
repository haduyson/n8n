#!/bin/bash

echo "--------- Bắt đầu cài đặt Docker -----------"
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt-cache policy docker-ce
sudo apt install -y docker-ce

echo "--------- Hoàn thành cài đặt Docker -----------"

echo "--------- Bắt đầu tạo thư mục -----------"
cd ~
mkdir vol_n8n
sudo chown -R 1000:1000 vol_n8n
sudo chmod -R 755 vol_n8n
echo "--------- Hoàn thành tạo thư mục -----------"

echo "--------- Bắt đầu khởi động Docker Compose -----------"
wget https://raw.githubusercontent.com/haduyson/n8n/refs/heads/main/compose_noai.yaml -O compose.yaml
export EXTERNAL_IP=http://"$(hostname -I | cut -f1 -d' ')"
export CURR_DIR=$(pwd)
sudo -E docker compose up -d
echo "--------- Hoàn thành! Vui lòng đợi vài phút và kiểm tra trong trình duyệt tại URL $EXTERNAL_IP để truy cập giao diện n8n -----------"
