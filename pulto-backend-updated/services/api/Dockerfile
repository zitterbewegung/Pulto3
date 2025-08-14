FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libmagic1 curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Build context is ./services/api
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# ✅ Copy ONLY the app/ folder into /app/app so module name is "app"
COPY app /app/app

ENV PYTHONUNBUFFERED=1

# Data dirs mounted via volumes
RUN mkdir -p /data/notebooks /data/assets
VOLUME ["/data/notebooks", "/data/assets"]

EXPOSE 8080
