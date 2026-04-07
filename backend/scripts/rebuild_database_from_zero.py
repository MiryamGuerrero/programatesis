from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import psycopg

ROOT_DIR = Path(__file__).resolve().parents[2]
BACKEND_DIR = ROOT_DIR / "backend"
DEFAULT_ENV = BACKEND_DIR / ".env"
MIGRATIONS_DIR = ROOT_DIR / "supabase" / "migrations"
SEEDS_DIR = ROOT_DIR / "supabase" / "seeds"
BACKUP_DIR = ROOT_DIR / "supabase" / "backups"


def parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")

    return values


def ensure_sslmode(database_url: str) -> str:
    if "sslmode=" in database_url:
        return database_url
    sep = "&" if "?" in database_url else "?"
    return f"{database_url}{sep}sslmode=require"


def backup_current_state(conn: psycopg.Connection, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_type = 'BASE TABLE'
              AND table_schema NOT IN ('pg_catalog', 'information_schema')
              AND table_schema NOT LIKE 'pg_toast%'
            ORDER BY table_schema, table_name
            """
        )
        tables = [(row[0], row[1]) for row in cur.fetchall()]

    manifest: list[dict[str, str | int]] = []

    for schema, table in tables:
        table_dir = output_dir / schema
        table_dir.mkdir(parents=True, exist_ok=True)
        csv_file = table_dir / f"{table}.csv"

        with conn.cursor() as cur:
            cur.execute(f'SELECT COUNT(*) FROM "{schema}"."{table}"')
            count = int(cur.fetchone()[0])

        manifest.append({"schema": schema, "table": table, "rows": count})

        if count == 0:
            continue

        with conn.cursor() as cur, csv_file.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            cur.execute(f'SELECT * FROM "{schema}"."{table}" LIMIT 0')
            writer.writerow([desc[0] for desc in cur.description])

            with cur.copy(f'COPY "{schema}"."{table}" TO STDOUT WITH CSV') as copy:
                for data in copy:
                    if isinstance(data, memoryview):
                        handle.write(bytes(data).decode("utf-8"))
                    elif isinstance(data, bytes):
                        handle.write(data.decode("utf-8"))
                    else:
                        handle.write(str(data))

    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def run_pg_dump_if_available(database_url: str, output_dir: Path) -> None:
    pg_dump_path = shutil.which("pg_dump")
    if not pg_dump_path:
        return

    dump_file = output_dir / "snapshot_pg_dump.sql"
    subprocess.run(
        [
            pg_dump_path,
            "--no-owner",
            "--no-privileges",
            "--format=plain",
            "--encoding=UTF8",
            f"--dbname={database_url}",
            f"--file={dump_file}",
        ],
        check=True,
    )


def apply_sql_file(conn: psycopg.Connection, path: Path) -> None:
    sql_text = path.read_text(encoding="utf-8")
    with conn.cursor() as cur:
        cur.execute(sql_text)
    conn.commit()


def run_script(script_path: Path, env_file: Path) -> None:
    subprocess.run(
        [
            sys.executable,
            str(script_path),
            "--env-file",
            str(env_file),
        ],
        cwd=str(ROOT_DIR),
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Recrea base de datos nueva desde cero y ejecuta ETL")
    parser.add_argument("--env-file", default=str(DEFAULT_ENV))
    parser.add_argument("--skip-backup", action="store_true")
    parser.add_argument("--skip-etl", action="store_true")
    args = parser.parse_args()

    env_file = Path(args.env_file)
    env_values = parse_env_file(env_file)
    database_url = env_values.get("DATABASE_URL") or os.getenv("DATABASE_URL", "")
    if not database_url:
        raise RuntimeError("DATABASE_URL no encontrado")

    database_url = ensure_sslmode(database_url)

    with psycopg.connect(database_url, prepare_threshold=None) as conn:
        if not args.skip_backup:
            stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_dir = BACKUP_DIR / f"snapshot_{stamp}"
            backup_current_state(conn, backup_dir)
            run_pg_dump_if_available(database_url, backup_dir)
            print(f"BACKUP_OK dir={backup_dir}")

        migration_files = sorted(MIGRATIONS_DIR.glob("*.sql"))
        for migration in migration_files:
            apply_sql_file(conn, migration)
            print(f"MIGRATION_OK file={migration.name}")

        seed_files = sorted(SEEDS_DIR.glob("*.sql"))
        for seed in seed_files:
            apply_sql_file(conn, seed)
            print(f"SEED_OK file={seed.name}")

    if not args.skip_etl:
        run_script(ROOT_DIR / "backend" / "scripts" / "load_ingredientes_new_schema.py", env_file)
        run_script(ROOT_DIR / "backend" / "scripts" / "load_oms_curvas_new_schema.py", env_file)

    print("REBUILD_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
