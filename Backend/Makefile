#
//  Makefile
//  Pulto
//
//  Created by Joshua Herman on 6/27/25.
//  Copyright © 2025 Apple. All rights reserved.
//


# Makefile for Spatial Visualization Development Environment

.PHONY: help init up down logs shell test clean build deploy-tf destroy-tf status restart

# Default target
.DEFAULT_GOAL := help

# Variables
PROJECT_NAME := spatial-viz
ENVIRONMENT := local
TERRAFORM_DIR := ./terraform
DOCKER_COMPOSE_FILE := docker-compose.dev.yml

help: ## Show this help message
	@echo "Spatial Visualization Development Environment"
	@echo "============================================="
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize the development environment
	@echo "🚀 Initializing development environment..."
	@mkdir -p data notebooks temp scripts
	@touch scripts/init-db.sql
	@echo "-- Initial database setup" > scripts/init-db.sql
	@echo "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" >> scripts/init-db.sql
	@echo "✅ Environment initialized"

# Docker Compose Commands
up: ## Start all services with Docker Compose
	@echo "🐳 Starting services with Docker Compose..."
	@docker-compose -f $(DOCKER_COMPOSE_FILE) up -d
	@echo "✅ Services started"
	@echo "🌐 API available at: http://localhost:8000"
	@echo "📚 API docs at: http://localhost:8000/docs"
	@echo "🔧 Jupyter at: http://localhost:8888"

down: ## Stop all services
	@echo "🛑 Stopping services..."
	@docker-compose -f $(DOCKER_COMPOSE_FILE) down
	@echo "✅ Services stopped"

restart: ## Restart all services
	@echo "🔄 Restarting services..."
	@docker-compose -f $(DOCKER_COMPOSE_FILE) restart
	@echo "✅ Services restarted"

logs: ## Show logs from all services
	@docker-compose -f $(DOCKER_COMPOSE_FILE) logs -f

logs-app: ## Show logs from the app service only
	@docker-compose -f $(DOCKER_COMPOSE_FILE) logs -f spatial-viz-app

status: ## Show status of all services
	@echo "📊 Service Status:"
	@docker-compose -f $(DOCKER_COMPOSE_FILE) ps

shell: ## Open shell in the app container
	@docker-compose -f $(DOCKER_COMPOSE_FILE) exec spatial-viz-app /bin/bash

shell-postgres: ## Open PostgreSQL shell
	@docker-compose -f $(DOCKER_COMPOSE_FILE) exec postgres psql -U spatial_user -d spatial_viz

shell-redis: ## Open Redis CLI
	@docker-compose -f $(DOCKER_COMPOSE_FILE) exec redis redis-cli

# Terraform Commands
init-tf: ## Initialize Terraform
	@echo "🏗️  Initializing Terraform..."
	@cd $(TERRAFORM_DIR) && terraform init
	@echo "✅ Terraform initialized"

plan-tf: ## Plan Terraform deployment
	@echo "📋 Planning Terraform deployment..."
	@cd $(TERRAFORM_DIR) && terraform plan

deploy-tf: ## Deploy infrastructure with Terraform
	@echo "🚀 Deploying infrastructure with Terraform..."
	@cd $(TERRAFORM_DIR) && terraform apply -auto-approve
	@echo "✅ Infrastructure deployed"

destroy-tf: ## Destroy Terraform infrastructure
	@echo "💥 Destroying Terraform infrastructure..."
	@cd $(TERRAFORM_DIR) && terraform destroy -auto-approve
	@echo "✅ Infrastructure destroyed"

# Development Commands
build: ## Build the application Docker image
	@echo "🔨 Building application image..."
	@docker build -f Dockerfile.dev -t $(PROJECT_NAME):latest .
	@echo "✅ Image built"

test: ## Run tests
	@echo "🧪 Running tests..."
	@docker-compose -f $(DOCKER_COMPOSE_FILE) exec spatial-viz-app python -m pytest tests/ -v
	@echo "✅ Tests completed"

lint: ## Run code linting
	@echo "🔍 Running linting..."
	@docker-compose -f $(DOCKER_COMPOSE_FILE) exec spatial-viz-app black --check .
	@docker-compose -f $(DOCKER_COMPOSE_FILE) exec spatial-viz-app flake8 .
	@echo "✅ Linting completed"

format: ## Format code
	@echo "✨ Formatting code..."
	@docker-compose -f $(DOCKER_COMPOSE_FILE) exec spatial-viz-app black .
	@echo "✅ Code formatted"

# Data and Cleanup Commands
seed: ## Seed the database with sample data
	@echo "🌱 Seeding database..."
	@docker-compose -f $(DOCKER_COMPOSE_FILE) exec spatial-viz-app python scripts/seed_data.py
	@echo "✅ Database seeded"

clean: ## Clean up Docker resources
	@echo "🧹 Cleaning up Docker resources..."
	@docker-compose -f $(DOCKER_COMPOSE_FILE) down --volumes --remove-orphans
	@docker system prune -f
	@echo "✅ Cleanup completed"

clean-all: ## Clean up everything including images
	@echo "🧹 Deep cleaning Docker resources..."
	@docker-compose -f $(DOCKER_COMPOSE_FILE) down --volumes --remove-orphans
	@docker system prune -af
	@echo "✅ Deep cleanup completed"

# Backup and Restore Commands
backup-db: ## Backup PostgreSQL database
	@echo "💾 Backing up database..."
	@mkdir -p backups
	@docker-compose -f $(DOCKER_COMPOSE_FILE) exec postgres pg_dump -U spatial_user spatial_viz > backups/db_backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "✅ Database backed up"

backup-volumes: ## Backup Docker volumes
	@echo "💾 Backing up volumes..."
	@mkdir -p backups
	@docker run --rm -v spatial-viz-app-data:/data -v $(PWD)/backups:/backup alpine tar czf /backup/app_data_$(shell date +%Y%m%d_%H%M%S).tar.gz -C /data .
	@docker run --rm -v spatial-viz-notebook-storage:/data -v $(PWD)/backups:/backup alpine tar czf /backup/notebooks_$(shell date +%Y%m%d_%H%M%S).tar.gz -C /data .
	@echo "✅ Volumes backed up"

# Development Helpers
dev: init up ## Quick start for development (init + up)
	@echo "🎉 Development environment is ready!"
	@echo ""
	@echo "Available services:"
	@echo "  📡 API Server:     http://localhost:8000"
	@echo "  📚 API Docs:       http://localhost:8000/docs"
	@echo "  🔧 Jupyter:        http://localhost:8888"
	@echo "  🗄️  PostgreSQL:     localhost:5432"
	@echo "  🔴 Redis:          localhost:6379"
	@echo "  📦 MinIO:          http://localhost:9001 (admin/admin123)"

stop: down ## Alias for down

restart-app: ## Restart just the app service
	@docker-compose -f $(DOCKER_COMPOSE_FILE) restart spatial-viz-app

watch-logs: logs ## Alias for logs

# Health check
health: ## Check health of all services
	@echo "🏥 Checking service health..."
	@echo "API Server:"
	@curl -s http://localhost:8000/health || echo "❌ API Server not responding"
	@echo ""
	@echo "Redis:"
	@docker-compose -f $(DOCKER_COMPOSE_FILE) exec redis redis-cli ping || echo "❌ Redis not responding"
	@echo ""
	@echo "PostgreSQL:"
	@docker-compose -f $(DOCKER_COMPOSE_FILE) exec postgres pg_isready -U spatial_user || echo "❌ PostgreSQL not responding"