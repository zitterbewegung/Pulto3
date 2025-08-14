
import os, io, magic
from fastapi import UploadFile, HTTPException
from sqlalchemy.orm import Session
from app.config import settings
from app import models
from minio import Minio

s3 = Minio(
    endpoint=settings.S3_ENDPOINT.replace("http://", "").replace("https://", ""),
    access_key=settings.S3_ACCESS_KEY,
    secret_key=settings.S3_SECRET_KEY,
    secure=settings.S3_ENDPOINT.startswith("https://"),
)

ALLOWED_POINTCLOUD_EXTS = {".ply", ".pcd", ".las", ".laz", ".xyz", ".pts", ".obj", ".stl", ".glb", ".gltf", ".txt"}

async def save_notebook(file: UploadFile, user: models.User, session: Session) -> models.Notebook:
    if not file.filename.lower().endswith(".ipynb"):
        raise HTTPException(400, "File must be a .ipynb notebook")
    content = await file.read()
    object_key = f"{user.id}/notebooks/{file.filename}"
    s3.put_object(settings.S3_BUCKET_NOTEBOOKS, object_key, io.BytesIO(content), length=len(content), content_type="application/x-ipynb+json")

    local_dir = "/data/notebooks"
    os.makedirs(local_dir, exist_ok=True)
    local_path = os.path.join(local_dir, f"user{user.id}_{file.filename}")
    with open(local_path, "wb") as f:
        f.write(content)

    nb = models.Notebook(user_id=user.id, filename=file.filename, bucket=settings.S3_BUCKET_NOTEBOOKS, object_key=object_key, local_path=local_path)
    session.add(nb)
    session.commit()
    return nb

async def save_asset(file: UploadFile, user: models.User, session: Session, kind: str) -> models.Asset:
    name = file.filename
    ext = os.path.splitext(name)[1].lower()
    if kind == "pointcloud" and ext not in ALLOWED_POINTCLOUD_EXTS:
        raise HTTPException(400, f"Unsupported point cloud extension: {ext}")
    content = await file.read()
    mime = magic.from_buffer(content, mime=True) or "application/octet-stream"
    bucket = settings.S3_BUCKET_ASSETS
    object_key = f"{user.id}/{kind}/{name}"
    s3.put_object(bucket, object_key, io.BytesIO(content), length=len(content), content_type=mime)
    asset = models.Asset(user_id=user.id, kind=kind, filename=name, mime_type=mime, bucket=bucket, object_key=object_key)
    session.add(asset)
    session.commit()
    return asset

async def stream_object(bucket: str, object_key: str):
    resp = s3.get_object(bucket, object_key)
    return resp.stream(32*1024)
