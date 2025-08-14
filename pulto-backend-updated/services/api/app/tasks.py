
from celery import Celery
from app.config import settings
from app import notebooks, models, db

celery_app = Celery(__name__, broker=settings.REDIS_URL, backend=settings.REDIS_URL)

@celery_app.task(name="execute_notebook")
def execute_notebook_task(nb_path: str) -> dict:
    return notebooks.execute_notebook(nb_path)

def queue_notebook_execution(nb_id: int, user_id: int) -> str:
    session = db.SessionLocal()
    nb = session.get(models.Notebook, nb_id)
    if not nb or nb.user_id != user_id:
        raise ValueError("Notebook not found or unauthorized")
    async_result = execute_notebook_task.delay(nb.local_path)
    return async_result.id

def get_job(job_id: str):
    res = celery_app.AsyncResult(job_id)
    info = {"id": job_id, "status": res.status.lower()}
    if res.failed():
        info["detail"] = str(res.result)
    if res.successful():
        info["detail"] = "completed"
    return info
