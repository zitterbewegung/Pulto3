# Spatial Data Visualization Backend

A Flask-based backend service for processing Jupyter notebooks with spatial metadata and 3D visualization support for Swift/RealityKit applications.

## 🚀 Features

- **Notebook Processing**: Parse and validate Jupyter notebooks with nbformat support
- **Chart Generation**: Extract matplotlib charts and return as base64-encoded images
- **Spatial Metadata**: Store and retrieve 3D positioning data (x, y, z, pitch, yaw, roll)
- **Multi-format Support**: Handle PNG, JPEG images and various data formats
- **Production Ready**: Docker containerization with AWS ECS deployment
- **Real-time Updates**: REST API for updating spatial positioning from Swift clients

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Swift Client  │────│  Flask Backend  │────│  Jupyter Files  │
│   (RealityKit)  │    │   (Processing)  │    │   (Storage)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                       ┌─────────────────┐
                       │  AWS ECS/ALB    │
                       │  (Production)   │
                       └─────────────────┘
```

## 🚦 Quick Start

### Local Development

1. **Setup Development Environment**:
   ```bash
   chmod +x dev-setup.sh
   ./dev-setup.sh
   ```

2. **Start Development Server**:
   ```bash
   ./run-dev.sh
   ```

3. **Test the API**:
   ```bash
   ./test-backend.sh
   ```

### Docker Development

1. **Using Docker Compose**:
   ```bash
   docker-compose up -d
   ```

2. **Access Services**:
   - Backend API: http://localhost:8000
   - Jupyter Lab: http://localhost:8888 (token: `spatial-dev-token`)
   - Nginx Proxy: http://localhost (routes to backend)

## 📡 API Endpoints

### Core Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check |
| `GET` | `/notebooks` | List all notebooks |
| `POST` | `/convert/<name>` | Process notebook and extract charts |
| `POST` | `/process_notebook` | Validate and extract all outputs |

### Spatial Metadata

| Method | Endpoint | Description |
|--------|----------|-------------|
| `PUT` | `/notebooks/<name>/cells/<index>/spatial` | Update cell spatial data |
| `PUT` | `/notebooks/<name>/cells/spatial` | Update all cells spatial data |
| `GET` | `/notebooks/<name>` | Get notebook with metadata |

### Example Requests

**Health Check**:
```bash
curl http://localhost:8000/health
```

**Upload Notebook**:
```bash
curl -X POST -F "file=@notebook.ipynb" \
     http://localhost:8000/convert/my_notebook
```

**Update Spatial Metadata**:
```bash
curl -X PUT http://localhost:8000/notebooks/my_notebook.ipynb/cells/0/spatial \
     -H "Content-Type: application/json" \
     -d '{"x": 100, "y": 200, "z": 50, "pitch": 0, "yaw": 45, "roll": 0}'
```

## 🐳 Deployment

### AWS Production Deployment

1. **Prerequisites**:
   - AWS CLI configured
   - Docker installed
   - Terraform installed

2. **Deploy to AWS**:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh production us-east-1
   ```

3. **Monitor Deployment**:
   ```bash
   # View logs
   aws logs tail /ecs/notebook-processor --follow
   
   # Check service status
   aws ecs describe-services --cluster notebook-processor --services notebook-processor
   ```

### Manual Docker Deployment

1. **Build Image**:
   ```bash
   docker build -t spatial-backend .
   ```

2. **Run Container**:
   ```bash
   docker run -d -p 8000:5000 \
     -e FLASK_ENV=production \
     -v ./notebooks:/tmp/notebooks \
     spatial-backend
   ```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FLASK_ENV` | Environment (development/production) | `production` |
| `FLASK_DEBUG` | Enable debug mode | `False` |
| `UPLOAD_FOLDER` | Notebook storage path | `/tmp/notebooks` |

### Swift Client Configuration

Update your Swift client to point to the deployed backend:

```swift
// For local development
let baseURL = "http://localhost:8000"

