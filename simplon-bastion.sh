#!/bin/bash

# Update and upgrade Ubuntu
sudo apt update
sudo apt upgrade -y

# Change SSH port
sudo sed -i 's/#Port 22/Port 10022/' /etc/ssh/sshd_config

# Restart SSH service
sudo systemctl restart sshd