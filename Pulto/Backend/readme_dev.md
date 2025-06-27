# Spatial Data Visualization System - Development Environment

A comprehensive spatial data visualization system built with FastAPI, RealityKit, and SwiftUI. This repository provides both backend services for processing Jupyter notebooks and spatial data, and infrastructure for local development.

## 🏗️ Architecture

- **Backend**: FastAPI server for notebook processing and spatial data handling
- **Frontend**: SwiftUI + RealityKit for macOS/VisionOS spatial visualization
- **Storage**: PostgreSQL for metadata, Redis for caching, MinIO for object storage
- **Data Processing**: Jupyter notebook execution with matplotlib chart extraction
- **Spatial Format**: Custom nbformat extensions for VisionOS environments

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Make (for convenient commands)
- Terraform (optional, for infrastructure as code)
- Python 3.12+ (for local development)

### Option 1: Docker Compose (Recommended)

```bash
# Clone the repository
git clone <your-repo-url>
cd spatial-visualization

# Copy environment configuration
cp .env.example .env

# Start development environment
make dev

# Access services:
# - API Server: http://localhost:8000
# - API Documentation: http://localhost:8000/docs
# - Jupyter: http://localhost:8888
# - MinIO Console: http://localhost:9001
```

### Option 2: Terraform (Infrastructure as Code)

```bash
# Initialize Terraform
make init-tf

# Plan deployment
make plan-tf

# Deploy infrastructure
make deploy-tf

# Check status
make status
```

## 📋 Available Commands

### Development Commands
```bash
make dev          # Initialize and start development environment
make up           # Start all services
make down         # Stop all services
make restart      # Restart all services
make logs         # View logs from all services
make status       # Show service status
```

### Code Quality
```bash
make test         # Run tests
make lint         # Run code linting
make format       # Format code with black
```

### Database Operations
```bash
make shell-postgres  # Open PostgreSQL shell
make backup-db      # Backup database
make seed           # Seed database with sample data
```

### Maintenance
```bash
make clean        # Clean Docker resources
make clean-all    # Deep clean (including images)
make health       # Check service health
```

## 🔧 Configuration

### Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
# Key configurations
ENVIRONMENT=development
LOG_LEVEL=debug
DATABASE_URL=postgresql://spatial_user:spatial_pass@postgres:5432/spatial_viz
REDIS_URL=redis://redis:6379
```

### Terraform Variables

Create `terraform/terraform.tfvars`:

```hcl
app_port = 8000
redis_port = 6379
postgres_port = 5432
environment = "local"
project_name = "spatial-viz"
enable_postgres = true
enable_redis = true
```

## 🛠️ Development Workflow

### 1. Backend Development

The FastAPI backend provides endpoints for:
- Converting Jupyter notebooks to spatial formats
- Extracting charts and visualizations
- Managing VisionOS spatial window data
- Processing point cloud and 3D data

Key endpoints:
- `POST /convert/{notebook_name}` - Convert notebook
- `GET /notebooks/{notebook_name}` - Get notebook info
- `PUT /notebooks/{notebook_name}/cells/{cell_index}/spatial` - Update spatial position

### 2. Frontend Development (SwiftUI + RealityKit)

The Swift frontend connects to the backend API:

```swift
// Example API integration
struct NotebookService {
    func convertNotebook(_ data: Data) async throws -> ConversionResult {
        // API call to backend
    }
    
