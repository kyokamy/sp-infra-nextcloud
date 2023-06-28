# Infrastructure Setup Script

This bash script automates the setup of a basic infrastructure stack on AWS. It creates a Virtual Private Cloud (VPC), subnets, security groups, and instances for a bastion host, MySQL server, and Nextcloud server.

## Prerequisites

Before using this script, ensure that you have the following:

1. AWS CLI configured with appropriate access credentials. You can install and configure the AWS CLI by following the instructions in the [AWS CLI User Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html).

2. Create a key pair within AWS interface then keep it secure as we will need it through the process

## Usage

To use the script, follow these steps:

1. Open a terminal or command prompt.

2. Navigate to the directory where the script is located.

3. Make the script executable with the following command:
chmod +x simplon-infra.sh

4. Run the script with the following command:
./simplon-infra.sh

The script will start creating the infrastructure stack on AWS.

5. Monitor the script execution. It will provide progress updates and display the IDs of the created resources.

6. Once the script completes successfully, it will display a success message indicating that the infrastructure setup has been completed.

7. Access the bastion host instance by using the provided public IP address. Use the following command to SSH into the instance:
ssh -i <your-key-name.pem> ubuntu@<bastion-public-ip>

Replace `<bastion-public-ip>` with the actual public IP address of the bastion host instance.

8. From the bastion host, you can access the MySQL server and Nextcloud server instances within the private subnet. Use the private IP addresses of the respective instances for accessing them.

Enjoy automating your infrastructure setup with ease!