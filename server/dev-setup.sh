#!/bin/bash

# Local Development Setup for Spatial Data Visualization Backend
# Usage: ./dev-setup.sh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[DEV] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[DEV] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[DEV] ERROR: $1${NC}"
    exit 1
}

# Check if Python 3.8+ is available
check_python() {
    log "Checking Python installation..."
    
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        log "Found Python $PYTHON_VERSION"
        
        # Check if version is 3.8+
        if python3 -c 'import sys; exit(0 if sys.version_info >= (3, 8) else 1)'; then
            log "Python version check passed ✅"
        else
            error "Python 3.8+ is required, found $PYTHON_VERSION"
        fi
    else
        error "Python 3 is not installed"
    fi
}

# Setup virtual environment
setup_venv() {
    log "Setting up virtual environment..."
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        log "Virtual environment created"
    else
        log "Virtual environment already exists"
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    log "Virtual environment activated"
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install dependencies
    log "Installing Python dependencies..."
    pip install -r requirements.txt
    
    log "Dependencies installed ✅"
}

# Create development configuration
create_dev_config() {
    log "Creating development configuration..."
    
    cat > dev-config.py << EOF
# Development Configuration
import os

class DevelopmentConfig:
    DEBUG = True
    TESTING = False
    
    # Flask settings
    SECRET_KEY = 'dev-secret-key-change-in-production'
    
    # Upload settings
    UPLOAD_FOLDER = './temp/notebooks'
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB max file size
    
    # CORS settings
    CORS_ORIGINS = ['http://localhost:3000', 'http://127.0.0.1:3000']
    
    # Logging
    LOG_LEVEL = 'DEBUG'

# Make upload directory
os.makedirs('./temp/notebooks', exist_ok=True)
EOF
    
    log "Development configuration created"
}

