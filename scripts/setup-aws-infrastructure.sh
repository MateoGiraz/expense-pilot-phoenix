#!/bin/bash

# AWS Infrastructure Setup Script
# Run this BEFORE deploying any services

AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="170107269579"

echo "🏗️  Setting up AWS infrastructure for Expense Pilot..."

# 1. Create ECS Task Execution Role (if it doesn't exist)
echo "📋 Creating ECS Task Execution Role..."
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ecs-tasks.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    --region ${AWS_REGION} 2>/dev/null || echo "Role already exists"

# Attach the policy
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
    --region ${AWS_REGION} 2>/dev/null || echo "Policy already attached"

# 2. Get VPC and subnet information
echo "🔍 Getting VPC and subnet information..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text --region ${AWS_REGION})
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --query 'Subnets[*].SubnetId' --output text --region ${AWS_REGION})
SUBNET_ARRAY=($SUBNET_IDS)
FIRST_SUBNET=${SUBNET_ARRAY[0]}

echo "Using VPC: ${VPC_ID}"
echo "Using Subnet: ${FIRST_SUBNET}"

# 3. Create Security Group for ECS services
echo "🔒 Creating security group..."
SG_ID=$(aws ec2 create-security-group \
    --group-name expense-pilot-ecs-sg \
    --description "Security group for Expense Pilot ECS services" \
    --vpc-id ${VPC_ID} \
    --query 'GroupId' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "Created security group: ${SG_ID}"
    
    # Add inbound rules for all our services
    aws ec2 authorize-security-group-ingress --group-id ${SG_ID} --protocol tcp --port 80 --cidr 0.0.0.0/0 --region ${AWS_REGION}
    aws ec2 authorize-security-group-ingress --group-id ${SG_ID} --protocol tcp --port 443 --cidr 0.0.0.0/0 --region ${AWS_REGION}
    aws ec2 authorize-security-group-ingress --group-id ${SG_ID} --protocol tcp --port 3000 --cidr 0.0.0.0/0 --region ${AWS_REGION}
    aws ec2 authorize-security-group-ingress --group-id ${SG_ID} --protocol tcp --port 4000 --cidr 0.0.0.0/0 --region ${AWS_REGION}
    aws ec2 authorize-security-group-ingress --group-id ${SG_ID} --protocol tcp --port 4001 --cidr 0.0.0.0/0 --region ${AWS_REGION}
    aws ec2 authorize-security-group-ingress --group-id ${SG_ID} --protocol tcp --port 5439 --cidr 0.0.0.0/0 --region ${AWS_REGION}
    aws ec2 authorize-security-group-ingress --group-id ${SG_ID} --protocol tcp --port 8000 --cidr 0.0.0.0/0 --region ${AWS_REGION}
    aws ec2 authorize-security-group-ingress --group-id ${SG_ID} --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region ${AWS_REGION}
    
    # Allow services to communicate with each other
    aws ec2 authorize-security-group-ingress --group-id ${SG_ID} --protocol tcp --port 0-65535 --source-group ${SG_ID} --region ${AWS_REGION}
else
    echo "Security group might already exist, getting existing one..."
    SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=expense-pilot-ecs-sg" --query 'SecurityGroups[0].GroupId' --output text --region ${AWS_REGION})
fi

# 4. Create databases in RDS
echo "📊 Creating databases in RDS instance..."
PGPASSWORD="expense-pilot-postgres" psql -h expense-pilot.c5buefi1ww4u.us-east-1.rds.amazonaws.com -U postgres -d postgres -c "CREATE DATABASE auth_service_db;" 2>/dev/null || echo "auth_service_db already exists"
PGPASSWORD="expense-pilot-postgres" psql -h expense-pilot.c5buefi1ww4u.us-east-1.rds.amazonaws.com -U postgres -d postgres -c "CREATE DATABASE expenses_service_db;" 2>/dev/null || echo "expenses_service_db already exists"
PGPASSWORD="expense-pilot-postgres" psql -h expense-pilot.c5buefi1ww4u.us-east-1.rds.amazonaws.com -U postgres -d postgres -c "CREATE DATABASE expense_pilot_dev;" 2>/dev/null || echo "expense_pilot_dev already exists"

# 5. Update deployment scripts with correct subnet and security group
echo "🔧 Updating deployment scripts with infrastructure details..."
sed -i.bak "s/subnet-12345/${FIRST_SUBNET}/g" deploy-*.sh
sed -i.bak "s/sg-12345/${SG_ID}/g" deploy-*.sh

# Clean up backup files
rm -f deploy-*.sh.bak

echo "✅ AWS Infrastructure setup complete!"
echo ""
echo "📝 Summary:"
echo "   VPC ID: ${VPC_ID}"
echo "   Subnet ID: ${FIRST_SUBNET}"
echo "   Security Group ID: ${SG_ID}"
echo "   ECS Cluster: expense-pilot-cluster"
echo ""
echo "🚀 You can now run the deployment scripts:"
echo "   ./deploy-api-gateway.sh"
echo "   ./deploy-auth-service.sh"
echo "   ./deploy-expenses-service.sh"
echo "   ./deploy-expense-pilot.sh"
echo "   ./deploy-audit-service.sh"
echo "   ./deploy-notification-service.sh" 