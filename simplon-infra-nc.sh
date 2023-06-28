#!/bin/bash

# Define variables
STACK_NAME="nils-infrastructure"
TEMPLATE_FILE="cloudformation-template.yml"
GITHUB_REPO="https://github.com/kyokamy/sp-infra-nextcloud"
REGION="eu-west-1"

# Generate a unique suffix for resource names
RESOURCE_SUFFIX=$(date +%s)

# Create a CloudFormation stack with a unique name
STACK_NAME="$STACK_NAME-$RESOURCE_SUFFIX"

# Create the CloudFormation template file
cat <<EOF > "$TEMPLATE_FILE"
---
AWSTemplateFormatVersion: '2010-09-09'
Description: Nils Infrastructure

Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16

  PublicSubnet:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.0.0/24

  PrivateSubnet:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.1.0/24

  InternetGateway:
    Type: AWS::EC2::InternetGateway

  GatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC

  PublicRoute:
    Type: AWS::EC2::Route
    DependsOn: GatewayAttachment
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  PublicSubnetRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet
      RouteTableId: !Ref PublicRouteTable

  PrivateRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC

  PrivateRoute:
    Type: AWS::EC2::Route
    DependsOn: GatewayAttachment
    Properties:
      RouteTableId: !Ref PrivateRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NatGateway

  PrivateSubnetRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnet
      RouteTableId: !Ref PrivateRouteTable

  NatGatewayEIP:
    Type: AWS::EC2::EIP

  NatGateway:
    Type: AWS::EC2::NatGateway
    Properties:
      SubnetId: !Ref PublicSubnet
      AllocationId: !GetAtt NatGatewayEIP.AllocationId

  BastionSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Bastion Security Group
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 10022
          ToPort: 10022
          CidrIp: 0.0.0.0/0

  BastionInstance:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: ami-05b5a865c3579bbc4
      InstanceType: t1.micro
      KeyName: nextcloud-simplon.pem
      SecurityGroupIds:
        - !Ref BastionSecurityGroup
      SubnetId: !Ref PublicSubnet
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          # Script for Bastion instance
          # Add your custom installation and configuration commands here
          git clone $GITHUB_REPO /path/to/repository

  MySQLSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: MySQL Security Group
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 3306
          ToPort: 3306
          SourceSecurityGroupId: !Ref BastionSecurityGroup

  MySQLInstance:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: ami-05b5a865c3579bbc4
      InstanceType: t1.micro
      KeyName: nextcloud-simplon.pem
      SecurityGroupIds:
        - !Ref MySQLSecurityGroup
      SubnetId: !Ref PrivateSubnet
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          # Script for MySQL instance
          # Add your custom installation and configuration commands here
          git clone $GITHUB_REPO /path/to/repository

  NextcloudSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Nextcloud Security Group
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0

  NextcloudInstance:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: ami-05b5a865c3579bbc4
      InstanceType: t1.medium
      KeyName: nextcloud-simplon.pem
      SecurityGroupIds:
        - !Ref NextcloudSecurityGroup
      SubnetId: !Ref PublicSubnet
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          # Script for Nextcloud instance
          # Add your custom installation and configuration commands here
          git clone $GITHUB_REPO /path/to/repository

  # Add a CloudFormation rollback trigger
  RollbackTrigger:
    Type: AWS::CloudFormation::WaitConditionHandle

  StackTerminationProtection:
    Type: AWS::CloudFormation::Stack
    Properties:
      StackName: !Ref "AWS::StackName"
      EnableTerminationProtection: true
      DependsOn: RollbackTrigger

# ... continue with other resource definitions ...

# Create the CloudFormation stack
aws cloudformation create-stack --stack-name "$STACK_NAME" \
  --template-body file://"$TEMPLATE_FILE" \
  --capabilities CAPABILITY_IAM

# Wait for the stack creation to complete
aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" \
  && echo "Stack creation complete!" \
  || {
    echo "Error creating stack. Rolling back..."
    aws cloudformation delete-stack --stack-name "$STACK_NAME"
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"
    echo "Stack rollback complete!"
    exit 1
  }

# Get stack outputs
outputs=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs")

echo "Stack outputs:"
echo "$outputs"