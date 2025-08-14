
import os
import asyncio
from fastapi import FastAPI, Depends, File, UploadFile, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from app import models, schemas, db, auth, storage, mqtt_client, tasks, notebooks
from app.utils import ensure_buckets
from app.config import settings

app = FastAPI(title="Pulto Backend", version="1.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup():
    models.Base.metadata.create_all(bind=db.engine)
    await ensure_buckets()

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "features": {
            "apple_login": settings.apple_login_effective,
            "dev_login": settings.ENABLE_DEV_LOGIN,
        },
    }

# ---- Auth (Sign in with Apple) ----
@app.post("/auth/apple", response_model=schemas.TokenResponse)
async def auth_apple(payload: schemas.AppleAuthRequest, session: Session = Depends(db.get_db)):
    if not settings.apple_login_effective:
        raise HTTPException(status_code=404, detail="Not found")
    user = await auth.verify_apple_identity_token(payload.identityToken, session)
    token = auth.issue_access_token(user)
    return schemas.TokenResponse(access_token=token, token_type="bearer")

# ---- Dev Auth (for local/testing) ----
@app.post("/auth/dev", response_model=schemas.TokenResponse)
async def auth_dev(payload: schemas.DevAuthRequest, session: Session = Depends(db.get_db)):
    if not settings.ENABLE_DEV_LOGIN:
        raise HTTPException(status_code=404, detail="Not found")
    user = auth.ensure_user_by_email(session, payload.email)
    token = auth.issue_access_token(user)
    return schemas.TokenResponse(access_token=token, token_type="bearer")

@app.get("/me", response_model=schemas.UserOut)
async def me(user: models.User = Depends(auth.require_user)):
    return schemas.UserOut.model_validate(user.__dict__)

# ---- Uploads ----
@app.post("/uploads/notebooks", response_model=schemas.NotebookOut)
async def upload_notebook(file: UploadFile = File(...), user: models.User = Depends(auth.require_user), session: Session = Depends(db.get_db)):
    note = await storage.save_notebook(file, user, session)
    return schemas.NotebookOut.model_validate(note.to_dict())

@app.post("/uploads/pointclouds", response_model=schemas.AssetOut)
async def upload_pointcloud(file: UploadFile = File(...), user: models.User = Depends(auth.require_user), session: Session = Depends(db.get_db)):
    asset = await storage.save_asset(file, user, session, kind="pointcloud")
    return schemas.AssetOut.model_validate(asset.to_dict())

@app.post("/uploads/usdz", response_model=schemas.AssetOut)
async def upload_usdz(file: UploadFile = File(...), user: models.User = Depends(auth.require_user), session: Session = Depends(db.get_db)):
    if not file.filename.lower().endswith(".usdz"):
        raise HTTPException(400, "File must be .usdz")
    asset = await storage.save_asset(file, user, session, kind="usdz")
    return schemas.AssetOut.model_validate(asset.to_dict())

@app.get("/assets/{asset_id}/download")
async def download_asset(asset_id: int, user: models.User = Depends(auth.require_user), session: Session = Depends(db.get_db)):
    obj = session.get(models.Asset, asset_id)
    if not obj or obj.user_id != user.id:
        raise HTTPException(404, "Not found")
    stream = await storage.stream_object(obj.bucket, obj.object_key)
    return StreamingResponse(stream, media_type=obj.mime_type, headers={
        "Content-Disposition": f'attachment; filename=\"{obj.filename}\"'
    })

# ---- Notebooks ----
@app.get("/notebooks", response_model=list[schemas.NotebookOut])
async def list_notebooks(user: models.User = Depends(auth.require_user), session: Session = Depends(db.get_db)):
    q = session.query(models.Notebook).filter_by(user_id=user.id).order_by(models.Notebook.id.desc()).all()
    return [schemas.NotebookOut.model_validate(n.to_dict()) for n in q]

@app.post("/notebooks/{nb_id}/run", response_model=schemas.JobOut)
async def run_notebook(nb_id: int, user: models.User = Depends(auth.require_user), session: Session = Depends(db.get_db)):
    nb = session.get(models.Notebook, nb_id)
    if not nb or nb.user_id != user.id:
        raise HTTPException(404, "Notebook not found")
    job_id = tasks.queue_notebook_execution(nb.id, user.id)
    return schemas.JobOut(id=job_id, status="queued")

@app.get("/jobs/{job_id}", response_model=schemas.JobOut)
async def get_job(job_id: str):
    info = tasks.get_job(job_id)
    if not info:
        raise HTTPException(404, "Job not found")
    return schemas.JobOut(**info)

@app.get("/notebooks/{nb_id}", response_model=schemas.NotebookOut)
async def get_notebook(nb_id: int, user: models.User = Depends(auth.require_user), session: Session = Depends(db.get_db)):
    nb = session.get(models.Notebook, nb_id)
    if not nb or nb.user_id != user.id:
        raise HTTPException(404, "Notebook not found")
    return schemas.NotebookOut.model_validate(nb.to_dict())

@app.get("/notebooks/{nb_id}/cells", response_model=schemas.NotebookCellsOut)
async def get_notebook_cells(nb_id: int, user: models.User = Depends(auth.require_user), session: Session = Depends(db.get_db)):
    nb = session.get(models.Notebook, nb_id)
    if not nb or nb.user_id != user.id:
        raise HTTPException(404, "Notebook not found")
    cells = notebooks.extract_cells_from_path(nb.local_path)
    return schemas.NotebookCellsOut(notebook_id=nb.id, cells=cells)

# ---- MQTT ----
@app.websocket("/mqtt/stream")
async def mqtt_stream(ws: WebSocket, topic: str):
    await ws.accept()
    client = mqtt_client.AsyncWSBridge(ws, topic)
    try:
        await client.run()
    except WebSocketDisconnect:
        pass
    finally:
        await client.shutdown()

@app.post("/mqtt/publish")
async def mqtt_publish(payload: schemas.MqttPublish):
    await mqtt_client.publish(payload.topic, payload.payload)
    return {"status": "ok"}
