import json
import os

import psycopg
from dotenv import load_dotenv


def fetch_all(cur, query, params=None):
    if params is None:
        cur.execute(query)
    else:
        cur.execute(query, params)
    return cur.fetchall()


def main() -> None:
    load_dotenv(".env")
    url = os.getenv("DATABASE_URL")
    if not url:
        print(json.dumps({"error": "DATABASE_URL missing"}, ensure_ascii=False, indent=2))
        return

    out: dict[str, object] = {}
    with psycopg.connect(url, autocommit=True, prepare_threshold=None) as conn:
        with conn.cursor() as cur:
            out["schemas"] = [
                r[0]
                for r in fetch_all(
                    cur,
                    """
                    select schema_name
                    from information_schema.schemata
                    where schema_name not in ('pg_catalog','information_schema','pg_toast')
                      and schema_name not like 'pg_%'
                    order by schema_name
                    """,
                )
            ]

            out["security_or_log_tables"] = [
                f"{s}.{t}"
                for s, t in fetch_all(
                    cur,
                    """
                    select table_schema, table_name
                    from information_schema.tables
                    where table_type='BASE TABLE'
                      and (
                        lower(table_name) like '%log%'
                        or lower(table_schema) like '%seguridad%'
                        or lower(table_schema) like '%security%'
                      )
                    order by table_schema, table_name
                    """,
                )
            ]

            checks = {
                "seguridad.log_seguridad": ("seguridad", "log_seguridad"),
                "seguridad.log_auditoria": ("seguridad", "log_auditoria"),
                "seguridad.log_error": ("seguridad", "log_error"),
            }

            for key, (schema, table) in checks.items():
                exists = fetch_all(
                    cur,
                    """
                    select exists (
                        select 1
                        from information_schema.tables
                        where table_schema=%s and table_name=%s
                    )
                    """,
                    (schema, table),
                )[0][0]
                out[f"{key}.exists"] = bool(exists)

                if not exists:
                    continue

                out[f"{key}.columns"] = [
                    {"name": c, "type": d, "nullable": n}
                    for c, d, n in fetch_all(
                        cur,
                        """
                        select column_name, data_type, is_nullable
                        from information_schema.columns
                        where table_schema=%s and table_name=%s
                        order by ordinal_position
                        """,
                        (schema, table),
                    )
                ]

                rls_row = fetch_all(
                    cur,
                    """
                    select c.relrowsecurity
                    from pg_class c
                    join pg_namespace n on n.oid = c.relnamespace
                    where n.nspname=%s and c.relname=%s and c.relkind='r'
                    """,
                    (schema, table),
                )
                out[f"{key}.rls_enabled"] = bool(rls_row[0][0]) if rls_row else None

                out[f"{key}.policies"] = [
                    {
                        "policy": p,
                        "cmd": cmd,
                        "roles": roles,
                        "using": q,
                        "with_check": wc,
                    }
                    for p, cmd, roles, q, wc in fetch_all(
                        cur,
                        """
                        select policyname, cmd, roles, qual, with_check
                        from pg_policies
                        where schemaname=%s and tablename=%s
                        order by policyname
                        """,
                        (schema, table),
                    )
                ]

                out[f"{key}.triggers"] = [
                    {"name": n, "def": d}
                    for n, d in fetch_all(
                        cur,
                        """
                        select t.tgname, pg_get_triggerdef(t.oid)
                        from pg_trigger t
                        join pg_class c on c.oid=t.tgrelid
                        join pg_namespace n on n.oid=c.relnamespace
                        where not t.tgisinternal
                          and n.nspname=%s
                          and c.relname=%s
                        order by t.tgname
                        """,
                        (schema, table),
                    )
                ]

            out["all_policies_in_seguridad"] = [
                {
                    "schema": s,
                    "table": t,
                    "policy": p,
                    "cmd": cmd,
                    "roles": roles,
                    "using": q,
                    "with_check": wc,
                }
                for s, t, p, cmd, roles, q, wc in fetch_all(
                    cur,
                    """
                    select schemaname, tablename, policyname, cmd, roles, qual, with_check
                    from pg_policies
                    where schemaname='seguridad'
                    order by tablename, policyname
                    """,
                )
            ]

            out["all_triggers_in_seguridad"] = [
                {"schema": s, "table": t, "trigger": n, "def": d}
                for s, t, n, d in fetch_all(
                    cur,
                    """
                    select n.nspname, c.relname, t.tgname, pg_get_triggerdef(t.oid)
                    from pg_trigger t
                    join pg_class c on c.oid=t.tgrelid
                    join pg_namespace n on n.oid=c.relnamespace
                    where not t.tgisinternal and n.nspname='seguridad'
                    order by c.relname, t.tgname
                    """,
                )
            ]

            out["functions_in_seguridad"] = [
                f"{s}.{f}"
                for s, f in fetch_all(
                    cur,
                    """
                    select n.nspname, p.proname
                    from pg_proc p
                    join pg_namespace n on n.oid = p.pronamespace
                    where n.nspname = 'seguridad'
                    order by n.nspname, p.proname
                    """,
                )
            ]

            out["security_log_indexes"] = [
                {
                    "table": f"{s}.{t}",
                    "index": i,
                    "def": d,
                }
                for s, t, i, d in fetch_all(
                    cur,
                    """
                    select schemaname, tablename, indexname, indexdef
                    from pg_indexes
                    where schemaname='seguridad' and tablename in ('log_auditoria','log_error')
                    order by tablename, indexname
                    """,
                )
            ]

            out["security_log_grants"] = [
                {
                    "table": t,
                    "grantee": g,
                    "privilege": p,
                }
                for t, g, p in fetch_all(
                    cur,
                    """
                    select table_name, grantee, privilege_type
                    from information_schema.role_table_grants
                    where table_schema='seguridad'
                      and table_name in ('log_auditoria','log_error')
                      and grantee in ('anon','authenticated','service_role')
                    order by table_name, grantee, privilege_type
                    """,
                )
            ]

    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
