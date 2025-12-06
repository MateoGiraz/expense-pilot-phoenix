#!/bin/bash

AWS_REGION="us-east-1"
CLUSTER_NAME="expense-pilot-cluster"
NAMESPACE_NAME="expense-pilot.local"

echo "🚀 Enabling Service Discovery for ECS services..."

# 1. Check if namespace already exists
echo "📋 Checking if Cloud Map namespace exists..."
EXISTING_NAMESPACE=$(aws servicediscovery list-namespaces --filters Name=NAME,Values=${NAMESPACE_NAME} --query 'Namespaces[0].Id' --output text --region ${AWS_REGION} 2>/dev/null)

if [ "$EXISTING_NAMESPACE" != "None" ] && [ "$EXISTING_NAMESPACE" != "" ]; then
    echo "✅ Namespace already exists: ${EXISTING_NAMESPACE}"
    NAMESPACE_ID=$EXISTING_NAMESPACE
else
    echo "📋 Creating Cloud Map namespace..."
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text --region ${AWS_REGION})
    
    OPERATION_ID=$(aws servicediscovery create-private-dns-namespace \
        --name ${NAMESPACE_NAME} \
        --vpc ${VPC_ID} \
        --region ${AWS_REGION} \
        --query 'OperationId' --output text)

    echo "Waiting for namespace creation (Operation ID: ${OPERATION_ID})..."
    
    # Wait for operation to complete
    while true; do
        STATUS=$(aws servicediscovery get-operation --operation-id ${OPERATION_ID} --region ${AWS_REGION} --query 'Operation.Status' --output text)
        echo "Operation status: ${STATUS}"
        
        if [ "$STATUS" = "SUCCESS" ]; then
            break
        elif [ "$STATUS" = "FAIL" ]; then
            echo "❌ Namespace creation failed"
            exit 1
        fi
        
        sleep 5
    done

    # Get the namespace ID
    NAMESPACE_ID=$(aws servicediscovery list-namespaces --filters Name=NAME,Values=${NAMESPACE_NAME} --query 'Namespaces[0].Id' --output text --region ${AWS_REGION})
    echo "✅ Namespace created: ${NAMESPACE_ID}"
fi

# 2. Create services for each microservice
create_service_discovery() {
    local SERVICE_NAME=$1
    local PORT=$2
    
    echo "📋 Creating service discovery for: ${SERVICE_NAME}"
    
    # Check if service already exists
    EXISTING_SERVICE=$(aws servicediscovery list-services --filters Name=NAMESPACE_ID,Values=${NAMESPACE_ID} --query "Services[?Name=='${SERVICE_NAME}'].Id" --output text --region ${AWS_REGION} 2>/dev/null)
    
    if [ "$EXISTING_SERVICE" != "" ] && [ "$EXISTING_SERVICE" != "None" ]; then
        echo "✅ Service discovery for ${SERVICE_NAME} already exists"
    else
        aws servicediscovery create-service \
            --name ${SERVICE_NAME} \
            --dns-config "NamespaceId=${NAMESPACE_ID},DnsRecords=[{Type=A,TTL=300}]" \
            --health-check-custom-config FailureThreshold=1 \
            --region ${AWS_REGION} >/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✅ Created service discovery for: ${SERVICE_NAME}"
        else
            echo "❌ Failed to create service discovery for: ${SERVICE_NAME}"
        fi
    fi
}

# Create service discovery entries with correct container ports
create_service_discovery "api-gateway" "8080"
create_service_discovery "auth-service" "5439"
create_service_discovery "expenses-service" "4001"
create_service_discovery "expense-pilot" "4000"
create_service_discovery "audit-service" "3000"
create_service_discovery "notification-service" "8000"

echo ""
echo "✅ Service Discovery setup complete!"
echo ""
echo "🔧 Next steps:"
echo "1. Update GitHub Actions workflows to include service discovery"
echo "2. Redeploy services to enable service discovery"
echo ""
echo "Services will then be accessible as:"
echo "  - auth-service.expense-pilot.local:5439"
echo "  - api-gateway.expense-pilot.local:8080"  
echo "  - expenses-service.expense-pilot.local:4001"
echo "  - expense-pilot.expense-pilot.local:4000"
echo "  - audit-service.expense-pilot.local:3000"
echo "  - notification-service.expense-pilot.local:8000" 