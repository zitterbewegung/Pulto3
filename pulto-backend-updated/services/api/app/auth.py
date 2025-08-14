
import time, httpx, jwt, secrets
from typing import Optional
from fastapi import HTTPException, Depends, Header
from jose import jwk, jwt as jose_jwt
from jose.utils import base64url_decode
from sqlalchemy.orm import Session
from app.config import settings
from app.db import get_db
from app import models

APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"

_cache_keys = None
_cache_ts = 0

async def _get_apple_keys():
    global _cache_keys, _cache_ts
    if _cache_keys and time.time() - _cache_ts < 3600:
        return _cache_keys
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(APPLE_KEYS_URL)
        r.raise_for_status()
        _cache_keys = r.json()
        _cache_ts = time.time()
        return _cache_keys

async def verify_apple_identity_token(identity_token: str, session: Session) -> models.User:
    if not settings.apple_login_effective:
        raise HTTPException(404, "Not found")

    headers = jose_jwt.get_unverified_header(identity_token)
    keys = await _get_apple_keys()
    key = next((k for k in keys["keys"] if k["kid"] == headers["kid"]), None)
    if not key:
        raise HTTPException(400, "Invalid identity token: key mismatch")

    public_key = jwk.construct(key)
    message, encoded_sig = identity_token.rsplit('.', 1)
    decoded_sig = base64url_decode(encoded_sig.encode())
    if not public_key.verify(message.encode(), decoded_sig):
        raise HTTPException(400, "Invalid identity token signature")

    claims = jose_jwt.get_unverified_claims(identity_token)
    if claims.get("iss") != APPLE_ISSUER:
        raise HTTPException(400, "Invalid issuer")
    aud = claims.get("aud")
    if isinstance(aud, list):
        valid_aud = settings.APPLE_CLIENT_ID in aud
    else:
        valid_aud = aud == settings.APPLE_CLIENT_ID
    if not valid_aud:
        raise HTTPException(400, "Invalid audience")

    exp = claims.get("exp", 0)
    if time.time() > exp:
        raise HTTPException(400, "Token expired")

    sub = claims["sub"]
    email = claims.get("email")
    user = session.query(models.User).filter_by(sub=sub).first()
    if not user:
        user = models.User(sub=sub, email=email)
        session.add(user)
        session.commit()
    return user

def issue_access_token(user: models.User) -> str:
    now = int(time.time())
    payload = {
        "sub": str(user.id),
        "iss": settings.JWT_ISSUER,
        "aud": settings.JWT_AUDIENCE,
        "iat": now,
        "exp": now + settings.JWT_EXPIRES_MIN * 60,
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")

def _parse_auth_header(auth_header: Optional[str]) -> Optional[str]:
    if not auth_header:
        return None
    typ, _, token = auth_header.partition(" ")
    if typ.lower() != "bearer":
        return None
    return token

def require_user(authorization: Optional[str] = Header(None), session: Session = Depends(get_db)) -> models.User:
    token = _parse_auth_header(authorization)
    if not token:
        raise HTTPException(401, "Missing bearer token")
    try:
        data = jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"], audience=settings.JWT_AUDIENCE, issuer=settings.JWT_ISSUER)
    except Exception:
        raise HTTPException(401, "Invalid token")
    user_id = int(data["sub"])
    user = session.get(models.User, user_id)
    if not user:
        raise HTTPException(401, "User not found")
    return user

def ensure_user_by_email(session: Session, email: Optional[str]) -> models.User:
    if not email:
        email = f"dev+{secrets.token_hex(6)}@example.local"
    sub = f"dev::{email.lower()}"
    user = session.query(models.User).filter_by(sub=sub).first()
    if not user:
        user = models.User(sub=sub, email=email)
        session.add(user)
        session.commit()
    return user
