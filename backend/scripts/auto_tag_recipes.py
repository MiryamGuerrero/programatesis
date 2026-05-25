import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv


def infer_tags_for_recipe(cur, recipe_id: int) -> set[int]:
    cur.execute(
        """
        select distinct r.id_etiqueta
        from heuristico.regla r
        join heuristico.condicion_regla cr on cr.id_regla = r.id
        join heuristico.condicion c on c.id = cr.id_condicion
        where r.id_etiqueta is not null
          and upper(coalesce(r.origen_regla, 'CLINICA')) = 'CLINICA'
          and upper(coalesce(c.indicador_codigo, '')) in (
            'LUPUS_ERITEMATOSO_SISTEMICO',
            'ARTRITIS_IDIOPATICA_JUVENIL'
          )
        """
    )
    target_tags = {int(r[0]) for r in cur.fetchall() if r and r[0] is not None}
    if not target_tags:
        return set()

    cur.execute(
        """
        select
            ri.id_ingrediente,
            coalesce(ri.peso_en_gramos, 0)::numeric as gramos,
            coalesce(ri.es_principal, false) as es_principal
        from nutricion.receta_ingrediente ri
        where ri.id_receta = %s
        """,
        (recipe_id,),
    )
    rows = cur.fetchall()
    if not rows:
        return set()

    grams_by_ing: dict[int, float] = {}
    principal: set[int] = set()
    total = 0.0
    for iid, grams, is_main in rows:
        iid = int(iid)
        g = float(grams or 0)
        grams_by_ing[iid] = grams_by_ing.get(iid, 0.0) + g
        total += g
        if is_main:
            principal.add(iid)

    ing_ids = list(grams_by_ing.keys())
    if not ing_ids:
        return set()

    cur.execute(
        """
        select id_ingrediente, id_etiqueta
        from nutricion.ingrediente_etiqueta
        where id_ingrediente = any(%s)
          and id_etiqueta = any(%s)
        """,
        (ing_ids, list(target_tags)),
    )
    rels = cur.fetchall()
    if not rels:
        return set()

    grams_by_tag: dict[int, float] = {}
    tags_from_main: set[int] = set()
    for iid, tag_id in rels:
        iid = int(iid)
        tag_id = int(tag_id)
        grams_by_tag[tag_id] = grams_by_tag.get(tag_id, 0.0) + grams_by_ing.get(iid, 0.0)
        if iid in principal:
            tags_from_main.add(tag_id)

    inferred: set[int] = set()
    for tag_id, grams in grams_by_tag.items():
        ratio = (grams / total) if total > 0 else 0.0
        if tag_id in tags_from_main or ratio >= 0.20:
            inferred.add(tag_id)
    return inferred


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    load_dotenv(root / "backend" / ".env")
    db = os.getenv("DATABASE_URL")
    if not db:
        raise RuntimeError("DATABASE_URL no encontrada en backend/.env")

    with psycopg.connect(db) as conn:
        conn.autocommit = False
        with conn.cursor() as cur:
            cur.execute("set statement_timeout = 0")
            cur.execute("select id from nutricion.receta")
            recipe_ids = [int(r[0]) for r in cur.fetchall()]

            inserted = 0
            touched = 0
            processed = 0
            for rid in recipe_ids:
                inferred = infer_tags_for_recipe(cur, rid)
                if not inferred:
                    processed += 1
                    if processed % 50 == 0:
                        conn.commit()
                    continue

                cur.execute(
                    "select id_etiqueta from nutricion.receta_etiqueta where id_receta = %s",
                    (rid,),
                )
                existing = {int(r[0]) for r in cur.fetchall()}
                missing = sorted(inferred - existing)
                if not missing:
                    processed += 1
                    if processed % 50 == 0:
                        conn.commit()
                    continue

                cur.executemany(
                    "insert into nutricion.receta_etiqueta (id_receta, id_etiqueta) values (%s, %s) on conflict do nothing",
                    [(rid, eid) for eid in missing],
                )
                touched += 1
                inserted += len(missing)
                processed += 1
                if processed % 50 == 0:
                    conn.commit()

        conn.commit()
    print(f"Recetas actualizadas: {touched}")
    print(f"Etiquetas agregadas: {inserted}")


if __name__ == "__main__":
    main()
