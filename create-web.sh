#!/bin/bash

# Fungsi untuk memvalidasi input
validate_input() {
    if [ -z "$1" ]; then
        echo "Error: Nama project tidak boleh kosong!"
        exit 1
    fi
}

# Fungsi untuk menginstall PHP extensions
install_php_extensions() {
    echo "🔍 Memeriksa PHP extensions..."
    
    # Deteksi versi PHP yang digunakan
    PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    
    # List ekstensi yang dibutuhkan
    REQUIRED_EXTENSIONS=("curl" "intl" "mbstring" "xml" "zip")
    
    for ext in "${REQUIRED_EXTENSIONS[@]}"; do
        if ! php -m | grep -q "^$ext$"; then
            echo "📦 Menginstall php$PHP_VERSION-$ext..."
            sudo apt-get update
            sudo apt-get install -y "php$PHP_VERSION-$ext"
        else
            echo "✅ PHP extension $ext sudah terinstall"
        fi
    done
    
    # Restart PHP-FPM setelah instalasi extension
    echo "🔄 Merestart PHP-FPM..."
    sudo service "php$PHP_VERSION-fpm" restart
}

# Fungsi untuk membuat konfigurasi Nginx
create_nginx_config() {
    local project_name=$1
    local project_type=$2
    
    echo "📝 Membuat konfigurasi Nginx..."
    
    # Template konfigurasi Nginx
    if [ "$project_type" = "1" ]; then
        # Config untuk CodeIgniter
        sudo bash -c "cat > /etc/nginx/sites-available/$project_name.conf << 'EOL'
server {
    listen 80;
    server_name $project_name.local;
    root /var/www/html/$project_name/public;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL"
    elif [ "$project_type" = "2" ]; then
        # Config untuk Laravel
        sudo bash -c "cat > /etc/nginx/sites-available/$project_name.conf << 'EOL'
server {
    listen 80;
    server_name $project_name.local;
    root /var/www/html/$project_name/public;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')-fpm.sock;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOL"
    fi

    # Aktifkan site
    sudo ln -sf /etc/nginx/sites-available/$project_name.conf /etc/nginx/sites-enabled/
    
    # Tambahkan entry ke hosts file
    echo "127.0.0.1 $project_name.local" | sudo tee -a /etc/hosts
    
    # Test dan reload Nginx
    sudo nginx -t && sudo service nginx reload
    
    echo "✅ Konfigurasi Nginx berhasil dibuat"
    echo "🌐 Site tersedia di: http://$project_name.local"
}

# Fungsi untuk membuat project
create_project() {
    local project_name=$1
    local project_type=$2
    
    echo "Memulai pembuatan project..."
    
    # Install PHP extensions yang dibutuhkan
    install_php_extensions
    
    # Masuk ke direktori web
    cd /var/www/html || exit
    
    # Set permission awal untuk /var/www/html
    echo "Setting permission awal..."
    sudo chown -R $USER:www-data /var/www/html
    sudo chmod -R 775 /var/www/html
    
    # Buat project berdasarkan tipe
    echo "Membuat project $project_name..."
    if [ "$project_type" = "1" ]; then
        if composer create-project codeigniter4/appstarter "$project_name"; then
            echo "Project CodeIgniter berhasil dibuat"
        else
            echo "Gagal membuat project CodeIgniter"
            exit 1
        fi
    elif [ "$project_type" = "2" ]; then
        if composer create-project laravel/laravel "$project_name"; then
            echo "Project Laravel berhasil dibuat"
        else
            echo "Gagal membuat project Laravel"
            exit 1
        fi
    fi
    
    # Periksa apakah direktori project berhasil dibuat
    if [ -d "/var/www/html/$project_name" ]; then
        echo "Setting permission project folder..."
        sudo chown -R $USER:www-data "/var/www/html/$project_name"
        sudo chmod -R 775 "/var/www/html/$project_name"
        
        # Buat konfigurasi Nginx
        create_nginx_config "$project_name" "$project_type"
        
        # Buat database
        echo "Membuat database..."
        if sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS ${project_name};" && \
           sudo mysql -u root -e "GRANT ALL PRIVILEGES ON ${project_name}.* TO 'root'@'localhost';" && \
           sudo mysql -u root -e "FLUSH PRIVILEGES;"; then
            echo "✅ Database $project_name berhasil dibuat!"
        else
            echo "❌ Gagal membuat database"
            exit 1
        fi
        
        echo "✅ Project $project_name telah berhasil dibuat!"
        echo "📁 Lokasi: /var/www/html/$project_name"
        echo "🔐 Permission telah diatur"
        echo "🗄️ Database: $project_name"
        echo "🌐 Website: http://$project_name.local"
    else
        echo "❌ Gagal membuat direktori project"
        exit 1
    fi
}

# Main script
clear
echo "=== PHP Framework Project Creator ==="
echo "1. CodeIgniter"
echo "2. Laravel"
read -p "Pilih framework (1/2): " framework_choice

if [[ ! "$framework_choice" =~ ^[1-2]$ ]]; then
    echo "❌ Pilihan tidak valid! Pilih 1 atau 2"
    exit 1
fi

read -p "Masukkan nama project: " project_name

# Validasi input
validate_input "$project_name"

# Cek apakah direktori project sudah ada
if [ -d "/var/www/html/$project_name" ]; then
    echo "❌ Project dengan nama $project_name sudah ada!"
    exit 1
fi

# Cek apakah sudo password valid
if sudo -v; then
    create_project "$project_name" "$framework_choice"
else
    echo "❌ Sudo authentication failed!"
    exit 1
fi
