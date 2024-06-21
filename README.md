# Enhanced-Lamp-Server-single-site

---

## Single-Site LAMP Server Setup Script for Proxmox LXC Containers

This repository provides a Bash script to automate the setup of a LAMP (Linux, Apache, MySQL, PHP) server in a Debian-based LXC container on Proxmox. The script configures the server to serve a single website, ensuring that the server's IP address or hostname directly points to the site’s content.

### Key Features:

- **Apache Configuration**: Sets up Apache to serve content from `/var/www/html`, making your website accessible directly through the server's IP or hostname.
- **MySQL Installation and Secure Setup**: Installs MySQL and prompts for a root password to secure the database server.
- **PHP 8.x Installation**: Installs the latest PHP 8.x version with necessary modules.
- **Adminer Installation**: Provides an easy-to-use web interface for managing MySQL databases, accessible at `/adminer`.
- **Secure and Easy Configuration**: Includes steps to secure the MySQL installation, configure SSH for root access, and enable Apache's rewrite module.

## Usage:

1. **Clone or Download** this repository.
2. **Make the script executable**: `chmod +x single-site-lamp-setup.sh`.
3. **Run the script** in your LXC container: `./single-site-lamp-setup.sh`.
4. **Access your website** at `http://[your-container-IP]/`.

This script simplifies the process of setting up a robust and secure single-site LAMP server in a Proxmox LXC environment.
