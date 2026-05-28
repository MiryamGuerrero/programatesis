import logging
import os
from contextlib import contextmanager
from threading import RLock
import time

from psycopg_pool import ConnectionPool
from psycopg import OperationalError
from app.core.config import get_settings

logger = logging.getLogger(__name__)

_pool = None
_pool_lock = RLock()


def _resolve_pool_settings(settings):
    cpu_count = os.cpu_count() or 2
    max_size = settings.db_pool_max_size or min(24, max(10, cpu_count * 4))
    min_size = max(1, min(settings.db_pool_min_size, max_size))
    num_workers = settings.db_pool_workers or min(4, max(1, cpu_count))
    return min_size, max_size, num_workers

def get_pool() -> ConnectionPool:
    global _pool
    if _pool is not None:
        return _pool

    with _pool_lock:
        if _pool is None:
            settings = get_settings()
            if not settings.database_url:
                raise RuntimeError("DATABASE_URL must be configured")

            min_size, max_size, num_workers = _resolve_pool_settings(settings)
            _pool = ConnectionPool(
                conninfo=settings.database_url,
                min_size=min_size,
                max_size=max_size,
                kwargs={"autocommit": True, "prepare_threshold": None},
                check=ConnectionPool.check_connection,
                num_workers=num_workers,
            )
            logger.info(
                "Pool de base de datos inicializado: min=%s max=%s workers=%s",
                min_size,
                max_size,
                num_workers,
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
