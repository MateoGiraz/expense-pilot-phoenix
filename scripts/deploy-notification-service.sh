#!/bin/bash

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="170107269579"
CLUSTER_NAME="expense-pilot-cluster"
SERVICE_NAME="notification-service"
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/expense-pilot/notification-service"

echo "🚀 Deploying Notification Service to ECS..."

# Build and push Docker image
echo "📦 Building Docker image..."
cd notification-service
docker build -t ${SERVICE_NAME} .

# Tag for ECR
docker tag ${SERVICE_NAME}:latest ${ECR_REPO}:latest

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO}

# Push to ECR
echo "📤 Pushing to ECR..."
docker push ${ECR_REPO}:latest

# Create task definition
echo "📋 Creating task definition..."
cat > task-definition.json << EOF
{
  "family": "${SERVICE_NAME}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "${SERVICE_NAME}",
      "image": "${ECR_REPO}:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "PORT",
          "value": "8000"
        },
        {
          "name": "AWS_ACCESS_KEY_ID",
          "value": "${{ secrets.AWS_ACCESS_KEY_ID }}"
        },
        {
          "name": "AWS_SECRET_ACCESS_KEY",
          "value": "${{ secrets.AWS_SECRET_ACCESS_KEY }}"
        },
        {
          "name": "AWS_REGION",
          "value": "us-east-1"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/${SERVICE_NAME}",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF

# Create log group
aws logs create-log-group --log-group-name "/ecs/${SERVICE_NAME}" --region ${AWS_REGION} 2>/dev/null || true

# Register task definition
echo "📝 Registering task definition..."
aws ecs register-task-definition --cli-input-json file://task-definition.json --region ${AWS_REGION}

# Create or update service
echo "🔄 Creating/updating ECS service..."
SERVICE_EXISTS=$(aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION} --query 'services[0].serviceName' --output text 2>/dev/null)

if [ "$SERVICE_EXISTS" = "${SERVICE_NAME}" ]; then
    echo "Updating existing service..."
    aws ecs update-service --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --task-definition ${SERVICE_NAME} --region ${AWS_REGION}
else
    echo "Creating new service..."
    aws ecs create-service \
        --cluster ${CLUSTER_NAME} \
        --service-name ${SERVICE_NAME} \
        --task-definition ${SERVICE_NAME} \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[subnet-0a8dc37c19196cf3b],securityGroups=[sg-0e2a0b66841492356],assignPublicIp=ENABLED}" \
        --region ${AWS_REGION}
fi

# Clean up
rm task-definition.json
cd ..

echo "✅ Notification Service deployment complete!"
echo "🔍 Check status: aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION}" 