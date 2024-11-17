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
    
    # Restart Apache setelah instalasi extension
    echo "🔄 Merestart Apache..."
    sudo service apache2 restart
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
