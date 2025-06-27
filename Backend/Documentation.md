# Terraform Infrastructure for Spatial Data Visualization System

This Terraform configuration deploys a containerized backend infrastructure to support your Swift/RealityKit spatial data visualization application that processes volumetric spaces and point cloud data from Jupyter notebooks.

## Architecture Overview

- **ECS Fargate**: Serverless container hosting for your notebook processor
- **Application Load Balancer**: High-availability traffic distribution
- **ECR Repository**: Container image storage
- **Auto Scaling**: Automatic scaling based on CPU utilization (1-4 containers)
- **VPC**: Isolated network environment with public subnets
- **CloudWatch**: Centralized logging and monitoring


## terraform.tfvars

```hcl
app_name       = "notebook-processor"
environment    = "production"
aws_region     = "us-east-1"
app_count      = 2
fargate_cpu    = "512"
fargate_memory = "1024"
```

## Deployment Instructions

### Prerequisites
1. **AWS CLI configured** with proper credentials
2. **Terraform installed** (version ~> 1.0)
3. **Docker installed** for building container images

### Steps

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Plan deployment**:
   ```bash
   terraform plan
   ```

3. **Apply configuration**:
   ```bash
   terraform apply
   ```

4. **Build and push Docker image**:
   ```bash
   chmod +x push.sh
   ./push.sh
   ```

### AWS Credentials Setup

Choose one of these methods:

**Option 1: AWS CLI**
```bash
aws configure
```

**Option 2: Environment Variables**
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"
```

**Option 3: Credentials File**
Create `~/.aws/credentials`:
```ini
[default]
aws_access_key_id = your-access-key-id
aws_secret_access_key = your-secret-access-key
```

## Integration with Swift/RealityKit App

Once deployed, your spatial data visualization application will:

1. **Send HTTP requests** to the ALB endpoint for notebook processing
2. **Receive processed volumetric data** in JSON format compatible with your Swift app
3. **Render 3D spatial visualizations** using RealityKit with the processed point cloud data
4. **Handle real-time updates** through the load-balanced backend infrastructure

The backend processes Jupyter notebook nbformat files containing spatial metadata and returns structured data for your macOS application's 3D rendering pipeline.

## Troubleshooting

- **Credential errors**: Ensure AWS credentials are properly configured
- **Region issues**: Verify the AWS region supports all required services
- **Resource limits**: Check AWS account limits for ECS, ECR, and networking resources
- **Container health**: Monitor CloudWatch logs for application startup issues

## Runbook - Operations and Maintenance

### Daily Operations

#### Health Check Procedures
```bash
# Check ECS service status
aws ecs describe-services --cluster notebook-processor-cluster --services notebook-processor-service

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn $(terraform output -raw target_group_arn)

# Check recent CloudWatch logs
aws logs tail /ecs/notebook-processor --follow

# Test application endpoint
curl -f http://$(terraform output -raw alb_hostname)/health
```

#### Monitor Key Metrics
```bash
# CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=notebook-processor-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Memory utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=notebook-processor-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Scaling Operations

#### Manual Scaling
```bash
# Scale up to 4 instances
aws ecs update-service \
  --cluster notebook-processor-cluster \
  --service notebook-processor-service \
  --desired-count 4

# Scale down to 1 instance
aws ecs update-service \
  --cluster notebook-processor-cluster \
  --service notebook-processor-service \
  --desired-count 1
```

#### Auto Scaling Configuration
```bash
# Check current auto scaling settings
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-ids service/notebook-processor-cluster/notebook-processor-service

# Modify auto scaling policy
aws application-autoscaling put-scaling-policy \
  --policy-name notebook-processor-scale-up \
  --service-namespace ecs \
  --resource-id service/notebook-processor-cluster/notebook-processor-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

### Deployment Operations

#### Rolling Deployment
```bash
# Build and push new image
export ECR_URL=$(terraform output -raw ecr_repository_url)
docker build -t notebook-processor .
docker tag notebook-processor:latest $ECR_URL:latest
docker push $ECR_URL:latest

# Force new deployment (rolling update)
aws ecs update-service \
  --cluster notebook-processor-cluster \
  --service notebook-processor-service \
  --force-new-deployment
```

#### Blue/Green Deployment
```bash
# Create new task definition with new image
aws ecs register-task-definition \
  --family notebook-processor \
  --cli-input-json file://updated-task-definition.json

# Update service with new task definition
aws ecs update-service \
  --cluster notebook-processor-cluster \
  --service notebook-processor-service \
  --task-definition notebook-processor:NEW_REVISION
```

### Troubleshooting Procedures

#### Common Issues and Solutions

**Issue: Service won't start**
```bash
# Check task definition and recent failures
aws ecs describe-tasks \
  --cluster notebook-processor-cluster \
  --tasks $(aws ecs list-tasks --cluster notebook-processor-cluster --service-name notebook-processor-service --query 'taskArns[0]' --output text)

