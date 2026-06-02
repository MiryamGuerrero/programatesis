import os
import sys
from pathlib import Path

import psycopg

ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = ROOT.parent
sys.path.insert(0, str(ROOT))

from app.domain.servicios.restricciones_alimentarias import (  # noqa: E402
    RESTRICCIONES_ALIMENTARIAS,
    resolver_codigo_restriccion,
)


def load_env() -> None:
    env_path = ROOT / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.strip().startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def expand_restrictions(cur, codigos: set[str]) -> tuple[set[int], set[int]]:
    subgrupos: set[int] = set()
    ingredientes: set[int] = set()

    for codigo in codigos:
        restriccion = RESTRICCIONES_ALIMENTARIAS.get(resolver_codigo_restriccion(codigo))
        if not restriccion:
            continue
        subgrupos.update(restriccion.subgrupos_ids)
        ingredientes.update(restriccion.ingredientes_ids)

        for patron in restriccion.patrones_subgrupo:
            cur.execute(
                "select id from nutricion.subgrupo_alimentario where lower(nombre) like %s",
                (f"%{patron.lower()}%",),
            )
            subgrupos.update(int(r[0]) for r in cur.fetchall() if r and r[0] is not None)

        for patron in restriccion.patrones_ingrediente:
            cur.execute(
                "select id from nutricion.ingrediente where lower(nombre) like %s",
                (f"%{patron.lower()}%",),
            )
            ingredientes.update(int(r[0]) for r in cur.fetchall() if r and r[0] is not None)

        if restriccion.etiquetas_bloqueadas:
            cur.execute(
                """
                select distinct ie.id_ingrediente
                from nutricion.ingrediente_etiqueta ie
                join nutricion.etiqueta_nutricional e on e.id = ie.id_etiqueta
                where e.codigo = any(%s)
                """,
                (list(restriccion.etiquetas_bloqueadas),),
            )
            ingredientes.update(int(r[0]) for r in cur.fetchall() if r and r[0] is not None)

    return subgrupos, ingredientes


def main() -> None:
    load_env()
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise RuntimeError("DATABASE_URL no encontrada en backend/.env")

    total_subgrupos = 0
    total_ingredientes = 0
    pacientes = 0

    with psycopg.connect(db_url, autocommit=False) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                select id_paciente, array_agg(codigo_restriccion)
                from clinico.restriccion_paciente
                where activa = true
                group by id_paciente
                """
            )
            rows = cur.fetchall()
            for id_paciente, codigos_raw in rows:
                codigos = {str(c).strip().upper() for c in (codigos_raw or []) if str(c).strip()}
                subgrupos, ingredientes = expand_restrictions(cur, codigos)
                pacientes += 1

                if subgrupos:
                    cur.execute(
                        """
                        delete from clinico.alergia_paciente_subgrupo
                        where id_paciente = %s
                          and id_subgrupo_alimentario = any(%s)
                        """,
                        (id_paciente, list(subgrupos)),
                    )
                    total_subgrupos += cur.rowcount

                if ingredientes:
                    cur.execute(
                        """
                        delete from clinico.alergia_paciente_ingrediente
                        where id_paciente = %s
                          and id_ingrediente = any(%s)
                        """,
                        (id_paciente, list(ingredientes)),
                    )
                    total_ingredientes += cur.rowcount

        conn.commit()

    print(
        f"Limpieza aplicada. Pacientes revisados: {pacientes}. "
        f"Subgrupos derivados eliminados: {total_subgrupos}. "
        f"Ingredientes derivados eliminados: {total_ingredientes}."
    )


if __name__ == "__main__":
    main()
