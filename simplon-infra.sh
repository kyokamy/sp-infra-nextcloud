#!/bin/bash

# Define variables
STACK_NAME="nils-infrastructure"
REGION="eu-west-3"

# Generate a unique suffix for resource names
RESOURCE_SUFFIX=$(date +%s)

# Function to handle errors and destroy resources
function handle_error {
  echo "An error occurred. Destroying resources..."

  if [[ -n "$bastion_instance_id" ]]; then
    aws ec2 terminate-instances --instance-ids "$bastion_instance_id" --region "$REGION"
    aws ec2 wait instance-terminated --instance-ids "$bastion_instance_id" --region "$REGION"
  fi

  if [[ -n "$mysql_instance_id" ]]; then
    aws ec2 terminate-instances --instance-ids "$mysql_instance_id" --region "$REGION"
    aws ec2 wait instance-terminated --instance-ids "$mysql_instance_id" --region "$REGION"
  fi

  if [[ -n "$nextcloud_instance_id" ]]; then
    aws ec2 terminate-instances --instance-ids "$nextcloud_instance_id" --region "$REGION"
    aws ec2 wait instance-terminated --instance-ids "$nextcloud_instance_id" --region "$REGION"
  fi

  if [[ -n "$bastion_sg_id" ]]; then
    aws ec2 delete-security-group --group-id "$bastion_sg_id" --region "$REGION"
  fi

  if [[ -n "$mysql_sg_id" ]]; then
    aws ec2 delete-security-group --group-id "$mysql_sg_id" --region "$REGION"
  fi

  if [[ -n "$nextcloud_sg_id" ]]; then
    aws ec2 delete-security-group --group-id "$nextcloud_sg_id" --region "$REGION"
  fi

  if [[ -n "$public_subnet_id" ]]; then
    aws ec2 delete-subnet --subnet-id "$public_subnet_id" --region "$REGION"
  fi

  if [[ -n "$private_subnet_id" ]]; then
    aws ec2 delete-subnet --subnet-id "$private_subnet_id" --region "$REGION"
  fi

  if [[ -n "$gateway_id" ]]; then
    aws ec2 detach-internet-gateway --internet-gateway-id "$gateway_id" --vpc-id "$vpc_id" --region "$REGION"
    aws ec2 delete-internet-gateway --internet-gateway-id "$gateway_id" --region "$REGION"
  fi

  if [[ -n "$route_table_assoc_id" ]]; then
    aws ec2 disassociate-route-table --association-id "$route_table_assoc_id" --region "$REGION"
  fi

  if [[ -n "$public_route_table_id" ]]; then
    aws ec2 delete-route-table --route-table-id "$public_route_table_id" --region "$REGION"
  fi

  if [[ -n "$vpc_id" ]]; then
    aws ec2 delete-vpc --vpc-id "$vpc_id" --region "$REGION"
  fi

  echo "Resources destroyed. Exiting..."
  exit 1
}

# Trap errors and call the handle_error function
trap 'handle_error' ERR

# Create a VPC
vpc_id=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications ResourceType=vpc,Tags='[{Key=Name,Value="simplon-vpc"}]' --region "$REGION" --query 'Vpc.VpcId' --output text)
echo "VPC created with ID: $vpc_id"

# Check if VPC creation was successful
if [[ $? -ne 0 ]]; then
  echo "Failed to create VPC. Exiting..."
  exit 1
fi

# Create a public subnet
public_subnet_id=$(aws ec2 create-subnet --vpc-id "$vpc_id" --cidr-block 10.0.1.0/24 --availability-zone "$REGION"a --query 'Subnet.SubnetId' --output text)
echo "Public subnet created with ID: $public_subnet_id"

# Create a private subnet
private_subnet_id=$(aws ec2 create-subnet --vpc-id "$vpc_id" --cidr-block 10.0.10.0/24 --availability-zone "$REGION"b --query 'Subnet.SubnetId' --output text)
echo "Private subnet created with ID: $private_subnet_id"

# Create an internet gateway
gateway_id=$(aws ec2 create-internet-gateway --region "$REGION" --query 'InternetGateway.InternetGatewayId' --output text)
echo "Internet gateway created with ID: $gateway_id"

# Attach the internet gateway to the VPC
aws ec2 attach-internet-gateway --vpc-id "$vpc_id" --internet-gateway-id "$gateway_id" --region "$REGION"
echo "Internet gateway attached to the VPC"

# Create a public route table
public_route_table_id=$(aws ec2 create-route-table --vpc-id "$vpc_id" --region "$REGION" --query 'RouteTable.RouteTableId' --output text)
echo "Public route table created with ID: $public_route_table_id"

