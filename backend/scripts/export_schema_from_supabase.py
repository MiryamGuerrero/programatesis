from __future__ import annotations

import argparse
import os
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlparse

import psycopg

CANDIDATE_BASE_SCHEMAS = [
    "seguridad",
    "usuarios",
    "clinico",
    "nutricion",
    "heuristico",
    "interaccion",
    "referencia",
]

TYPE_MAP = {
    "bigint": "BIGINT",
    "integer": "INTEGER",
    "smallint": "SMALLINT",
    "boolean": "BOOLEAN",
    "text": "TEXT",
    "date": "DATE",
    "json": "JSON",
    "jsonb": "JSONB",
    "double precision": "DOUBLE PRECISION",
    "real": "REAL",
    "bytea": "BYTEA",
    "uuid": "UUID",
    "interval": "INTERVAL",
    "time without time zone": "TIME",
    "time with time zone": "TIMETZ",
    "timestamp without time zone": "TIMESTAMP",
    "timestamp with time zone": "TIMESTAMPTZ",
}


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


def connect_with_fallback(database_url: str, pooler_host: str, pooler_port: int) -> psycopg.Connection:
    direct_error: Exception | None = None
    try:
        return psycopg.connect(
            ensure_sslmode(database_url),
            connect_timeout=30,
            prepare_threshold=None,
        )
    except Exception as exc:  # noqa: BLE001
        direct_error = exc

    parsed = urlparse(database_url)
    project_ref = ""
    if parsed.hostname and parsed.hostname.startswith("db."):
        parts = parsed.hostname.split(".")
        if len(parts) > 1:
            project_ref = parts[1]

    dbname = parsed.path.lstrip("/") or "postgres"
    password = unquote(parsed.password or "")
    user_candidates: list[str] = []
    if project_ref:
        user_candidates.append(f"postgres.{project_ref}")
    if parsed.username and parsed.username not in user_candidates:
        user_candidates.append(parsed.username)
    if "postgres" not in user_candidates:
        user_candidates.append("postgres")

    last_error: Exception | None = None
    for user in user_candidates:
        try:
            return psycopg.connect(
                host=pooler_host,
                port=pooler_port,
                user=user,
                password=password,
                dbname=dbname,
                sslmode="require",
                connect_timeout=30,
                prepare_threshold=None,
            )
        except Exception as exc:  # noqa: BLE001
            last_error = exc

    raise RuntimeError(f"Could not connect to database. direct={direct_error} pooler={last_error}")


def safe_ident(name: str) -> str:
    if name and name[0].isalpha() or (name and name[0] == "_"):
        if all(ch.islower() or ch.isdigit() or ch == "_" for ch in name):
            return name
    escaped = name.replace('"', '""')
    return f'"{escaped}"'


def type_sql(col: dict[str, object]) -> str:
    data_type = str(col["data_type"])
    udt_name = str(col["udt_name"])
    udt_schema = str(col["udt_schema"])

    if data_type == "character varying":
        length = col["character_maximum_length"]
        return f"VARCHAR({length})" if length is not None else "VARCHAR"

    if data_type == "character":
        length = col["character_maximum_length"]
        return f"CHAR({length})" if length is not None else "CHAR"

    if data_type == "numeric":
        precision = col["numeric_precision"]
        scale = col["numeric_scale"]
        if precision is not None and scale is not None:
            return f"NUMERIC({precision},{scale})"
        if precision is not None:
            return f"NUMERIC({precision})"
        return "NUMERIC"

    if data_type == "ARRAY":
        base = udt_name[1:] if udt_name.startswith("_") else udt_name
        base_type = TYPE_MAP.get(base, base.upper())
        return f"{base_type}[]"

    if data_type == "USER-DEFINED":
        if udt_schema in ("pg_catalog", "public"):
            return safe_ident(udt_name)
        return f"{safe_ident(udt_schema)}.{safe_ident(udt_name)}"

    return TYPE_MAP.get(data_type, data_type.upper())