    func updateSpatialPosition(_ position: SpatialPosition) async throws {
        // Update cell position via API
    }
}
```

### 3. Spatial Data Format

Custom nbformat extension for VisionOS:

```json
{
  "metadata": {
    "visionos_export": {
      "version": "1.0",
      "coordinate_system": "meters",
      "precision": 6
    }
  },
  "cells": [
    {
      "metadata": {
        "visionos_window": {
          "id": "window_1",
          "type": "chart",
          "position": {"x": 1.0, "y": 1.0, "z": 1.0},
          "rotation": {"pitch": 0.0, "yaw": 0.0, "roll": 0.0}
        }
      }
    }
  ]
}
```

## 📊 Services

### FastAPI Backend
- **Port**: 8000
- **Health**: http://localhost:8000/health
- **Docs**: http://localhost:8000/docs
- **Features**: Hot reload, automatic dependency injection, async processing

### PostgreSQL Database
- **Port**: 5432
- **Database**: spatial_viz
- **User**: spatial_user / spatial_pass
- **Features**: Spatial extensions, JSON support, full-text search

### Redis Cache
- **Port**: 6379
- **Usage**: Session storage, chart caching, spatial data caching
- **Configuration**: LRU eviction, AOF persistence

### Jupyter Notebook
- **Port**: 8888
- **Token**: Disabled for development
- **Features**: SciPy stack, spatial visualization libraries

### MinIO (S3-compatible)
- **API Port**: 9000
- **Console**: http://localhost:9001
- **Credentials**: minioadmin / minioadmin123
- **Usage**: Notebook storage, chart assets, backup storage

## 🧪 Testing

### Running Tests
```bash
# All tests
make test

# Specific test module
docker-compose exec spatial-viz-app python -m pytest tests/test_notebook_conversion.py -v

# With coverage
docker-compose exec spatial-viz-app python -m pytest --cov=backend tests/
```

### Test Structure
```
tests/
├── test_api_endpoints.py      # API endpoint tests
├── test_notebook_conversion.py # Notebook processing tests
├── test_spatial_data.py       # VisionOS spatial data tests
├── test_chart_extraction.py   # Chart extraction tests
└── fixtures/                  # Test data and fixtures
    ├── sample_notebook.ipynb
    ├── visionos_notebook.ipynb
    └── test_charts/
```

## 🔍 Debugging

### Viewing Logs
```bash
# All services
make logs

# Specific service
docker-compose logs -f spatial-viz-app
docker-compose logs -f postgres
docker-compose logs -f redis
```

### Debugging the App
```bash
# Open shell in app container
make shell

# Python REPL with app context
docker-compose exec spatial-viz-app python -c "from backend import app; import IPython; IPython.embed()"
```

### Database Debugging
```bash
# PostgreSQL shell
make shell-postgres

# View tables
\dt

# Check spatial data
SELECT * FROM spatial_positions;
```

## 🚀 Production Deployment

### Building for Production
```bash
# Build production image
docker build -f Dockerfile.prod -t spatial-viz:prod .

# Use production compose file
docker-compose -f docker-compose.prod.yml up -d
```

### Environment Considerations
- Set `ENVIRONMENT=production`
- Use strong passwords and secrets
- Enable SSL/TLS
- Configure proper logging
- Set up monitoring and alerts
- Use managed databases and caches

## 📁 Project Structure

```
spatial-visualization/
├── backend.py                    # FastAPI application
├── requirements.txt              # Python dependencies
├── Dockerfile.dev               # Development Docker image
├── docker-compose.dev.yml       # Development services
├── Makefile                     # Development commands
├── .env.example                 # Environment template
├── terraform/                   # Infrastructure as code
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── scripts/                     # Utility scripts
│   ├── init-db.sql
│   └── seed_data.py
├── tests/                       # Test suite
├── notebooks/                   # Sample notebooks
├── data/                        # Application data
└── docs/                        # Documentation
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make changes and add tests
4. Run tests: `make test`
5. Commit changes: `git commit -m 'Add amazing feature'`
6. Push to branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Troubleshooting

### Common Issues

**Port conflicts:**
```bash
# Check what's using ports
lsof -i :8000
lsof -i :5432

# Change ports in .env or terraform.tfvars
```

**Docker issues:**
```bash
# Reset Docker state
make clean-all

# Rebuild everything
make build && make up
```

**Database connection issues:**
```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Reset database
docker-compose down -v
docker-compose up postgres
```

**Memory issues:**
```bash
# Check container resource usage
docker stats

# Increase Docker memory limits in Docker Desktop
```

### Getting Help

- Check the [API documentation](http://localhost:8000/docs)
- Review service logs: `make logs`
- Check service health: `make health`
- Open an issue on GitHub

---

**Happy coding! 🎉**