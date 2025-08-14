
from app.storage import s3
from app.config import settings

async def ensure_buckets():
    for bucket in [settings.S3_BUCKET_ASSETS, settings.S3_BUCKET_NOTEBOOKS]:
        if not s3.bucket_exists(bucket):
            s3.make_bucket(bucket)
