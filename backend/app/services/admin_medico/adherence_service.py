from app.repositories.interaccion_repository import (
    get_average_pain_for_patient,
    get_patient_id_by_plan,
    get_plan_item_statuses,
)


def _build_comparison_message(adherencia_pct: float, dolor_promedio: float | None) -> str | None:
    if dolor_promedio is None:
        return None

    if adherencia_pct >= 75 and dolor_promedio <= 3:
        return "Adherencia alta con dolor controlado"
    if adherencia_pct < 50 and dolor_promedio >= 6:
        return "Adherencia baja asociada a dolor elevado"
    return "Tendencia mixta entre adherencia y dolor"


def calculate_adherence(id_plan: int, id_paciente: str | None = None) -> dict:
    rows = get_plan_item_statuses(id_plan)

    by_item: dict[int, list[str]] = {}
    for row in rows:
        item_id = int(row["id_plan_item"])
        status = str(row.get("estado") or "")
        by_item.setdefault(item_id, []).append(status.upper())

    total_items = len(by_item)
    if total_items == 0:
        patient_id = id_paciente or get_patient_id_by_plan(id_plan)
        pain_avg = get_average_pain_for_patient(patient_id) if patient_id else None
        return {
            "total_items": 0,
            "items_reportados": 0,
            "adherencia_pct": 0.0,
            "dolor_promedio": pain_avg,
            "comparacion": _build_comparison_message(0.0, pain_avg),
        }

    reported = 0
    adherence_units = 0.0

    for statuses in by_item.values():
        non_empty = [s for s in statuses if s]
        if non_empty:
            reported += 1

        if any("COMPLETO" in s for s in non_empty):
            adherence_units += 1.0
        elif any("PARCIAL" in s for s in non_empty):
            adherence_units += 0.5

    adherence_pct = round((adherence_units / total_items) * 100.0, 2)
    patient_id = id_paciente or get_patient_id_by_plan(id_plan)
    pain_avg = get_average_pain_for_patient(patient_id) if patient_id else None

    return {
        "total_items": total_items,
        "items_reportados": reported,
        "adherencia_pct": adherence_pct,
        "dolor_promedio": pain_avg,
        "comparacion": _build_comparison_message(adherence_pct, pain_avg),
    }
