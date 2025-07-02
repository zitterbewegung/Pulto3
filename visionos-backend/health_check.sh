#!/bin/bash
# Health check script for post-deployment verification

BASE_URL=${1:-"http://localhost:8000"}

echo "🏥 Running health checks for $BASE_URL"
echo "======================================"

# Basic health check
echo "1. Basic health check..."
if curl -s "$BASE_URL/health" | grep -q "healthy"; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

# API endpoints check
echo "2. API endpoints check..."
if curl -s "$BASE_URL/api/info" | grep -q "FastAPI"; then
    echo "✅ API info endpoint working"
else
    echo "❌ API info endpoint failed"
    exit 1
fi

# WebSocket check
echo "3. WebSocket check..."
if command -v wscat &> /dev/null; then
    echo '{"type":"ping"}' | timeout 5 wscat -c "ws://localhost:8000/ws" && echo "✅ WebSocket working" || echo "❌ WebSocket failed"
else
    echo "⚠️  wscat not found, skipping WebSocket test"
fi

# Database check
echo "4. Database connectivity..."
if curl -s "$BASE_URL/analytics" | grep -q "system_status"; then
    echo "✅ Database connectivity verified"
else
    echo "❌ Database connectivity failed"
    exit 1
fi

# Performance check
echo "5. Performance check..."
RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' "$BASE_URL/health")
if (( $(echo "$RESPONSE_TIME < 1.0" | bc -l) )); then
    echo "✅ Response time acceptable: ${RESPONSE_TIME}s"
else
    echo "⚠️  Response time high: ${RESPONSE_TIME}s"
fi

echo ""
echo "🎉 Health checks completed!"
