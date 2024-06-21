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
STD="&>/dev/null"

# Function to display a message and exit the script
function msg_error() {
    echo -e "${CROSS} ${RD}$1${CL}"
    exit 1
}

# Function to display a message in yellow color
function msg_info() {
    echo -ne "${HOLD} ${YW}$1..."
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

# Prompt user for MySQL root password
MYSQL_ROOT_PASSWORD=$(prompt "Enter MySQL root password" "root")

# Step 1: Update the Debian OS
msg_info "Updating Container OS"
sed -i "/bullseye-updates/d" /etc/apt/sources.list
echo "deb http://deb.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list.d/debian-repo.list
apt-get update
apt-get -y upgrade ${STD}
msg_ok "Updated Container OS"

# Step 2: Install basic dependencies
msg_info "Installing Dependencies"
apt-get install -y curl sudo nano gnupg software-properties-common ${STD}
msg_ok "Installed Dependencies"

# Step 3: Set up Apache for a single-site deployment
msg_info "Installing Apache"
apt-get install -y apache2 ${STD}
systemctl enable apache2 ${STD}
systemctl start apache2 ${STD}

# Configure Apache to serve the site from /var/www/html
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
msg_ok "Configured Apache"

# Step 4: Install MySQL server
msg_info "Installing MySQL Server"
apt-get install -y mysql-server ${STD}
msg_ok "Installed MySQL Server"

# Secure MySQL installation
msg_info "Securing MySQL"
mysql_secure_installation <<EOF

y
$MYSQL_ROOT_PASSWORD
$MYSQL_ROOT_PASSWORD
y
y
y
y
EOF
msg_ok "Secured MySQL"

# Step 5: Add PHP repository and install PHP 8.x
msg_info "Adding PHP repository"
add-apt-repository ppa:ondrej/php -y ${STD}
msg_ok "Added PHP repository"

msg_info "Installing PHP 8.x"
apt-get update ${STD}
apt-get install -y php8.2 libapache2-mod-php php8.2-mysql ${STD}
msg_ok "Installed PHP 8.x"

# Step 6: Install Adminer
msg_info "Installing Adminer"
mkdir -p /usr/share/adminer
wget "https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php" -O /usr/share/adminer/adminer.php ${STD}
echo 'Alias /adminer "/usr/share/adminer/adminer.php"
<Directory "/usr/share/adminer">
    Require all granted
</Directory>' > /etc/apache2/conf-available/adminer.conf
a2enconf adminer ${STD}
msg_ok "Installed Adminer"

# Step 7: Create a PHP info file to verify PHP installation
msg_info "Creating PHP info file"
echo "<?php phpinfo(); ?>" > /var/www/html/info.php
chown -R www-data:www-data /var/www/html
msg_ok "Created PHP info file"

# Step 8: Enable Apache rewrite module (optional but recommended for most web apps)
msg_info "Enabling Apache rewrite module"
a2enmod rewrite ${STD}
systemctl restart apache2 ${STD}
msg_ok "Enabled Apache rewrite module"

# Step 9: SSH configuration
msg_info "Setting up SSH"
sed -i "s/PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config
systemctl restart ssh ${STD}
msg_ok "Set up SSH"

# Step 10: Check if root password is empty and prompt to set it
if [ "$(grep -c root /etc/shadow)" -gt 0 ] && [ -z "$(getent shadow root | cut -d: -f2)" ]; then
  msg_info "Setting Root Password"
  passwd root
  msg_ok "Set Root Password"
fi

# Final completion message
msg_ok "LAMP server setup completed successfully!"
echo "You can access your website at http://[your-container-IP]/"
echo "Adminer is available at http://[your-container-IP]/adminer"
echo "PHP info page is available at http://[your-container-IP]/info.php"
