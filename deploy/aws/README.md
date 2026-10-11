# AWS deployment (ECS Fargate + OTel Collector)

This directory contains an ECS Fargate-oriented deployment recipe for the two-service observability stack with AWS native backends.

## Target architecture

- service-a in ECS Fargate
- service-b in ECS Fargate
- OTel Collector in ECS Fargate or EC2
- X-Ray for distributed tracing
- CloudWatch Logs for structured logs (with trace_id correlation)
- CloudWatch Metrics for metrics (alternative: Prometheus via managed Prometheus in AWS)
- Grafana Cloud or self-hosted Grafana connected to CloudWatch and X-Ray

## Prerequisites

- AWS CLI v2 installed and configured
- ECS cluster created (or use this script to create one)
- ECR repositories created (or created dynamically)
- IAM roles for ECS tasks with permissions to:
  - CloudWatch Logs (PutLogEvents)
  - X-Ray (WriteTraceData)
  - CloudWatch Metrics (PutMetricData)

```bash
aws ecr create-repository --repository-name otel-observability/service-a --region us-east-1
aws ecr create-repository --repository-name otel-observability/service-b --region us-east-1
aws ecr create-repository --repository-name otel-observability/otel-collector --region us-east-1
```

## Build and push images

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1
export ECR_REGISTRY=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Authenticate Docker to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build and push service-a
docker build -t $ECR_REGISTRY/otel-observability/service-a:latest ./service-a
docker push $ECR_REGISTRY/otel-observability/service-a:latest

# Build and push service-b
docker build -t $ECR_REGISTRY/otel-observability/service-b:latest ./service-b
docker push $ECR_REGISTRY/otel-observability/service-b:latest
```

## Deploy with CloudFormation or Terraform

Example CloudFormation template is provided in `ecs-fargate-stack.yaml`. Deploy it:

```bash
aws cloudformation create-stack \
  --stack-name otel-observability-stack \
  --template-body file://deploy/aws/ecs-fargate-stack.yaml \
  --parameters ParameterKey=Environment,ParameterValue=prod ParameterKey=ClusterName,ParameterValue=my-cluster \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## Environment variables for services

For service-a / service-b in ECS task definition:

```bash
SERVICE_NAME=service-a
OTEL_SERVICE_NAME=service-a
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector-internal-alb:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_RESOURCE_ATTRIBUTES=service.name=service-a,deployment.environment=aws,aws.ecs.cluster.name=my-cluster
SERVICE_B_URL=http://service-b-internal-alb:8000
DATABASE_URL=postgresql+psycopg2://postgres:password@rds-endpoint:5432/service_a
AWS_XRAY_TRACING_ENABLED=true
```

## OTel Collector exporters for AWS

The collector uses:
- **awsxray** exporter: sends traces to X-Ray
- **awscloudwatchlogs** exporter: sends logs to CloudWatch Logs
- **awsemf** exporter: sends metrics to CloudWatch (as Embedded Metric Format)
- **logging** exporter: debug logging to stdout

## Verify integration

1. **Traces**: Check AWS X-Ray console → Service map and trace details
2. **Logs**: CloudWatch Logs → Log Groups → `/ecs/otel-observability/service-a` or service-b
3. **Metrics**: CloudWatch → Metrics → browse custom namespaces like `OTelCollector` or `ServiceMetrics`
4. **Correlation**: Use trace_id from X-Ray to search logs in CloudWatch Logs Insights

## Example CloudWatch Logs Insights query

```sql
fields @timestamp, @message, trace_id, span_id, @log
| filter trace_id = "0x123456..."
| stats count() by span_id
```

## Notes

- For production, use RDS instead of local PostgreSQL.
- Configure VPC and security groups to restrict traffic between services and to the collector.
- Enable VPC Flow Logs for debugging network issues.
- Use AWS Secrets Manager to store database credentials and rotate them regularly.
- Set up alarms in CloudWatch for critical metrics (error rate, latency, OTel collector health).

## Example requests

```bash
ALB_ENDPOINT=$(aws elbv2 describe-load-balancers --names otel-service-a-alb --query 'LoadBalancers[0].DNSName' --output text)

curl -X POST http://$ALB_ENDPOINT/process \
  -H 'Content-Type: application/json' \
  -d '{"customer":"bob","item":"phone","quantity":1,"amount":800.00}'
```
