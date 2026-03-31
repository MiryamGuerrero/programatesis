from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

import psycopg


def load_env_file(env_path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not env_path.exists():
        return values

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def ensure_sslmode(database_url: str) -> str:
    if "sslmode=" in database_url:
        return database_url
    separator = "&" if "?" in database_url else "?"
    return f"{database_url}{separator}sslmode=require"


def apply_with_direct_url(database_url: str, sql_text: str) -> None:
    with psycopg.connect(ensure_sslmode(database_url), connect_timeout=30) as conn:
        with conn.cursor() as cur:
            cur.execute(sql_text)
        conn.commit()


def apply_with_pooler(database_url: str, sql_text: str, pooler_host: str, pooler_port: int) -> None:
    parsed = urlparse(database_url)
    project_ref = ""
    if parsed.hostname and parsed.hostname.startswith("db."):
        parts = parsed.hostname.split(".")
        if len(parts) > 1:
            project_ref = parts[1]

    dbname = parsed.path.lstrip("/") or "postgres"
    password = unquote(parsed.password or "")
    user_candidates = []
    if project_ref:
        user_candidates.append(f"postgres.{project_ref}")
    if parsed.username and parsed.username not in user_candidates:
        user_candidates.append(parsed.username)
    if "postgres" not in user_candidates:
        user_candidates.append("postgres")

    last_error: Exception | None = None
    for user in user_candidates:
        try:
            with psycopg.connect(
                host=pooler_host,
                port=pooler_port,
                user=user,
                password=password,
                dbname=dbname,
                sslmode="require",
                connect_timeout=30,
            ) as conn:
                with conn.cursor() as cur:
                    cur.execute(sql_text)
                conn.commit()
            return
        except Exception as exc:  # noqa: BLE001
            last_error = exc

    if last_error is not None:
        raise last_error


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply a SQL file to Supabase PostgreSQL")
    parser.add_argument("--sql-file", required=True, help="Path to SQL file")
    parser.add_argument("--env-file", default=".env", help="Path to .env file")
    parser.add_argument("--pooler-host", default="", help="Optional Supabase pooler host")
    parser.add_argument("--pooler-port", default=6543, type=int, help="Pooler port (default 6543)")
    args = parser.parse_args()

    sql_file = Path(args.sql_file)
    env_file = Path(args.env_file)

    if not sql_file.exists():
        print(f"ERROR: SQL file not found: {sql_file}")
        return 1

    env_values = load_env_file(env_file)
    database_url = env_values.get("DATABASE_URL") or os.getenv("DATABASE_URL", "")
    if not database_url:
        print("ERROR: DATABASE_URL not found in environment")
        return 1

    database_url = ensure_sslmode(database_url)
    sql_text = sql_file.read_text(encoding="utf-8")

    try:
        apply_with_direct_url(database_url, sql_text)
    except Exception as exc:  # noqa: BLE001
        if not args.pooler_host:
            print(f"ERROR: migration failed: {exc}")
            return 1
        try:
            apply_with_pooler(database_url, sql_text, args.pooler_host, args.pooler_port)
        except Exception as pooler_exc:  # noqa: BLE001
            print(f"ERROR: migration failed direct={exc} pooler={pooler_exc}")
            return 1

    print("MIGRATION_APPLIED_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
