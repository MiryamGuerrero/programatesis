from __future__ import annotations

import os
from pathlib import Path

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


def print_plan(title: str, rows: list[tuple[str]]) -> None:
    print("\n" + "=" * 80)
    print(title)
    print("=" * 80)
    for row in rows:
        print(row[0])


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    env_path = repo_root / "backend" / ".env"
    env_values = load_env_file(env_path)
    database_url = env_values.get("DATABASE_URL") or os.getenv("DATABASE_URL", "")

    if not database_url:
        print("ERROR: DATABASE_URL no encontrado en backend/.env")
        return 1

    database_url = ensure_sslmode(database_url)

    with psycopg.connect(
        database_url,
        connect_timeout=30,
        prepare_threshold=None,
    ) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                select coalesce(nullif(substr(nombre, 1, 4), ''), 'ar')
                from nutricion.ingrediente
                where nombre is not null and btrim(nombre) <> ''
                order by id desc
                limit 1
                """
            )
            row = cur.fetchone()
            term = (row[0] if row else "ar")
            pattern = f"%{term}%"

            print(f"Termino usado para benchmark: '{term}' (patron: '{pattern}')")

            cur.execute(
                """
                explain (analyze, buffers)
                select id, nombre
                from nutricion.ingrediente
                where nombre ilike %s
                order by id desc
                limit 20
                """,
                (pattern,),
            )
            normal_plan = cur.fetchall()
            print_plan("PLAN NORMAL (con indice disponible)", normal_plan)

            cur.execute("begin")
            cur.execute("set local enable_bitmapscan = off")
            cur.execute("set local enable_indexscan = off")
            cur.execute("set local enable_indexonlyscan = off")
            cur.execute(
                """
                explain (analyze, buffers)
                select id, nombre
                from nutricion.ingrediente
                where nombre ilike %s
                order by id desc
                limit 20
                """,
                (pattern,),
            )
            seq_plan = cur.fetchall()
            cur.execute("rollback")
            print_plan("PLAN SECUENCIAL FORZADO (sin usar indices)", seq_plan)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