# Create sample notebooks for testing
create_sample_notebooks() {
    log "Creating sample notebooks for testing..."
    
    mkdir -p temp/notebooks
    
    # Sample notebook with matplotlib chart
    cat > temp/notebooks/sample_chart.ipynb << 'EOF'
{
 "cells": [
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {
    "spatial": {
     "x": 100,
     "y": 200,
     "z": 0,
     "pitch": 0,
     "yaw": 0,
     "roll": 0
    }
   },
   "outputs": [],
   "source": [
    "import matplotlib.pyplot as plt\n",
    "import numpy as np\n",
    "\n",
    "# Generate sample data\n",
    "x = np.linspace(0, 10, 100)\n",
    "y = np.sin(x)\n",
    "\n",
    "# Create plot\n",
    "plt.figure(figsize=(10, 6))\n",
    "plt.plot(x, y, 'b-', linewidth=2, label='sin(x)')\n",
    "plt.xlabel('X values')\n",
    "plt.ylabel('Y values')\n",
    "plt.title('Sample Sine Wave')\n",
    "plt.legend()\n",
    "plt.grid(True)\n",
    "plt.show()"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "name": "python",
   "version": "3.8.0"
  },
  "chartPositions": {
   "chartKey_001": {"x": 120.0, "y": -80.0}
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EOF

    # 3D visualization notebook
    cat > temp/notebooks/spatial_3d.ipynb << 'EOF'
{
 "cells": [
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {
    "spatial": {
     "x": -150,
     "y": 100,
     "z": -50,
     "pitch": 0,
     "yaw": 45,
     "roll": 0
    }
   },
   "outputs": [],
   "source": [
    "import matplotlib.pyplot as plt\n",
    "import numpy as np\n",
    "from mpl_toolkits.mplot3d import Axes3D\n",
    "\n",
    "# Generate 3D data\n",
    "fig = plt.figure(figsize=(12, 8))\n",
    "ax = fig.add_subplot(111, projection='3d')\n",
    "\n",
    "# Create a 3D surface\n",
    "x = np.linspace(-5, 5, 50)\n",
    "y = np.linspace(-5, 5, 50)\n",
    "X, Y = np.meshgrid(x, y)\n",
    "Z = np.sin(np.sqrt(X**2 + Y**2))\n",
    "\n",
    "# Plot surface\n",
    "surf = ax.plot_surface(X, Y, Z, cmap='viridis', alpha=0.8)\n",
    "ax.set_xlabel('X axis')\n",
    "ax.set_ylabel('Y axis')\n",
    "ax.set_zlabel('Z axis')\n",
    "ax.set_title('3D Spatial Visualization')\n",
    "\n",
    "plt.colorbar(surf)\n",
    "plt.show()"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "name": "python",
   "version": "3.8.0"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EOF
    
    log "Sample notebooks created ✅"
}

# Create run script
create_run_script() {
    log "Creating run script..."
    
    cat > run-dev.sh << 'EOF'
#!/bin/bash

# Activate virtual environment
source venv/bin/activate

# Set development environment variables
export FLASK_ENV=development
export FLASK_DEBUG=1
export PYTHONPATH="${PYTHONPATH}:$(pwd)"

# Run the Flask application
echo "🚀 Starting Flask development server..."
echo "📍 Server will be available at: http://localhost:8000"
echo "💡 Use Ctrl+C to stop the server"
echo ""

python backend.py
EOF
    
    chmod +x run-dev.sh
    log "Run script created (./run-dev.sh)"
}

# Create test script
create_test_script() {
    log "Creating test script..."
    
    cat > test-backend.sh << 'EOF'
#!/bin/bash

# Test script for the backend API
# Usage: ./test-backend.sh [base_url]

BASE_URL="${1:-http://localhost:8000}"

echo "🧪 Testing Spatial Data Visualization Backend"
echo "🔗 Base URL: $BASE_URL"
echo ""

# Test health endpoint
echo "1️⃣ Testing health endpoint..."
curl -f "$BASE_URL/health" || echo "❌ Health check failed"
echo ""

# Test notebook listing
echo "2️⃣ Testing notebook listing..."
curl -f "$BASE_URL/notebooks" || echo "❌ Notebook listing failed"
echo ""

# Test notebook upload (if sample exists)
if [ -f "temp/notebooks/sample_chart.ipynb" ]; then
    echo "3️⃣ Testing notebook conversion..."
    curl -X POST -F "file=@temp/notebooks/sample_chart.ipynb" \
         "$BASE_URL/convert/test_notebook" || echo "❌ Notebook conversion failed"
    echo ""
fi

# Test spatial metadata update
echo "4️⃣ Testing spatial metadata update..."
curl -X PUT "$BASE_URL/notebooks/sample_chart.ipynb/cells/0/spatial" \
     -H "Content-Type: application/json" \
     -d '{"x": 1, "y": 2, "z": 3, "pitch": 0, "yaw": 45, "roll": 0}' || echo "❌ Spatial metadata update failed"
echo ""

echo "✅ Backend testing completed"
EOF
    
    chmod +x test-backend.sh
    log "Test script created (./test-backend.sh)"
}

# Main setup function
main() {
    log "🚀 Setting up development environment for Spatial Data Visualization Backend"
    
    check_python
    setup_venv
    create_dev_config
    create_sample_notebooks
    create_run_script
    create_test_script
    
    log "🎉 Development environment setup completed!"
    
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Start development server: ./run-dev.sh"
    echo "  2. Test the API: ./test-backend.sh"
    echo "  3. View sample notebooks in: temp/notebooks/"
    echo ""
    echo "🔧 Development URLs:"
    echo "  Health Check: http://localhost:8000/health"
    echo "  API Documentation: http://localhost:8000/notebooks"
    echo ""
    echo "📝 Notes:"
    echo "  - Virtual environment is in: ./venv/"
    echo "  - Sample notebooks are in: ./temp/notebooks/"
    echo "  - Configuration is in: ./dev-config.py"
}

# Run main function
