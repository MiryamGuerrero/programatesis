from __future__ import annotations

import csv
from pathlib import Path
from urllib.parse import urlparse, unquote

import psycopg

ROOT_DIR = Path(__file__).resolve().parents[2]
ENV_FILE = ROOT_DIR / "backend" / ".env"
REF_SOURCE_CSV = ROOT_DIR / "supabase" / "oms_referencia_cleaned.csv"
PERC_SOURCE_CSV = ROOT_DIR / "supabase" / "oms_percentiles_cleaned.csv"
DETAIL_REPORT_CSV = ROOT_DIR / "supabase" / "oms_auditoria_fuente_vs_bd.csv"
SUMMARY_REPORT_CSV = ROOT_DIR / "supabase" / "oms_auditoria_resumen.csv"

REF_FIELDS = [
    "l",
    "m",
    "s",
    "sd4neg",
    "sd3neg",
    "sd2neg",
    "sd1neg",
    "sd0",
    "sd1",
    "sd2",
    "sd3",
    "sd4",
]

PERC_FIELDS = [
    "l",
    "m",
    "s",
    "stdev",
    "p01",
    "p1",
    "p3",
    "p5",
    "p10",
    "p15",
    "p25",
    "p50",
    "p75",
    "p85",
    "p90",
    "p95",
    "p97",
    "p99",
]

STATUS_MATCH = "MATCH"
STATUS_MISSING_IN_DB = "MISSING_IN_DB"
STATUS_EXTRA_IN_DB = "EXTRA_IN_DB"
STATUS_VALUE_MISMATCH = "VALUE_MISMATCH"


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


def to_float(value: str | float | int | None) -> float | None:
    if value is None:
        return None
    if isinstance(value, (float, int)):
        return round(float(value), 6)

    text = str(value).strip()
    if text == "":
        return None

    text = text.replace(",", ".")
    return round(float(text), 6)


def parse_project_ref(env: dict[str, str]) -> str:
    supabase_url = env.get("SUPABASE_URL", "").strip()
    if supabase_url:
        parsed = urlparse(supabase_url)
        host = parsed.hostname or ""
        parts = host.split(".")
        if len(parts) >= 1 and parts[0]:
            return parts[0]

    database_url = env.get("DATABASE_URL", "").strip()
    if database_url:
        parsed = urlparse(database_url)
        host = parsed.hostname or ""
        parts = host.split(".")
        if len(parts) >= 2 and parts[0] == "db":
            return parts[1]

    raise RuntimeError("No se pudo inferir project_ref desde SUPABASE_URL o DATABASE_URL")


def connect_via_pooler(env: dict[str, str]):
    database_url = env.get("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL no configurado en backend/.env")

    parsed = urlparse(database_url)
    password = unquote(parsed.password or "")
    dbname = (parsed.path or "/postgres").lstrip("/") or "postgres"

    project_ref = parse_project_ref(env)
    user = f"postgres.{project_ref}"

    region_hosts = [
        "aws-0-us-east-1.pooler.supabase.com",
        "aws-0-us-west-1.pooler.supabase.com",
        "aws-0-us-west-2.pooler.supabase.com",
        "aws-0-sa-east-1.pooler.supabase.com",
    ]

    last_error: Exception | None = None
    for host in region_hosts:
        try:
            connection = psycopg.connect(
                host=host,
                port=6543,
                user=user,
                password=password,
                dbname=dbname,
                sslmode="require",
                connect_timeout=10,
            )
            return connection
        except Exception as exc:  # pragma: no cover
            last_error = exc

    raise RuntimeError(f"No se pudo conectar por pooler Supabase: {last_error}")


def load_source_csv(path: Path, value_fields: list[str]) -> dict[tuple[str, str, int], dict]:
    if not path.exists():
        raise FileNotFoundError(f"No existe archivo fuente: {path}")

    payload: dict[tuple[str, str, int], dict] = {}
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            key = (row["indicador_codigo"], row["sexo_codigo"], int(row["meses"]))
            payload[key] = {
                "source": row.get("source", ""),
                "values": {field: to_float(row.get(field)) for field in value_fields},
            }

    return payload


def fetch_ref_db_rows(connection) -> dict[tuple[str, str, int], dict[str, float | None]]:
    sql = """
        select
            i.codigo,
            sx.codigo,
            r.meses,
            r.l,
            r.m,
            r.s,
            r.sd4neg,
            r.sd3neg,
            r.sd2neg,
            r.sd1neg,
            r.sd0,
            r.sd1,
            r.sd2,
            r.sd3,
            r.sd4
        from referencia.oms_referencia r
        join referencia.indicador_antropometrico i on i.id = r.id_indicador
        join usuarios.catalogo_sexo sx on sx.id = r.id_sexo
        where i.codigo in ('IMC_EDAD', 'TALLA_EDAD', 'PESO_EDAD')
    """

    payload: dict[tuple[str, str, int], dict[str, float | None]] = {}
    with connection.cursor() as cursor:
        cursor.execute(sql)
        for row in cursor.fetchall():
            key = (row[0], row[1], int(row[2]))
            payload[key] = {field: to_float(value) for field, value in zip(REF_FIELDS, row[3:])}

    return payload


