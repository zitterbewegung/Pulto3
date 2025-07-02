# security_config.py - Security Configuration

import secrets
from typing import List

class SecurityConfig:
    # API Security
    SECRET_KEY = secrets.token_urlsafe(32)
    ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = 30
    
    # CORS Configuration
    ALLOWED_ORIGINS: List[str] = [
        "https://your-domain.com",
        "https://app.your-domain.com",
        # Add your VisionOS app's origin
    ]
    
    # Rate Limiting
    RATE_LIMIT_PER_MINUTE = 60
    UPLOAD_RATE_LIMIT_PER_MINUTE = 10
    
    # File Upload Security
    MAX_UPLOAD_SIZE = 100 * 1024 * 1024  # 100MB
    ALLOWED_EXTENSIONS = {'.ipynb', '.json'}
    
    # Security Headers
    SECURITY_HEADERS = {
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "X-XSS-Protection": "1; mode=block",
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        "Content-Security-Policy": "default-src 'self'; script-src 'self' 'unsafe-inline'",
        "Referrer-Policy": "strict-origin-when-cross-origin"
    }

# Environment-specific configurations
class DevelopmentConfig(SecurityConfig):
    DEBUG = True
    ALLOWED_ORIGINS = ["*"]  # More permissive for development

class ProductionConfig(SecurityConfig):
    DEBUG = False
    # Strict HTTPS enforcement
    FORCE_HTTPS = True
    
class TestingConfig(SecurityConfig):
    TESTING = True
    SECRET_KEY = "test-secret-key"
