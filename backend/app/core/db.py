from contextlib import contextmanager
from functools import lru_cache

from psycopg_pool import ConnectionPool

from app.core.config import get_settings


@lru_cache
def get_pool() -> ConnectionPool:
    settings = get_settings()
    if not settings.database_url:
        raise RuntimeError("DATABASE_URL must be configured")

    return ConnectionPool(
        conninfo=settings.database_url,
        min_size=1,
        max_size=8,
        kwargs={"autocommit": True},
    )


@contextmanager
def db_cursor():
    pool = get_pool()
    with pool.connection() as conn:
        with conn.cursor() as cur:
            yield cur
