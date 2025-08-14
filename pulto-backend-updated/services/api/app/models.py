
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    sub = Column(String(255), unique=True, index=True)  # Apple or dev sub
    email = Column(String(255), index=True, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Notebook(Base):
    __tablename__ = "notebooks"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    filename = Column(String(255))
    bucket = Column(String(255))
    object_key = Column(String(512))
    local_path = Column(String(512))
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "filename": self.filename,
            "bucket": self.bucket,
            "object_key": self.object_key,
            "created_at": self.created_at.isoformat(),
        }

class Asset(Base):
    __tablename__ = "assets"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    kind = Column(String(64))  # pointcloud | usdz | other
    filename = Column(String(255))
    mime_type = Column(String(127))
    bucket = Column(String(255))
    object_key = Column(String(512))
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "kind": self.kind,
            "filename": self.filename,
            "mime_type": self.mime_type,
            "bucket": self.bucket,
            "object_key": self.object_key,
            "created_at": self.created_at.isoformat(),
        }
