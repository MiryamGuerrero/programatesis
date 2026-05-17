import logging
from contextlib import contextmanager
from threading import RLock
import time

from psycopg_pool import ConnectionPool
from psycopg import OperationalError
from app.core.config import get_settings

logger = logging.getLogger(__name__)

_pool = None
_pool_lock = RLock()

def get_pool() -> ConnectionPool:
    global _pool
    if _pool is not None:
        return _pool

    with _pool_lock:
        if _pool is None:
            settings = get_settings()
            if not settings.database_url:
                raise RuntimeError("DATABASE_URL must be configured")

            _pool = ConnectionPool(
                conninfo=settings.database_url,
                min_size=1,
                max_size=10,
                kwargs={"autocommit": True, "prepare_threshold": None},
                check=ConnectionPool.check_connection,
                num_workers=1,
            )
        return _pool

def close_pool():
    global _pool
    with _pool_lock:
        pool = _pool
        _pool = None

    if pool is not None:
        try:
            pool.close()
        except RuntimeError as exc:
            logger.warning("No se pudo cerrar el pool limpiamente: %s", exc)
        logger.info("Pool de conexiones cerrado correctamente.")

@contextmanager
def db_cursor():
    pool = get_pool()
    max_retries = 3
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            with pool.connection() as conn:
                with conn.cursor() as cur:
                    yield cur
                    return
        except OperationalError as e:
            retry_count += 1
            logger.warning(f"Reintento de conexión {retry_count}/{max_retries}")
            if retry_count >= max_retries:
                raise e
            time.sleep(1)