# Associate the public subnet with the public route table
route_table_assoc_id=$(aws ec2 associate-route-table --subnet-id "$public_subnet_id" --route-table-id "$public_route_table_id" --query 'AssociationId' --output text)
echo "Public subnet associated with the public route table"

# Create a route in the public route table
public_route=$(aws ec2 create-route --route-table-id "$public_route_table_id" --destination-cidr-block 0.0.0.0/0 --gateway-id "$gateway_id" --region "$REGION")

# Create a security group for the bastion instance
bastion_sg_id=$(aws ec2 create-security-group --group-name bastion-security-group --description "bastion security group" --vpc-id "$vpc_id" --query 'GroupId' --output text)
echo "Bastion security group created with ID: $bastion_sg_id"

# Add inbound SSH rule to the bastion security group
bastion_rule=$(aws ec2 authorize-security-group-ingress --group-id "$bastion_sg_id" --protocol tcp --port 10022 --cidr 0.0.0.0/0)
echo "Inbound SSH rule added to the bastion security group"

# Create a bastion instance
bastion_instance_id=$(aws ec2 run-instances --image-id ami-05b5a865c3579bbc4 --instance-type t2.micro --key-name nextcloud-simplon --user-data ./simplon-bastion.sh --security-group-ids "$bastion_sg_id" --subnet-id "$public_subnet_id" --region "$REGION" --associate-public-ip-address --query 'Instances[0].InstanceId' --output text)
echo "Bastion instance created with ID: $bastion_instance_id"

# Create a security group for the MySQL instance
mysql_sg_id=$(aws ec2 create-security-group --group-name mysql-security-group --description "MySQL Security Group" --vpc-id "$vpc_id" --region "$REGION" --query 'GroupId' --output text)
echo "MySQL security group created with ID: $mysql_sg_id"

# Add inbound MySQL rule to the MySQL security group
mysql_rule=$(aws ec2 authorize-security-group-ingress --group-id "$mysql_sg_id" --protocol tcp --port 3306 --source-group "$bastion_sg_id" --region "$REGION")
echo "Inbound MySQL rule added to the MySQL security group"

# Create a MySQL instance
mysql_instance_id=$(aws ec2 run-instances --image-id ami-05b5a865c3579bbc4 --instance-type t2.micro --key-name nextcloud-simplon --user-data ./simplon-bdd.sh --security-group-ids "$mysql_sg_id" --subnet-id "$private_subnet_id" --region "$REGION" --query 'Instances[0].InstanceId' --output text)
echo "MySQL instance created with ID: $mysql_instance_id"

# Create a security group for the Nextcloud instance
nextcloud_sg_id=$(aws ec2 create-security-group --group-name nextcloud-security-group --description "Nextcloud Security Group" --vpc-id "$vpc_id" --region "$REGION" --query 'GroupId' --output text)
echo "Nextcloud security group created with ID: $nextcloud_sg_id"

# Add inbound HTTP and HTTPS rules to the Nextcloud security group
nextcloud_rule1=$(aws ec2 authorize-security-group-ingress --group-id "$nextcloud_sg_id" --protocol tcp --port 80 --source-group "$bastion_sg_id" --region "$REGION")
nextcloud_rule2=$(aws ec2 authorize-security-group-ingress --group-id "$nextcloud_sg_id" --protocol tcp --port 443 --source-group "$bastion_sg_id" --region "$REGION")
echo "Inbound HTTP and HTTPS rules added to the Nextcloud security group"

# Create a Nextcloud instance
nextcloud_instance_id=$(aws ec2 run-instances --image-id ami-05b5a865c3579bbc4 --instance-type t2.medium --key-name nextcloud-simplon --user-data ./simplon-nc.sh --security-group-ids "$nextcloud_sg_id" --subnet-id "$private_subnet_id" --region "$REGION" --associate-public-ip-address --query 'Instances[0].InstanceId' --output text)
echo "Nextcloud instance created with ID: $nextcloud_instance_id"

# Wait for the instances to be running
aws ec2 wait instance-running --instance-ids "$bastion_instance_id" --region "$REGION"
aws ec2 wait instance-running --instance-ids "$mysql_instance_id" --region "$REGION"
aws ec2 wait instance-running --instance-ids "$nextcloud_instance_id" --region "$REGION"

# Retrieve the public IP address of the bastion instance
bastion_public_ip=$(aws ec2 describe-instances --instance-ids "$bastion_instance_id" --region "$REGION" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Bastion public IP: $bastion_public_ip"

# Display success message
echo "Infrastructure setup completed successfully!"