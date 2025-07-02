#!/bin/bash

# Deployment script for Spatial Data Visualization Backend
# Usage: ./deploy.sh [environment] [region]

set -e

# Configuration
APP_NAME="notebook-processor"
ENVIRONMENT="${1:-production}"
AWS_REGION="${2:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🚀 Deploying $APP_NAME to $ENVIRONMENT in $AWS_REGION"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    command -v aws >/dev/null 2>&1 || error "AWS CLI is required but not installed"
    command -v docker >/dev/null 2>&1 || error "Docker is required but not installed"
    command -v terraform >/dev/null 2>&1 || error "Terraform is required but not installed"
    
    # Check AWS credentials
    aws sts get-caller-identity >/dev/null 2>&1 || error "AWS credentials not configured"
    
    log "Prerequisites check passed ✅"
}

# Build and push Docker image
build_and_push_image() {
    log "Building and pushing Docker image..."
    
    ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
    
    # Login to ECR
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
    
    # Build image
    docker build -t $APP_NAME .
    docker tag $APP_NAME:latest $ECR_REPO:latest
    docker tag $APP_NAME:latest $ECR_REPO:$(git rev-parse --short HEAD)
    
    # Push image
    docker push $ECR_REPO:latest
    docker push $ECR_REPO:$(git rev-parse --short HEAD)
    
    log "Docker image pushed successfully ✅"
}

# Deploy infrastructure
deploy_infrastructure() {
    log "Deploying infrastructure with Terraform..."
    
    # Initialize Terraform
    terraform init
    
    # Plan deployment
    terraform plan \
        -var="app_name=$APP_NAME" \
        -var="environment=$ENVIRONMENT" \
        -var="aws_region=$AWS_REGION" \
        -out=tfplan
    
    # Apply deployment
    terraform apply tfplan
    
    log "Infrastructure deployed successfully ✅"
}

# Update ECS service
update_service() {
    log "Updating ECS service..."
    
    # Force new deployment
    aws ecs update-service \
        --cluster $APP_NAME \
        --service $APP_NAME \
        --force-new-deployment \
        --region $AWS_REGION
    
    # Wait for deployment to complete
    aws ecs wait services-stable \
        --cluster $APP_NAME \
        --services $APP_NAME \
        --region $AWS_REGION
    
    log "ECS service updated successfully ✅"
}

# Run health check
health_check() {
    log "Running health check..."
    
    ALB_DNS=$(terraform output -raw alb_hostname)
    
    # Wait a bit for the service to be ready
    sleep 30
    
    # Check health endpoint
    for i in {1..10}; do
        if curl -f "http://$ALB_DNS/health" >/dev/null 2>&1; then
            log "Health check passed ✅"
            log "Application is available at: http://$ALB_DNS"
            return 0
        fi
        warn "Health check attempt $i failed, retrying in 30 seconds..."
        sleep 30
    done
    
    error "Health check failed after 10 attempts"
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -f tfplan
}

# Main deployment flow
main() {
    log "Starting deployment of $APP_NAME"
    
    check_prerequisites
    build_and_push_image
    deploy_infrastructure
    update_service
    health_check
    cleanup
    
    log "🎉 Deployment completed successfully!"
    log "Your spatial data visualization backend is now running!"
    
    # Print useful information
    echo ""
    echo "📋 Deployment Summary:"
    echo "  Application: $APP_NAME"
    echo "  Environment: $ENVIRONMENT"
    echo "  Region: $AWS_REGION"
    echo "  Load Balancer: http://$(terraform output -raw alb_hostname)"
    echo ""
    echo "🔧 Useful commands:"
    echo "  View logs: aws logs tail /ecs/$APP_NAME --follow --region $AWS_REGION"
    echo "  Scale service: aws ecs update-service --cluster $APP_NAME --service $APP_NAME --desired-count <count> --region $AWS_REGION"
    echo "  Destroy infrastructure: terraform destroy"
}

# Set trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"
