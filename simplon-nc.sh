#!/bin/bash

# Update and upgrade Ubuntu
sudo apt update && sudo apt upgrade -y

# Download Nextcloud
wget https://download.nextcloud.com/server/releases/latest.zip

# Install required PHP modules
sudo apt install -y php php-apcu php-bcmath php-cli php-common php-curl php-gd php-gmp php-imagick php-intl php-mbstring php-mysql php-zip php-xml

# Enable necessary PHP modules
sudo phpenmod bcmath gmp imagick intl

# Enable Apache modules
sudo a2enmod dir env headers mime rewrite ssl

# Restart Apache
sudo systemctl restart apache2

# Unzip Nextcloud and remove the archive
unzip latest.zip
rm latest.zip

# Move Nextcloud to the web server directory
sudo chown -R www-data:www-data nextcloud
sudo mv nextcloud /var/www

# Disable default Apache site
sudo a2dissite 000-default.conf

# Create and edit Nextcloud virtual host configuration file
sudo bash -c 'cat > /etc/apache2/sites-available/nextcloud.conf << EOF
<VirtualHost *:80>
    DocumentRoot "/var/www/nextcloud"
    ServerName nextcloud.learnlinux.cloud

    <Directory "/var/www/nextcloud/">
        Options MultiViews FollowSymLinks
        AllowOverride All
        Order allow,deny
        Allow from all
    </Directory>

    TransferLog /var/log/apache2/nextcloud_access.log
    ErrorLog /var/log/apache2/nextcloud_error.log
</VirtualHost>
EOF'

# Enable Nextcloud virtual host
sudo a2ensite nextcloud.conf

# Modify php.ini
sudo sed -i 's/;memory_limit = .*/memory_limit = 512M/' /etc/php/*/apache2/php.ini
sudo sed -i 's/;upload_max_filesize = .*/upload_max_filesize = 200M/' /etc/php/*/apache2/php.ini
sudo sed -i 's/;max_execution_time = .*/max_execution_time = 360/' /etc/php/*/apache2/php.ini
sudo sed -i 's/;post_max_size = .*/post_max_size = 200M/' /etc/php/*/apache2/php.ini
sudo sed -i 's/;date.timezone =.*/date.timezone = America\/Detroit/' /etc/php/*/apache2/php.ini
sudo sed -i 's/;opcache.enable=0/opcache.enable=1/' /etc/php/*/apache2/php.ini
sudo sed -i 's/;opcache.interned_strings_buffer=4/opcache.interned_strings_buffer=8/' /etc/php/*/apache2/php.ini
sudo sed -i 's/;opcache.max_accelerated_files=2000/opcache.max_accelerated_files=10000/' /etc/php/*/apache2/php.ini
sudo sed -i 's/;opcache.memory_consumption=64/opcache.memory_consumption=128/' /etc/php/*/apache2/php.ini
sudo sed -i 's/;opcache.save_comments=1/opcache.save_comments=1/' /etc/php/*/apache2/php.ini
sudo sed -i 's/;opcache.revalidate_freq=2/opcache.revalidate_freq=1/' /etc/php/*/apache2/php.ini

# Restart Apache
sudo systemctl restart apache2

# Install AWS CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Configure AWS CloudWatch agent for Nextcloud
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
sudo bash -c 'cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "metrics": {
    "namespace": "Nextcloud",
    "metrics_collected": {
      "collectd": {},
      "prometheus": {
        "prometheus_config_path": "/opt/aws/amazon-cloudwatch-agent/etc/prometheus.yml"
      }
    },
    "append_dimensions": {
      "LogGroup": "${hostname}",
      "RetentionPeriod": "365"
    }
  }
}
EOF'

sudo bash -c 'cat > /opt/aws/amazon-cloudwatch-agent/etc/prometheus.yml << EOF
global:
  scrape_interval: 60s

scrape_configs:
  - job_name: 'nextcloud'
    static_configs:
      - targets: ['localhost:9100']
EOF'

# Enable and start AWS CloudWatch agent
sudo systemctl enable amazon-cloudwatch-agent.service
sudo systemctl start amazon-cloudwatch-agent.service

echo "Nextcloud installation and AWS CloudWatch agent configuration complete."