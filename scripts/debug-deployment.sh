#!/bin/bash

AWS_REGION="us-east-1"
CLUSTER_NAME="expense-pilot-cluster"

echo "🔧 Debugging ECS Deployment Issues..."

# 1. Check if cluster exists
echo "📋 Checking ECS Cluster..."
aws ecs describe-clusters --clusters ${CLUSTER_NAME} --region ${AWS_REGION} --query 'clusters[0].{Name:clusterName,Status:status,ActiveServices:activeServicesCount,RunningTasks:runningTasksCount}' --output table

# 2. List all services in the cluster
echo ""
echo "📋 Listing all services in cluster..."
aws ecs list-services --cluster ${CLUSTER_NAME} --region ${AWS_REGION} --output table

# 3. Check task definitions
echo ""
echo "📋 Checking task definitions..."
aws ecs list-task-definitions --family-prefix audit-service --region ${AWS_REGION} --query 'taskDefinitionArns[-1:]' --output table
aws ecs list-task-definitions --family-prefix notification-service --region ${AWS_REGION} --query 'taskDefinitionArns[-1:]' --output table

# 4. Check ECR repositories
echo ""
echo "📦 Checking ECR repositories..."
aws ecr describe-repositories --region ${AWS_REGION} --query 'repositories[*].{Name:repositoryName,URI:repositoryUri}' --output table

# 5. Check task execution role
echo ""
echo "🔐 Checking ECS task execution role..."
aws iam get-role --role-name ecsTaskExecutionRole --query 'Role.{RoleName:RoleName,Arn:Arn,CreateDate:CreateDate}' --output table 2>/dev/null || echo "❌ ecsTaskExecutionRole not found"

# 6. Check recent CloudWatch logs for any errors
echo ""
echo "📊 Checking recent CloudWatch logs..."
aws logs describe-log-groups --log-group-name-prefix "/ecs/" --region ${AWS_REGION} --query 'logGroups[*].{LogGroup:logGroupName,CreationTime:creationTime}' --output table

echo ""
echo "✅ Debug complete! Check the output above for any issues." 