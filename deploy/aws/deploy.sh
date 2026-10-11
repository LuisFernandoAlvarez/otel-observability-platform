#!/bin/bash

# Script to deploy OTel stack to AWS ECS Fargate
# Prerequisites: aws CLI, docker, ECR repositories created

set -e

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1
export ECR_REGISTRY=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
export ENVIRONMENT=prod
export CLUSTER_NAME=otel-observability

echo "=== Building and pushing Docker images ==="
echo "ECR Registry: $ECR_REGISTRY"

# Authenticate Docker to ECR
echo "Authenticating to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build and push service-a
echo "\nBuilding and pushing service-a..."
docker build -t $ECR_REGISTRY/otel-observability/service-a:latest ./service-a
docker push $ECR_REGISTRY/otel-observability/service-a:latest

# Build and push service-b
echo "Building and pushing service-b..."
docker build -t $ECR_REGISTRY/otel-observability/service-b:latest ./service-b
docker push $ECR_REGISTRY/otel-observability/service-b:latest

echo "\n=== Deploying CloudFormation stack ==="

aws cloudformation deploy \
  --template-file deploy/aws/ecs-fargate-stack.yaml \
  --stack-name otel-observability-stack \
  --parameter-overrides \
    Environment=$ENVIRONMENT \
    ClusterName=$CLUSTER_NAME \
    VpcId=vpc-xxxxx \
    SubnetIds="subnet-xxxxx,subnet-xxxxx" \
    DatabaseEndpoint=db.example.us-east-1.rds.amazonaws.com \
    DatabaseName=postgres \
    DatabaseUser=postgres \
    DatabasePassword=YourPasswordHere \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $AWS_REGION \
  --no-fail-on-empty-changeset

echo "\n=== Deployment complete ==="
echo "\nNext: run ./deploy/aws/verify-deployment.sh to check the deployment status"
