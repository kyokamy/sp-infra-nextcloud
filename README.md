# Simplon Infrastructure

This repository contains a script (`simplon-infra.sh`) that automates the setup of an infrastructure on AWS. The infrastructure includes a bastion instance, MySQL instance, and Nextcloud instance.

## Prerequisites

- AWS CLI installed and configured with appropriate credentials
- SSH key pair for accessing the instances

## Launching the Infrastructure

To launch the infrastructure, follow these steps:

1. Clone this repository:

   ```bash
   git clone https://github.com/example/simplon-infrastructure.git
   cd simplon-infrastructure

2. Make the script executable:
   ```bash
   chmod +x simplon-infra.sh


3. Run the script
   ```bash
   ./simplon-infra.sh


## Accessing the Bastion Instance via SSH

The bastion instance acts as a gateway for accessing other instances within the private subnet. To connect to the bastion instance via SSH, follow these steps:

1. Retrieve the public IP address of the bastion instance. You can find it in the script's output or use the AWS CLI:
   ```bash
   aws ec2 describe-instances --instance-ids <bastion-instance-id> --query 'Reservations[0].Instances[0].PublicIpAddress' --output text


3. Use SSH to connect to the bastion instance:
   ```bash
   ssh -i /path/to/ssh-key.pem ec2-user@<bastion-public-ip> -p 10022

Replace /path/to/ssh-key.pem with the path to your SSH key pair and <bastion-public-ip> with the actual public IP address of the bastion instance.

4. You are now connected to the bastion instance. From here, you can access other instances within the private subnet.

## Accessing Nextcloud

Nextcloud is accessible through a web interface. To access Nextcloud, follow these steps:

1. Open a web browser and enter the public IP address of the Nextcloud instance.

http://<nextcloud-public-ip>

2. Replace <nextcloud-public-ip> with the actual public IP address of the Nextcloud instance.

You should see the Nextcloud login page. Enter the necessary credentials to log in and start using Nextcloud.

3. If you want to access Nextcloud securely over HTTPS, you can set up SSL/TLS using a reverse proxy like Nginx or Apache.