# Check CloudWatch logs for errors
aws logs filter-log-events \
  --log-group-name /ecs/notebook-processor \
  --start-time $(date -d '1 hour ago' +%s)000
```

**Issue: High memory usage**
```bash
# Check container insights
aws logs filter-log-events \
  --log-group-name /aws/ecs/containerinsights/notebook-processor-cluster/performance \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern "{ $.Type = \"Container\" && $.Memory > 80 }"
```

**Issue: Load balancer 5xx errors**
```bash
# Check ALB access logs (if enabled)
aws s3 ls s3://your-alb-logs-bucket/AWSLogs/$(aws sts get-caller-identity --query Account --output text)/elasticloadbalancing/us-east-1/

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --names notebook-processor-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
```

### Security Maintenance

#### Regular Security Tasks
```bash
# Check for security vulnerabilities in ECR
aws ecr describe-image-scan-findings \
  --repository-name notebook-processor \
  --image-id imageTag=latest

# Review security groups
aws ec2 describe-security-groups \
  --group-names notebook-processor-alb-* notebook-processor-ecs-tasks-*

# Check IAM role permissions
aws iam list-attached-role-policies \
  --role-name notebook-processor-ecsTaskExecutionRole
```

#### Security Incident Response
```bash
# Emergency: Block all traffic to ALB
aws ec2 authorize-security-group-ingress \
  --group-id $(aws ec2 describe-security-groups --filters "Name=group-name,Values=notebook-processor-alb-*" --query 'SecurityGroups[0].GroupId' --output text) \
  --protocol tcp \
  --port 80 \
  --source-group $(aws ec2 create-security-group --group-name emergency-block --description "Emergency block" --vpc-id $(terraform output -raw vpc_id) --query 'GroupId' --output text)

# Immediate service shutdown
aws ecs update-service \
  --cluster notebook-processor-cluster \
  --service notebook-processor-service \
  --desired-count 0
```

### Backup and Recovery

#### Backup Procedures
```bash
# Backup Terraform state
aws s3 cp terraform.tfstate s3://your-backup-bucket/terraform-state/$(date +%Y%m%d)/

# Export current task definition
aws ecs describe-task-definition \
  --task-definition notebook-processor \
  --query 'taskDefinition' > task-definition-backup-$(date +%Y%m%d).json

# Backup ECR images
docker pull $(terraform output -raw ecr_repository_url):latest
docker save $(terraform output -raw ecr_repository_url):latest | gzip > notebook-processor-$(date +%Y%m%d).tar.gz
```

#### Disaster Recovery
```bash
# Recreate infrastructure from backup
terraform init
terraform plan
terraform apply

# Restore container image
docker load < notebook-processor-backup.tar.gz
docker tag notebook-processor:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest

# Restore service
aws ecs update-service \
  --cluster notebook-processor-cluster \
  --service notebook-processor-service \
  --force-new-deployment
```

### Cost Optimization

#### Monthly Cost Review
```bash
# Check ECS service costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -d 'last month' +%Y-%m-01),End=$(date +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Optimize for lower costs
# Scale down during off-hours
aws events put-rule --name scale-down-evening --schedule-expression "cron(0 22 * * ? *)"
aws events put-rule --name scale-up-morning --schedule-expression "cron(0 8 * * ? *)"
```

#### Resource Optimization
```bash
# Right-size Fargate tasks based on utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=notebook-processor-service \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average,Maximum
```

### Emergency Procedures

#### Critical Issue Response Plan

1. **Assess Impact**
   ```bash
   curl -f http://$(terraform output -raw alb_hostname)/health
   aws ecs describe-services --cluster notebook-processor-cluster --services notebook-processor-service
   ```

2. **Immediate Mitigation**
   ```bash
   # Quick rollback to previous task definition
   aws ecs update-service \
     --cluster notebook-processor-cluster \
     --service notebook-processor-service \
     --task-definition notebook-processor:PREVIOUS_REVISION
   ```

3. **Communication**
   - Notify stakeholders via configured channels
   - Update status page if applicable
   - Document incident timeline

4. **Post-Incident**
   - Review CloudWatch logs and metrics
   - Conduct root cause analysis
   - Update runbook procedures as needed

### Monitoring and Alerting Setup

#### CloudWatch Alarms
```bash
# High CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "notebook-processor-high-cpu" \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2

# Application errors alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "notebook-processor-errors" \
  --alarm-description "Alert on application errors" \
  --metric-name HTTPCode_Target_5XX_Count \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

## Cleanup

To destroy the infrastructure:
```bash
terraform destroy
```
