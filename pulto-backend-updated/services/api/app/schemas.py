
from pydantic import BaseModel
from typing import Optional, Any

# Auth
class AppleAuthRequest(BaseModel):
    identityToken: str

class DevAuthRequest(BaseModel):
    email: Optional[str] = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class UserOut(BaseModel):
    id: int
    email: Optional[str] = None

# Uploads / assets
class AssetOut(BaseModel):
    id: int
    user_id: int
    kind: str
    filename: str
    mime_type: str
    bucket: str
    object_key: str
    created_at: str

class NotebookOut(BaseModel):
    id: int
    user_id: int
    filename: str
    bucket: str
    object_key: str
    created_at: str

class JobOut(BaseModel):
    id: str
    status: str
    detail: Optional[str] = None

# Notebooks
class NotebookCell(BaseModel):
    cell_type: str
    source: str
    outputs: Any | None = None

class NotebookCellsOut(BaseModel):
    notebook_id: int
    cells: list[NotebookCell]

# MQTT
class MqttPublish(BaseModel):
    topic: str
    payload: str