// For production
let baseURL = "http://your-alb-dns-name.amazonaws.com"
```

## 📊 Data Formats

### Spatial Metadata Format

```json
{
  "x": 100.0,
  "y": 200.0,
  "z": 50.0,
  "pitch": 0.0,
  "yaw": 45.0,
  "roll": 0.0
}
```

### Notebook Response Format

```json
{
  "nbformat": 4,
  "nbformat_minor": 4,
  "cells": [...],
  "metadata": {
    "chartPositions": {
      "chartKey_001": {"x": 120.0, "y": -80.0}
    },
    "visionos_export": {
      "export_date": "2025-06-28T10:00:00Z",
      "total_windows": 2,
      "window_types": ["Charts", "Spatial"]
    }
  }
}
```

### Chart Images Response

```json
{
  "chartKey_001": ["base64-encoded-image-data"],
  "chartKey_002": ["base64-encoded-image-data"]
}
```

## 🧪 Testing

### Unit Tests

```bash
# Activate virtual environment
source venv/bin/activate

# Run tests
python -m pytest tests/

# Run with coverage
python -m pytest --cov=backend tests/
```

### Integration Tests

```bash
# Test all endpoints
./test-backend.sh

# Test with custom base URL
./test-backend.sh https://your-domain.com
```

### Load Testing

```bash
# Install Apache Bench
sudo apt-get install apache2-utils

# Test health endpoint
ab -n 1000 -c 10 http://localhost:8000/health

# Test notebook upload
ab -n 100 -c 5 -p sample.ipynb -T application/octet-stream \
   http://localhost:8000/convert/test
```

## 🔍 Monitoring

### Logging

- **Development**: Console output with debug information
- **Production**: CloudWatch logs in `/ecs/notebook-processor`

### Metrics

Key metrics to monitor:
- Response time for `/convert` endpoints
- Memory usage during chart generation
- File upload success rates
- Spatial metadata update frequency

### Health Checks

The `/health` endpoint provides:
```json
{
  "status": "healthy",
  "service": "notebook-processor"
}
```

## 🛠️ Development

### Project Structure

```
backend/
├── backend.py              # Main Flask application
├── requirements.txt        # Python dependencies
├── Dockerfile             # Container configuration
├── docker-compose.yml     # Local development stack
├── main.tf               # Terraform infrastructure
├── deploy.sh             # Deployment script
├── dev-setup.sh          # Development setup
├── nginx.conf            # Reverse proxy config
└── temp/
    └── notebooks/        # Local notebook storage
```

### Adding New Features

1. **New API Endpoint**:
   ```python
   @app.route('/new-endpoint', methods=['POST'])
   def new_feature():
       # Implementation
       return jsonify({'result': 'success'})
   ```

2. **Update Swift Client**:
   ```swift
   func callNewEndpoint() async {
       let url = URL(string: "\(baseURL)/new-endpoint")!
       // Implementation
   }
   ```

3. **Add Tests**:
   ```bash
   # Add to test-backend.sh
   echo "Testing new endpoint..."
   curl -X POST "$BASE_URL/new-endpoint"
   ```

## 🔐 Security

### Production Security

- Non-root user in Docker container
- File upload size limits (50MB)
- Rate limiting via nginx
- Input validation and sanitization
- Secure filename handling

### Development Security

- Debug mode only in development
- Temporary file cleanup
- Error message sanitization

## 📚 Dependencies

### Core Dependencies

- **Flask**: Web framework
- **nbformat**: Jupyter notebook format support
- **matplotlib**: Chart generation
- **numpy**: Numerical computations
- **gunicorn**: Production WSGI server

### Optional Dependencies

- **Redis**: Caching layer
- **pytest**: Testing framework
- **nginx**: Reverse proxy

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Make changes and test: `./test-backend.sh`
4. Commit changes: `git commit -am 'Add new feature'`
5. Push to branch: `git push origin feature/new-feature`
6. Submit pull request

## 📄 License

This project is part of the Spatial Data Visualization system for Swift/RealityKit applications.

## 🆘 Troubleshooting

### Common Issues

**Port Already in Use**:
```bash
# Kill process using port 8000
lsof -ti:8000 | xargs kill -9
```

**Docker Build Fails**:
```bash
# Clean Docker cache
docker system prune -a
```

**AWS Deployment Issues**:
```bash
# Check Terraform state
terraform show

# Verify AWS credentials
aws sts get-caller-identity
```

**Chart Generation Fails**:
- Check matplotlib backend configuration
- Verify notebook cell syntax
- Review error logs for specific issues

### Getting Help

- Check the health endpoint: `/health`
- Review application logs
- Test with sample notebooks in `temp/notebooks/`
- Use the test script: `./test-backend.sh`

---

For more information about the Swift client integration, see the main project documentation.