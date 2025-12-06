#!/bin/bash

echo "🔍 Checking ECS Service Discovery Configuration..."

AWS_REGION="us-east-1"
CLUSTER_NAME="expense-pilot-cluster"

# Check if services have service discovery enabled
echo "📋 Checking auth-service configuration..."
aws ecs describe-services --cluster ${CLUSTER_NAME} --services auth-service --region ${AWS_REGION} --query 'services[0].serviceRegistries' --output table

echo ""
echo "📋 Checking api-gateway configuration..."
aws ecs describe-services --cluster ${CLUSTER_NAME} --services api-gateway --region ${AWS_REGION} --query 'services[0].serviceRegistries' --output table

echo ""
echo "📋 Service status summary..."
aws ecs describe-services --cluster ${CLUSTER_NAME} --services auth-service api-gateway expense-pilot --region ${AWS_REGION} --query 'services[*].{Name:serviceName,Running:runningCount,Desired:desiredCount,Status:status}' --output table

echo ""
echo "📋 Checking if Cloud Map namespace exists..."
aws servicediscovery list-namespaces --output table 