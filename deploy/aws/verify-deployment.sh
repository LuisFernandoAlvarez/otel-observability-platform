#!/bin/bash

# Script to verify AWS deployment
# Prerequisites: aws CLI, jq

set -e

STACK_NAME="otel-observability-stack"
REGION="us-east-1"

echo "=== Verifying OTel Observability AWS Deployment ==="

# Check CloudFormation stack status
echo "\n1. Checking CloudFormation stack status..."
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].StackStatus' \
  --output text)

echo "Stack Status: $STACK_STATUS"

if [ "$STACK_STATUS" != "CREATE_COMPLETE" ] && [ "$STACK_STATUS" != "UPDATE_COMPLETE" ]; then
  echo "Warning: Stack is not in a complete state."
fi

# Check ECS services
echo "\n2. Checking ECS services..."
CLUSTER_NAME=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' \
  --output text)

echo "Cluster: $CLUSTER_NAME"

for SERVICE in service-a service-b otel-collector; do
  RUNNING=$(aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE \
    --region $REGION \
    --query 'services[0].runningCount' \
    --output text 2>/dev/null || echo "0")
  
  echo "  - $SERVICE: $RUNNING running"
done

# Check X-Ray service map
echo "\n3. Checking X-Ray traces..."
TRACES=$(aws xray get-service-graph \
  --start-time $(date -d '5 minutes ago' +%s) \
  --end-time $(date +%s) \
  --region $REGION \
  --query 'ServiceGraph | length(@)' \
  --output text 2>/dev/null || echo "0")

echo "  Service graph nodes: $TRACES"

# Check CloudWatch Logs
echo "\n4. Checking CloudWatch Logs..."
for LOG_GROUP in /ecs/otel-observability/service-a /ecs/otel-observability/service-b /ecs/otel-observability/collector; do
  STREAMS=$(aws logs describe-log-streams \
    --log-group-name $LOG_GROUP \
    --region $REGION \
    --query 'logStreams | length(@)' \
    --output text 2>/dev/null || echo "0")
  
  echo "  - $LOG_GROUP: $STREAMS streams"
done

# Check CloudWatch Metrics
echo "\n5. Checking CloudWatch Metrics..."
METRICS=$(aws cloudwatch list-metrics \
  --namespace OTelCollector \
  --region $REGION \
  --query 'Metrics | length(@)' \
  --output text 2>/dev/null || echo "0")

echo "  OTelCollector namespace: $METRICS metrics"

echo "\n=== Verification Complete ==="
echo "\nNext steps:"
echo "1. Check X-Ray console: https://console.aws.amazon.com/xray/"
echo "2. Check CloudWatch Logs Insights: https://console.aws.amazon.com/cloudwatch/"
echo "3. Send test requests to the ALB endpoint"
