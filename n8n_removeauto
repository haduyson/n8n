#!/bin/bash
[ "$EUID" -ne 0 ] && echo "Vui lòng chạy với sudo" && exit 1; cd /opt/n8n 2>/dev/null && docker-compose down; rm -rf /opt/n8n; rm -f /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n; nginx -t && systemctl reload nginx; sudo -u postgres psql -c "DROP DATABASE n8n_db; DROP USER n8n_user;" 2>/dev/null; echo "Đã xóa n8n và các thành phần liên quan!"
