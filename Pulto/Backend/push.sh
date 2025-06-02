#!/bin/bash
# Get the ECR repository URL from Terraform output
export ECR_URL=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL

# Build and tag the image
docker build -t notebook-processor .
docker tag notebook-processor:latest $ECR_URL:latest

# Push to ECR
docker push $ECR_URL:latest

# Get the ALB hostname
echo "http://$(terraform output -raw alb_hostname)"
