from __future__ import annotations

import csv
import os
from pathlib import Path
from typing import Iterable

import psycopg


ROOT = Path(__file__).resolve().parents[2]
OMS_DIR = ROOT / "oms"
BACKEND_DIR = ROOT / "backend"


def load_env() -> None:
    env_path = BACKEND_DIR / ".env"
    for line in env_path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.strip().startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def csv_rows(path: Path) -> Iterable[list[str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        reader = csv.reader(fh)
        next(reader)
        for row in reader:
            yield [None if value == "" else value for value in row]


def copy_csv(cur: psycopg.Cursor, table: str, columns: list[str], filename: str) -> int:
    path = OMS_DIR / filename
    count = 0
    column_sql = ", ".join(columns)
    with cur.copy(f"COPY {table} ({column_sql}) FROM STDIN") as copy:
        for row in csv_rows(path):
            copy.write_row(row)
            count += 1
    return count


def scalar(cur: psycopg.Cursor, sql: str, params: tuple = ()) -> int:
    cur.execute(sql, params)
    return int(cur.fetchone()[0])


def validate(cur: psycopg.Cursor) -> None:
    required_counts = {
        "referencia.condicion": 1,
        "referencia.oms_indicador": 6,
        "referencia.oms_referencia_zscore": 6000,
        "referencia.oms_referencia_percentil": 6000,
        "referencia.oms_clasificacion_zscore": 20,
        "referencia.oms_fuente_archivo": 1,
    }
    for table, min_count in required_counts.items():
        count = scalar(cur, f"select count(*) from {table}")
        if count < min_count:
            raise RuntimeError(f"{table} tiene {count} filas; se esperaban al menos {min_count}")
        print(f"OK {table}: {count} filas")

    for table in ("oms_referencia_zscore", "oms_referencia_percentil"):
        duplicates = scalar(
            cur,
            f"""
            select count(*)
            from (
              select ref_code, sexo, coalesce(edad_meses,-1), coalesce(edad_dias,-1), coalesce(medida_cm,-1), count(*)
              from referencia.{table}
              group by 1,2,3,4,5
              having count(*) > 1
            ) d
            """,
        )
        if duplicates:
            raise RuntimeError(f"referencia.{table} tiene {duplicates} claves duplicadas")
        print(f"OK referencia.{table}: sin duplicados")

    cur.execute("select ref_code from referencia.oms_indicador order by ref_code")
    indicators = {row[0] for row in cur.fetchall()}
    expected = {"WFL", "WFH", "BMI", "LHFA", "HFA", "WFA"}
    missing = expected - indicators
    if missing:
        raise RuntimeError(f"Faltan indicadores: {sorted(missing)}")
    print(f"OK indicadores: {sorted(indicators)}")

    cur.execute("select sexo, count(*) from referencia.oms_referencia_zscore group by sexo")
    sex_counts = dict(cur.fetchall())
    if set(sex_counts) != {"M", "F"}:
        raise RuntimeError(f"Sexos invalidos en zscore: {sex_counts}")
    print(f"OK sexos zscore: {sex_counts}")

    cur.execute(
        """
        select ref_code, min(edad_meses), max(edad_meses), min(edad_dias), max(edad_dias), min(medida_cm), max(medida_cm)
        from referencia.oms_referencia_zscore
        group by ref_code
        order by ref_code
        """
    )
    for row in cur.fetchall():
        print("RANGO", row)

    z_values = scalar(
        cur,
        """
        select count(*)
        from referencia.oms_referencia_zscore
        where sd3neg is not null and sd2neg is not null and sd1 is not null and sd2 is not null and sd3 is not null
        """,
    )
    if z_values < 6000:
        raise RuntimeError("Valores z-score incompletos")
    print(f"OK valores z-score completos: {z_values}")


def main() -> None:
    load_env()
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL no esta configurado")

    schema_sql = (OMS_DIR / "schema_referencia.sql").read_text(encoding="utf-8-sig")
    with psycopg.connect(database_url, autocommit=False) as conn:
        with conn.cursor() as cur:
            print("Borrando esquema referencia...")
            cur.execute("drop schema if exists referencia cascade")
            cur.execute(schema_sql)

            print("Importando CSV limpios...")
            loaded = {
                "condicion": copy_csv(
                    cur,
                    "referencia.condicion",
                    ["id", "nombre", "tipo", "edad_uso", "grupo_diagnostico"],
                    "condicion.csv",
                ),
                "oms_indicador": copy_csv(
                    cur,
                    "referencia.oms_indicador",
                    ["ref_code", "nombre", "estandar", "edad_aplicable", "clave_busqueda", "variable_observada", "uso_clinico"],
                    "oms_indicador.csv",
                ),
                "oms_referencia_zscore": copy_csv(
                    cur,
                    "referencia.oms_referencia_zscore",
                    [
                        "ref_code", "sexo", "edad_meses", "edad_dias", "medida_cm", "l", "m", "s", "stdev",
                        "sd5neg", "sd4neg", "sd3neg", "sd2neg", "sd1neg", "sd0", "sd1", "sd2", "sd3", "sd4", "source_file",
                    ],
                    "oms_referencia_zscore.csv",
                ),
                "oms_referencia_percentil": copy_csv(
                    cur,
                    "referencia.oms_referencia_percentil",
                    [
                        "ref_code", "sexo", "edad_meses", "edad_dias", "medida_cm", "l", "m", "s", "stdev",
                        "p01", "p1", "p3", "p5", "p10", "p15", "p25", "p50", "p75", "p85", "p90", "p95", "p97", "p99", "p999", "source_file",
                    ],
                    "oms_referencia_percentil.csv",
                ),
                "oms_clasificacion_zscore": copy_csv(
                    cur,
                    "referencia.oms_clasificacion_zscore",
                    [
                        "ref_code", "edad_meses_min", "edad_meses_max", "z_min", "z_max", "incluye_min",
                        "incluye_max", "diagnostico", "condicion_id", "grupo_diagnostico",
                    ],
                    "oms_clasificacion_zscore.csv",
                ),
                "oms_fuente_archivo": copy_csv(
                    cur,
                    "referencia.oms_fuente_archivo",
                    [
                        "source_file", "ref_code_detectado", "tipo_tabla", "sexo", "usado_en_csv_limpio",
                        "filas_datos", "columnas", "primer_valor_clave", "ultimo_valor_clave", "sha256", "nota",
                    ],
                    "oms_fuente_archivo.csv",
                ),
            }
            for name, count in loaded.items():
                print(f"Importado {name}: {count}")

            validate(cur)
        conn.commit()
    print("Reset de referencia OMS completado correctamente.")


if __name__ == "__main__":
    main()
