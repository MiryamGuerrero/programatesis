// @ts-nocheck
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Missing bearer token" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { patient_id, days = 7, meals_per_day = 4, start_date } = await req.json();
    if (!patient_id) {
      return new Response(JSON.stringify({ error: "patient_id is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRole) {
      return new Response(JSON.stringify({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const admin = createClient(supabaseUrl, serviceRole);
    const parsedDays = Number.isFinite(Number(days)) ? Math.max(1, Math.min(30, Number(days))) : 7;
    const parsedMeals = Number.isFinite(Number(meals_per_day))
      ? Math.max(1, Math.min(8, Number(meals_per_day)))
      : 4;
    const planStart = typeof start_date === "string" && start_date.trim().length > 0
      ? new Date(start_date)
      : new Date();

    if (Number.isNaN(planStart.getTime())) {
      return new Response(JSON.stringify({ error: "start_date is invalid" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const planEnd = new Date(planStart);
    planEnd.setDate(planEnd.getDate() + (parsedDays - 1));

    const isoDate = (d: Date) => d.toISOString().slice(0, 10);

    const ensureCatalogValue = async (
      table: "catalogo_tipo_plan" | "catalogo_origen_plan" | "catalogo_estado_plan",
      codigo: string,
    ): Promise<number> => {
      const existing = await admin
        .schema("interaccion")
        .from(table)
        .select("id")
        .eq("codigo", codigo)
        .limit(1)
        .maybeSingle();
      if (existing.error) throw existing.error;
      if (existing.data?.id) return Number(existing.data.id);

      const inserted = await admin
        .schema("interaccion")
        .from(table)
        .insert({ codigo })
        .select("id")
        .single();
      if (inserted.error) throw inserted.error;
      return Number(inserted.data.id);
    };

    const tipoPlanId = await ensureCatalogValue("catalogo_tipo_plan", "SEMANAL");
    const origenPlanId = await ensureCatalogValue("catalogo_origen_plan", "SISTEMA");
    const estadoPlanId = await ensureCatalogValue("catalogo_estado_plan", "ACTIVO");

    let momentosResp = await admin
      .schema("nutricion")
      .from("momento_comida")
      .select("id, nombre")
      .order("orden", { ascending: true })
      .order("id", { ascending: true })
      .limit(parsedMeals);
    if (momentosResp.error) throw momentosResp.error;

    let momentos = momentosResp.data ?? [];
    if (momentos.length === 0) {
      const payload = Array.from({ length: parsedMeals }, (_, idx) => ({
        nombre: `Comida ${idx + 1}`,
        orden: idx + 1,
      }));
      const inserted = await admin
        .schema("nutricion")
        .from("momento_comida")
        .insert(payload)
        .select("id, nombre")
        .order("id", { ascending: true });
      if (inserted.error) throw inserted.error;
      momentos = inserted.data ?? [];
    }

    const recetasResp = await admin
      .schema("nutricion")
      .from("receta")
      .select("id, nombre")
      .eq("activa", true)
      .order("id", { ascending: true })
      .limit(300);
    if (recetasResp.error) throw recetasResp.error;

    const recetas = recetasResp.data ?? [];
    if (recetas.length === 0) {
      return new Response(JSON.stringify({
        error: "No hay recetas activas en nutricion.receta para construir el plan",
      }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const planInsert = await admin
      .schema("interaccion")
      .from("plan_nutricional")
      .insert({
        id_paciente: patient_id,
        id_tipo_plan: tipoPlanId,
        id_origen_plan: origenPlanId,
        id_estado_plan: estadoPlanId,
        comidas_por_dia: parsedMeals,
        fecha_inicio: isoDate(planStart),
        fecha_fin: isoDate(planEnd),
        vigente: true,
      })
      .select("id, fecha_inicio, fecha_fin")
      .single();

    if (planInsert.error) throw planInsert.error;

    const planId = Number(planInsert.data.id);
    const items: Array<{ id_plan: number; fecha_programada: string; id_momento: number; id_receta: number }> = [];

    let cursor = 0;
    for (let day = 0; day < parsedDays; day += 1) {
      const current = new Date(planStart);
      current.setDate(planStart.getDate() + day);
      const fechaProgramada = isoDate(current);

      for (const momento of momentos) {
        const receta = recetas[cursor % recetas.length];
        cursor += 1;
        items.push({
          id_plan: planId,
          fecha_programada: fechaProgramada,
          id_momento: Number(momento.id),
          id_receta: Number(receta.id),
        });
      }
    }

    const itemsInsert = await admin
      .schema("interaccion")
      .from("plan_item")
      .insert(items)
      .select("id, fecha_programada, id_momento, id_receta");
    if (itemsInsert.error) throw itemsInsert.error;

    return new Response(JSON.stringify({
      ok: true,
      plan: {
        id: planId,
        fecha_inicio: planInsert.data.fecha_inicio,
        fecha_fin: planInsert.data.fecha_fin,
        total_items: items.length,
      },
      items: itemsInsert.data ?? [],
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : "unknown" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});
