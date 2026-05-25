import argparse
import os
from datetime import datetime
from pathlib import Path

import psycopg
from dotenv import load_dotenv


def _load_database_url() -> str:
    root = Path(__file__).resolve().parents[2]
    env_file = root / "backend" / ".env"
    load_dotenv(env_file)
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise RuntimeError("DATABASE_URL no encontrada en backend/.env")
    return db_url


def _build_overlap_candidates(cur):
    cur.execute("select id from heuristico.catalogo_accion where upper(nombre)='ELIMINAR' limit 1")
    row = cur.fetchone()
    if not row:
        raise RuntimeError("No existe accion ELIMINAR en heuristico.catalogo_accion")
    id_acc_eliminar = row[0]

    cur.execute(
        """
        select id
        from heuristico.condicion
        where upper(coalesce(indicador_codigo,''))='GENERAL_REUMATICOS'
        limit 1
        """
    )
    row = cur.fetchone()
    if not row:
        raise RuntimeError("No existe condicion GENERAL_REUMATICOS")
    id_cond_general = row[0]

    # Targets base bloqueantes de general reumaticos
    cur.execute(
        """
        select distinct
          coalesce(r.id_tipo_objetivo,0),
          coalesce(r.id_ingrediente,0),
          coalesce(r.id_grupo_alimentario,0),
          coalesce(r.id_subgrupo_alimentario,0),
          coalesce(r.id_etiqueta,0),
          coalesce(r.id_receta,0)
        from heuristico.regla r
        join heuristico.condicion_regla cr on cr.id_regla=r.id
        where cr.id_condicion=%s and r.id_accion=%s
        """,
        (id_cond_general, id_acc_eliminar),
    )
    general_signatures = set(cur.fetchall())

    # Reglas temporales/nutricionales candidatas
    cur.execute(
        """
        select
          cr.id_regla,
          cr.id_condicion,
          c.id_tipo_condicion,
          c.nombre as condicion_nombre,
          c.indicador_codigo,
          a.nombre as accion,
          coalesce(r.id_tipo_objetivo,0),
          coalesce(r.id_ingrediente,0),
          coalesce(r.id_grupo_alimentario,0),
          coalesce(r.id_subgrupo_alimentario,0),
          coalesce(r.id_etiqueta,0),
          coalesce(r.id_receta,0)
        from heuristico.regla r
        join heuristico.condicion_regla cr on cr.id_regla=r.id
        join heuristico.condicion c on c.id=cr.id_condicion
        join heuristico.catalogo_accion a on a.id=r.id_accion
        where c.id_tipo_condicion in (2,3)
        """
    )
    candidates = cur.fetchall()

    overlap = []
    for row in candidates:
        signature = tuple(row[6:12])
        if signature in general_signatures:
            overlap.append(row)
    return overlap


def _summaries(cur):
    cur.execute(
        """
        select c.id_tipo_condicion, a.nombre, count(*)
        from heuristico.regla r
        join heuristico.condicion_regla cr on cr.id_regla=r.id
        join heuristico.condicion c on c.id=cr.id_condicion
        join heuristico.catalogo_accion a on a.id=r.id_accion
        where c.id_tipo_condicion in (2,3)
        group by c.id_tipo_condicion, a.nombre
        order by c.id_tipo_condicion, a.nombre
        """
    )
    return cur.fetchall()


def _write_report(mode: str, overlap_rows, removed_links, removed_orphans, before_summary, after_summary):
    root = Path(__file__).resolve().parents[2]
    docs_dir = root / "docs"
    docs_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_path = docs_dir / f"reporte_overlap_general_reumaticos_{mode}_{ts}.txt"

    lines = []
    lines.append("REPORTE CONTROL OVERLAP VS GENERAL_REUMATICOS")
    lines.append("=" * 52)
    lines.append(f"Fecha: {datetime.now():%Y-%m-%d %H:%M:%S}")
    lines.append(f"Modo: {mode}")
    lines.append("")
    lines.append("Resumen antes")
    for t, acc, cnt in before_summary:
        tipo = "TEMPORAL" if t == 2 else "NUTRICIONAL"
        lines.append(f"- {tipo} | {acc} | {cnt}")
    lines.append("")
    lines.append(f"Overlaps detectados: {len(overlap_rows)}")
    if overlap_rows:
        lines.append("Detalle overlap (regla-condicion):")
        for r in overlap_rows:
            rid, cid, t, cname, code, acc, tobj, ing, grp, sub, etq, rec = r
            tipo = "TEMPORAL" if t == 2 else "NUTRICIONAL"
            lines.append(
                f"- tipo={tipo} | cond={cid}:{cname} ({code}) | accion={acc} | regla={rid} | "
                f"obj=({tobj},{ing},{grp},{sub},{etq},{rec})"
            )
    lines.append("")
    lines.append(f"Links eliminados: {removed_links}")
    lines.append(f"Reglas huerfanas eliminadas: {removed_orphans}")
    lines.append("")
    lines.append("Resumen despues")
    for t, acc, cnt in after_summary:
        tipo = "TEMPORAL" if t == 2 else "NUTRICIONAL"
        lines.append(f"- {tipo} | {acc} | {cnt}")

    report_path.write_text("\n".join(lines), encoding="utf-8")
    return report_path


def run(mode: str):
    db_url = _load_database_url()
    with psycopg.connect(db_url) as conn:
        with conn.cursor() as cur:
            before = _summaries(cur)
            overlap = _build_overlap_candidates(cur)

            removed_links = 0
            removed_orphans = 0
            if mode == "fix" and overlap:
                to_delete = [(r[0], r[1]) for r in overlap]
                cur.executemany(
                    "delete from heuristico.condicion_regla where id_regla=%s and id_condicion=%s",
                    to_delete,
                )
                removed_links = cur.rowcount
                cur.execute(
                    """
                    delete from heuristico.regla r
                    where not exists (
                      select 1 from heuristico.condicion_regla cr where cr.id_regla=r.id
                    )
                    """
                )
                removed_orphans = cur.rowcount
                conn.commit()
            else:
                conn.rollback()

            after = _summaries(cur)

    report = _write_report(mode, overlap, removed_links, removed_orphans, before, after)
    print(f"Modo: {mode}")
    print(f"Overlaps detectados: {len(overlap)}")
    print(f"Links eliminados: {removed_links}")
    print(f"Reglas huerfanas eliminadas: {removed_orphans}")
    print(f"Reporte: {report}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=(
            "Controla solapamientos de reglas temporales/nutricionales contra "
            "objetivos bloqueantes de GENERAL_REUMATICOS."
        )
    )
    parser.add_argument(
        "--mode",
        choices=["audit", "fix"],
        default="audit",
        help="audit: solo reporta; fix: elimina overlaps y reglas huerfanas.",
    )
    args = parser.parse_args()
    run(args.mode)
