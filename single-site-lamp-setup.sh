#!/usr/bin/env bash

# Comprehensive LAMP Setup Script for Proxmox LXC Container with Debian

set -o errexit  # Exit on any error
set -o errtrace # Ensure ERR traps are inherited by subcommands
set -o nounset  # Treat unset variables as an error
set -o pipefail # Exit on any error in a pipeline

# Common Variables for messaging
YW=`echo "\033[33m"`
BL=`echo "\033[36m"`
RD=`echo "\033[01;31m"`
GN=`echo "\033[1;92m"`
CL=`echo "\033[m"`
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"
HOLD="-"
DID_IT_AGAIN="${GN}Please run the script again.${CL}"
RETRY="${RD}An error occurred.${CL} ${DID_IT_AGAIN}"

# Function to display a message and exit the script
function msg_error() {
    echo -e "${CROSS} ${RD}$1${CL}"
    exit 1
}

# Function to display a message in yellow color
function msg_info() {
    echo -ne "${HOLD} ${YW}$1...${CL}"
}

# Function to display a message in green color
function msg_ok() {
    echo -e "${BFR}${CM} ${GN}$1${CL}"
}

# Function to prompt for input with a default value
prompt() {
  local prompt_text="$1"
  local default_value="$2"
  local user_input

  read -p "$prompt_text [$default_value]: " user_input
  echo "${user_input:-$default_value}"
}

# Prompt user for MariaDB root password
MYSQL_ROOT_PASSWORD=$(prompt "Enter MariaDB root password" "root")

# Step 1: Update the Debian OS
msg_info "Updating Container OS - Updating package list and upgrading existing packages"
sed -i "/bullseye-updates/d" /etc/apt/sources.list
echo "deb http://deb.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list.d/debian-repo.list
apt-get update
apt-get -y upgrade
msg_ok "Updated Container OS"

# Step 2: Install basic dependencies
msg_info "Installing basic dependencies (curl, sudo, nano, gnupg, software-properties-common)"
apt-get install -y curl sudo nano gnupg software-properties-common
msg_ok "Installed basic dependencies"

# Step 3: Set up Apache for a single-site deployment
msg_info "Installing Apache web server"
apt-get install -y apache2
systemctl enable apache2
systemctl start apache2
msg_ok "Installed and started Apache"

msg_info "Configuring Apache to serve the site from /var/www/html"
cat <<EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
systemctl reload apache2
msg_ok "Configured Apache to serve content from /var/www/html"

# Step 4: Install MariaDB server
msg_info "Installing MariaDB server as a drop-in replacement for MySQL"
apt-get install -y mariadb-server
msg_ok "Installed MariaDB server"

# Step 5: Secure MariaDB installation
msg_info "Securing MariaDB server"
# Switch to the MariaDB root user without a password to configure the root user authentication method.
sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$MYSQL_ROOT_PASSWORD');
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
FLUSH PRIVILEGES;
EOF
msg_ok "Secured MariaDB server"

# Step 6: Add PHP repository and install PHP 8.x
msg_info "Adding PHP repository for the latest PHP versions"
add-apt-repository ppa:ondrej/php -y
msg_ok "Added PHP repository"

msg_info "Installing PHP 8.x and required modules"
apt-get update
apt-get install -y php8.2 libapache2-mod-php php8.2-mysql
msg_ok "Installed PHP 8.x"

# Step 7: Install Adminer
msg_info "Installing Adminer database management tool"
mkdir -p /usr/share/adminer
wget "https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php" -O /usr/share/adminer/adminer.php
echo 'Alias /adminer "/usr/share/adminer/adminer.php"
<Directory "/usr/share/adminer">
    Require all granted
</Directory>' > /etc/apache2/conf-available/adminer.conf
a2enconf adminer
msg_ok "Installed Adminer"

# Step 8: Create a PHP info file to verify PHP installation
msg_info "Creating a PHP info file at /var/www/html/info.php to verify PHP installation"
echo "<?php phpinfo(); ?>" > /var/www/html/info.php
chown -R www-data:www-data /var/www/html
msg_ok "Created PHP info file"

# Step 9: Enable Apache rewrite module
msg_info "Enabling Apache rewrite module"
a2enmod rewrite
systemctl restart apache2
msg_ok "Enabled Apache rewrite module"

# Step 10: SSH configuration
msg_info "Configuring SSH to allow root login and password authentication"
sed -i "s/PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config
systemctl restart ssh
msg_ok "Configured SSH"

# Step 11: Check if root password is empty and prompt to set it
msg_info "Checking if the root password is empty"
if [ "$(grep -c root /etc/shadow)" -gt 0 ] && [ -z "$(getent shadow root | cut -d: -f2)" ]; then
  msg_info "Root password is empty, prompting to set a new password"
  passwd root
  msg_ok "Root password has been set"
fi

# Final completion message
msg_ok "LAMP server setup completed successfully!"
echo "You can access your website at http://[your-container-IP]/"
echo "Adminer is available at http://[your-container-IP]/adminer"
echo "PHP info page is available at http://[your-container-IP]/info.php"