def ordered_schemas(base_order: list[str], extra_schemas: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for schema in base_order + extra_schemas:
        if schema not in seen:
            seen.add(schema)
            result.append(schema)
    return result


def build_column_sql(col: dict[str, object]) -> str:
    column_name = safe_ident(str(col["column_name"]))
    data_type = str(col["data_type"])
    column_default = col["column_default"]
    identity_generation = col["identity_generation"]
    is_nullable = str(col["is_nullable"]) == "YES"

    serial_type = None
    if identity_generation is None and isinstance(column_default, str) and column_default.startswith("nextval("):
        if data_type == "integer":
            serial_type = "SERIAL"
        elif data_type == "bigint":
            serial_type = "BIGSERIAL"
        elif data_type == "smallint":
            serial_type = "SMALLSERIAL"

    base_type = serial_type or type_sql(col)
    pieces = [column_name, base_type]

    if identity_generation is not None:
        identity = str(identity_generation).upper()
        pieces.append(f"GENERATED {identity} AS IDENTITY")
    elif column_default is not None and serial_type is None:
        pieces.append(f"DEFAULT {column_default}")

    if not is_nullable:
        pieces.append("NOT NULL")

    return " ".join(pieces)


def main() -> int:
    parser = argparse.ArgumentParser(description="Export Supabase table schema to SQL")
    parser.add_argument("--output-file", default="..\\base_de_datos.sql", help="Output SQL file path")
    parser.add_argument("--env-file", default=".env", help="Path to .env with DATABASE_URL")
    parser.add_argument("--pooler-host", default="aws-0-us-west-2.pooler.supabase.com", help="Supabase pooler host")
    parser.add_argument("--pooler-port", default=6543, type=int, help="Supabase pooler port")
    args = parser.parse_args()

    env_values = load_env_file(Path(args.env_file))
    database_url = env_values.get("DATABASE_URL") or os.getenv("DATABASE_URL", "")
    if not database_url:
        raise RuntimeError("DATABASE_URL not found in environment")

    with connect_with_fallback(database_url, args.pooler_host, args.pooler_port) as conn:
        conn.row_factory = psycopg.rows.dict_row

        with conn.cursor() as cur:
            cur.execute(
                """
                select table_schema as nspname
                from information_schema.tables
                where table_type = 'BASE TABLE'
                  and table_schema like 'dom_%'
                group by table_schema
                order by table_schema
                """
            )
            domain_schemas = [str(row["nspname"]) for row in cur.fetchall()]

            cur.execute(
                """
                select table_schema as nspname
                from information_schema.tables
                where table_type = 'BASE TABLE'
                  and table_schema = any(%s)
                group by table_schema
                order by array_position(%s::text[], table_schema)
                """,
                (CANDIDATE_BASE_SCHEMAS, CANDIDATE_BASE_SCHEMAS),
            )
            existing_base_schemas = [str(row["nspname"]) for row in cur.fetchall()]

            schema_order = ordered_schemas(existing_base_schemas, domain_schemas)

            cur.execute(
                """
                select extname
                from pg_extension
                where extname in ('uuid-ossp', 'pgcrypto')
                order by extname
                """
            )
            extensions = [row["extname"] for row in cur.fetchall()]

            cur.execute(
                """
                select table_schema, table_name
                from information_schema.tables
                where table_type = 'BASE TABLE'
                  and table_schema = any(%s)
                order by array_position(%s::text[], table_schema), table_name
                """,
                                (schema_order, schema_order),
            )
            tables = cur.fetchall()

            cur.execute(
                """
                select
                    table_schema,
                    table_name,
                    column_name,
                    ordinal_position,
                    data_type,
                    udt_name,
                    udt_schema,
                    character_maximum_length,
                    numeric_precision,
                    numeric_scale,
                    is_nullable,
                    column_default,
                    identity_generation
                from information_schema.columns
                where table_schema = any(%s)
                order by array_position(%s::text[], table_schema), table_name, ordinal_position
                """,
                (schema_order, schema_order),
            )
            columns = cur.fetchall()

            cur.execute(
                """
                select
                    n.nspname as table_schema,
                    t.relname as table_name,
                    con.conname,
                    con.contype,
                    pg_get_constraintdef(con.oid, true) as definition
                from pg_constraint con
                inner join pg_class t on t.oid = con.conrelid
                inner join pg_namespace n on n.oid = t.relnamespace
                where n.nspname = any(%s)
                order by
                    array_position(%s::text[], n.nspname),
                    t.relname,
                    case con.contype
                        when 'p' then 1
                        when 'u' then 2
                        when 'c' then 3
                        when 'f' then 4
                        else 5
                    end,
                    con.conname
                """,
                (schema_order, schema_order),
            )
            constraints = cur.fetchall()

            cur.execute(
                """
                select pg_get_indexdef(i.oid) as indexdef
                from pg_index idx
                inner join pg_class i on i.oid = idx.indexrelid
                inner join pg_class t on t.oid = idx.indrelid
                inner join pg_namespace n on n.oid = t.relnamespace
                left join pg_constraint con on con.conindid = idx.indexrelid
                where n.nspname = any(%s)
                  and con.oid is null
                order by
                    array_position(%s::text[], n.nspname),
                    t.relname,
                    i.relname
                """,
                (schema_order, schema_order),
            )
            indexes = cur.fetchall()

            cur.execute(
                """
                select
                    n.nspname as view_schema,
                    c.relname as view_name,
                    pg_get_viewdef(c.oid, true) as view_definition,
                    coalesce(array_to_string(c.reloptions, ','), '') as reloptions
                from pg_class c
                inner join pg_namespace n on n.oid = c.relnamespace
                where c.relkind = 'v'
                  and n.nspname = any(%s)
                order by array_position(%s::text[], n.nspname), c.relname
                """,
                (schema_order, schema_order),
            )
            views = cur.fetchall()

    columns_by_table: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for col in columns:
        key = (str(col["table_schema"]), str(col["table_name"]))
        columns_by_table[key].append(col)

    lines: list[str] = []
    now_text = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")

    lines.append("-- =====================================================")
    lines.append("-- REUMA NUTRI - ESQUEMA SINCRONIZADO DESDE SUPABASE")
    lines.append(f"-- Generado automaticamente: {now_text}")
    lines.append("-- Incluye: tablas, columnas, constraints e indices")
    lines.append("-- =====================================================")
    lines.append("")

    lines.append("-- =====================================================")
    lines.append("-- EXTENSIONES")
    lines.append("-- =====================================================")
    for ext in extensions:
        lines.append(f'CREATE EXTENSION IF NOT EXISTS "{ext}";')
    lines.append("")

    lines.append("-- =====================================================")
    lines.append("-- ESQUEMAS")
    lines.append("-- =====================================================")
    for schema in schema_order:
        lines.append(f"CREATE SCHEMA IF NOT EXISTS {safe_ident(schema)};")
    lines.append("")

    lines.append("-- =====================================================")
    lines.append("-- TABLAS")
    lines.append("-- =====================================================")
    for table in tables:
        schema = str(table["table_schema"])
        table_name = str(table["table_name"])
        full_table = f"{safe_ident(schema)}.{safe_ident(table_name)}"

        lines.append(f"CREATE TABLE {full_table} (")
        table_columns = columns_by_table[(schema, table_name)]
        for idx, col in enumerate(table_columns):
            suffix = "," if idx < len(table_columns) - 1 else ""
            lines.append(f"    {build_column_sql(col)}{suffix}")
        lines.append(");")
        lines.append("")

    lines.append("-- =====================================================")
    lines.append("-- VISTAS")
    lines.append("-- =====================================================")
    for view in views:
        schema = safe_ident(str(view["view_schema"]))
        view_name = safe_ident(str(view["view_name"]))
        definition = str(view["view_definition"]).strip().rstrip(";")
        reloptions = str(view["reloptions"]) if view["reloptions"] is not None else ""

        with_options = ""
        if "security_invoker=true" in reloptions:
            with_options = " WITH (security_invoker = true)"

        lines.append(f"CREATE VIEW {schema}.{view_name}{with_options} AS")
        lines.append(definition + ";")
        lines.append("")

    lines.append("-- =====================================================")
    lines.append("-- CONSTRAINTS")
    lines.append("-- =====================================================")
    for con in constraints:
        schema = safe_ident(str(con["table_schema"]))
        table_name = safe_ident(str(con["table_name"]))
        conname = safe_ident(str(con["conname"]))
        definition = str(con["definition"])
        lines.append(f"ALTER TABLE {schema}.{table_name}")
        lines.append(f"    ADD CONSTRAINT {conname} {definition};")
        lines.append("")

    lines.append("-- =====================================================")
    lines.append("-- INDICES")
    lines.append("-- =====================================================")
    for idx in indexes:
        lines.append(f"{idx['indexdef']};")
    lines.append("")

    output_path = Path(args.output_file)
    output_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"SCHEMA_EXPORTED_OK -> {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
