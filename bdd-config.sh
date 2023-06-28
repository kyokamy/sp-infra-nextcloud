#!/bin/bash

# Update and upgrade Ubuntu
sudo apt update
sudo apt upgrade -y

# Install MySQL server
sudo apt install mysql-server -y

# Set MySQL root user password
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'AdminUser87#'"

# Create nextcloud database and user
sudo mysql -e "CREATE DATABASE nextcloud;"
sudo mysql -e "CREATE USER 'nextcloud_user'@'%' IDENTIFIED WITH mysql_native_password BY 'NextcloudAdminUser87#';"
sudo mysql -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud_user'@'%';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Restart MySQL server
sudo systemctl restart mysql.service

# Install AWS CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Configure AWS CloudWatch agent for MySQL
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
sudo bash -c 'cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "metrics": {
    "namespace": "MySQL",
    "metrics_collected": {
      "collectd": {},
      "mysql": {
        "metrics_collection_interval": 60,
        "force_flush_interval": 60,
        "disable_innodb_metrics": false,
        "disable_master_metrics": false,
        "disable_slave_metrics": false,
        "disable_processlist_metrics": false,
        "innodb_metrics_mode": "innodb_status",
        "procstat_file": "/proc/stat",
        "userstat_file": "/proc/self/stat",
        "slave_status_file": "/tmp/amazon-cloudwatch-agent-mysql_slave_status"
      }
    },
    "append_dimensions": {
      "LogGroup": "${hostname}",
      "RetentionPeriod": "365"
    }
  }
}
EOF'

# Enable and start AWS CloudWatch agent
sudo systemctl enable amazon-cloudwatch-agent.service
sudo systemctl start amazon-cloudwatch-agent.service

echo "MySQL server installation and AWS CloudWatch agent configuration complete."