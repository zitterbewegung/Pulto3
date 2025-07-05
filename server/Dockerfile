# Use Python 3.13 slim image as base
FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Install system dependencies required for scientific Python packages
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    libfreetype6-dev \
    libpng-dev \
    libopenblas-dev \
    pkg-config \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create a non-root user to run the application
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Create upload directory
RUN mkdir -p /tmp/notebooks

# Expose the port the app runs on
EXPOSE 5000

# Set environment variables
ENV FLASK_APP=backend.py
ENV PYTHONUNBUFFERED=1

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run the application with gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "backend:app"]

