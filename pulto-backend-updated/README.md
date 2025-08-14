
# Pulto Backend (FastAPI + Celery + MinIO + Mosquitto + Postgres)

This backend runs and stores Jupyter notebooks, supports Sign in with Apple (behind a feature flag), stores point cloud & USDZ files, and integrates an MQTT broker for IoT streams.

## Quick start

```bash
docker compose up --build
```

- API: http://localhost:8080/docs
- MinIO console: http://localhost:9001 (minio/minio12345)
- Postgres: localhost:5432

## Auth

- **Dev Login** (enabled by default):  
  `POST /auth/dev`  
  Body: `{ "email": "me@local.test" }` (email optional)  
  → returns `{ "access_token": "…", "token_type": "bearer" }`

- **Sign in with Apple** (optional)  
  Enable by setting `ENABLE_APPLE_LOGIN=true` and adding `APPLE_CLIENT_ID` (and other values) in `.env`.  
  Endpoint: `POST /auth/apple` with `{ "identityToken": "<JWT from iOS>" }`.

## Uploads

- `POST /uploads/notebooks` (multipart form file=.ipynb)
- `POST /uploads/pointclouds` (.ply .pcd .las .laz .xyz .pts .obj .stl .glb .gltf .txt)
- `POST /uploads/usdz` (.usdz only)
- `GET /assets/{asset_id}/download`

## Notebooks

- `GET /notebooks`
- `POST /notebooks/{id}/run`
- `GET /jobs/{job_id}`
- `GET /notebooks/{id}/cells`

## MQTT

- `POST /mqtt/publish` -> {topic, payload}
- `WS /mqtt/stream?topic=pulto/iot/#` -> JSON frames: {topic, payload}

## Feature Flags

- `ENABLE_DEV_LOGIN=true|false` (default true)
- `ENABLE_APPLE_LOGIN=true|false` (default false). Route enabled only if flag is true **and** `APPLE_CLIENT_ID` is set.

## Notes

- Notebook execution via Celery using nbclient. Outputs overwrite local cached file used by `/notebooks/{id}/cells`.
- Files stored in MinIO (S3-compatible). Configure `.env` for production or swap to AWS S3 by setting `S3_ENDPOINT=https://s3.amazonaws.com`.