def fetch_perc_db_rows(connection) -> dict[tuple[str, str, int], dict[str, float | None]]:
    sql = """
        select
            i.codigo,
            sx.codigo,
            p.meses,
            p.l,
            p.m,
            p.s,
            p.stdev,
            p.p01,
            p.p1,
            p.p3,
            p.p5,
            p.p10,
            p.p15,
            p.p25,
            p.p50,
            p.p75,
            p.p85,
            p.p90,
            p.p95,
            p.p97,
            p.p99
        from referencia.oms_percentil_referencia p
        join referencia.indicador_antropometrico i on i.id = p.id_indicador
        join usuarios.catalogo_sexo sx on sx.id = p.id_sexo
        where i.codigo in ('IMC_EDAD', 'TALLA_EDAD', 'PESO_EDAD')
    """

    payload: dict[tuple[str, str, int], dict[str, float | None]] = {}
    with connection.cursor() as cursor:
        cursor.execute(sql)
        for row in cursor.fetchall():
            key = (row[0], row[1], int(row[2]))
            payload[key] = {field: to_float(value) for field, value in zip(PERC_FIELDS, row[3:])}

    return payload


def compare_dataset(
    dataset_name: str,
    source_rows: dict[tuple[str, str, int], dict],
    db_rows: dict[tuple[str, str, int], dict],
    value_fields: list[str],
) -> tuple[list[dict], dict[str, int]]:
    all_keys = sorted(set(source_rows.keys()) | set(db_rows.keys()))

    detail_rows: list[dict] = []
    summary = {
        "source_rows": len(source_rows),
        "db_rows": len(db_rows),
        STATUS_MATCH: 0,
        STATUS_MISSING_IN_DB: 0,
        STATUS_EXTRA_IN_DB: 0,
        STATUS_VALUE_MISMATCH: 0,
    }

    for indicador, sexo, meses in all_keys:
        key = (indicador, sexo, meses)
        source_entry = source_rows.get(key)
        db_entry = db_rows.get(key)

        if source_entry is None and db_entry is not None:
            status = STATUS_EXTRA_IN_DB
            mismatch_fields = ""
            source_file = ""
        elif source_entry is not None and db_entry is None:
            status = STATUS_MISSING_IN_DB
            mismatch_fields = ""
            source_file = source_entry.get("source", "")
        else:
            assert source_entry is not None and db_entry is not None
            source_values = source_entry["values"]
            mismatch_list: list[str] = []
            for field in value_fields:
                source_value = source_values.get(field)
                db_value = db_entry.get(field)

                if source_value is None and db_value is None:
                    continue
                if source_value is None or db_value is None:
                    mismatch_list.append(field)
                    continue
                if abs(source_value - db_value) > 1e-6:
                    mismatch_list.append(field)

            if mismatch_list:
                status = STATUS_VALUE_MISMATCH
                mismatch_fields = "|".join(mismatch_list)
            else:
                status = STATUS_MATCH
                mismatch_fields = ""

            source_file = source_entry.get("source", "")

        summary[status] += 1

        detail_rows.append(
            {
                "dataset": dataset_name,
                "indicador_codigo": indicador,
                "sexo_codigo": sexo,
                "meses": meses,
                "status": status,
                "mismatch_fields": mismatch_fields,
                "source": source_file,
            }
        )

    return detail_rows, summary


def write_detail_report(rows: list[dict]) -> None:
    DETAIL_REPORT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with DETAIL_REPORT_CSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "dataset",
                "indicador_codigo",
                "sexo_codigo",
                "meses",
                "status",
                "mismatch_fields",
                "source",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)


def write_summary_report(summary_rows: list[dict]) -> None:
    with SUMMARY_REPORT_CSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "dataset",
                "source_rows",
                "db_rows",
                STATUS_MATCH,
                STATUS_MISSING_IN_DB,
                STATUS_EXTRA_IN_DB,
                STATUS_VALUE_MISMATCH,
            ],
        )
        writer.writeheader()
        writer.writerows(summary_rows)


def main() -> None:
    env = parse_env_file(ENV_FILE)

    source_ref = load_source_csv(REF_SOURCE_CSV, REF_FIELDS)
    source_perc = load_source_csv(PERC_SOURCE_CSV, PERC_FIELDS)

    with connect_via_pooler(env) as connection:
        db_ref = fetch_ref_db_rows(connection)
        db_perc = fetch_perc_db_rows(connection)

    ref_detail, ref_summary = compare_dataset("oms_referencia", source_ref, db_ref, REF_FIELDS)
    perc_detail, perc_summary = compare_dataset("oms_percentil_referencia", source_perc, db_perc, PERC_FIELDS)

    write_detail_report(ref_detail + perc_detail)
    write_summary_report(
        [
            {
                "dataset": "oms_referencia",
                **ref_summary,
            },
            {
                "dataset": "oms_percentil_referencia",
                **perc_summary,
            },
        ]
    )

    print("DETAIL_REPORT", DETAIL_REPORT_CSV)
    print("SUMMARY_REPORT", SUMMARY_REPORT_CSV)
    print(
        "OMS_REFERENCIA",
        f"source={ref_summary['source_rows']}",
        f"db={ref_summary['db_rows']}",
        f"match={ref_summary[STATUS_MATCH]}",
        f"missing={ref_summary[STATUS_MISSING_IN_DB]}",
        f"extra={ref_summary[STATUS_EXTRA_IN_DB]}",
        f"mismatch={ref_summary[STATUS_VALUE_MISMATCH]}",
    )
    print(
        "OMS_PERCENTIL_REFERENCIA",
        f"source={perc_summary['source_rows']}",
        f"db={perc_summary['db_rows']}",
        f"match={perc_summary[STATUS_MATCH]}",
        f"missing={perc_summary[STATUS_MISSING_IN_DB]}",
        f"extra={perc_summary[STATUS_EXTRA_IN_DB]}",
        f"mismatch={perc_summary[STATUS_VALUE_MISMATCH]}",
    )


if __name__ == "__main__":
    main()
