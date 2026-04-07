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

    const { patient_id, momento_codigo } = await req.json();
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
    let idMomento: number | null = null;

    if (typeof momento_codigo === "string" && momento_codigo.trim().length > 0) {
      const normalized = momento_codigo.trim().toLowerCase();
      const momentoResp = await admin
        .schema("nutricion")
        .from("momento_comida")
        .select("id, nombre")
        .order("id", { ascending: true });
      if (momentoResp.error) throw momentoResp.error;

      const found = (momentoResp.data ?? []).find((m) => {
        const name = String(m.nombre ?? "").trim().toLowerCase();
        return name === normalized;
      });
      if (found) {
        idMomento = Number(found.id);
      }
    }

    let recetasQuery = admin
      .schema("nutricion")
      .from("receta")
      .select("id, nombre, activa")
      .eq("activa", true)
      .order("id", { ascending: true })
      .limit(10);

    if (idMomento !== null) {
      const recetaMomentoResp = await admin
        .schema("nutricion")
        .from("receta_momento")
        .select("id_receta")
        .eq("id_momento", idMomento);
      if (recetaMomentoResp.error) throw recetaMomentoResp.error;

      const ids = [...new Set((recetaMomentoResp.data ?? []).map((x) => Number(x.id_receta)))];
      if (ids.length === 0) {
        return new Response(JSON.stringify({
          ok: true,
          paciente: patient_id,
          recomendaciones: [],
          mensaje: "No hay recetas asignadas para el momento solicitado",
        }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      recetasQuery = recetasQuery.in("id", ids);
    }

    const recetasResp = await recetasQuery;
    if (recetasResp.error) throw recetasResp.error;

    const recomendaciones = (recetasResp.data ?? []).map((r) => ({
      id_receta: Number(r.id),
      nombre: String(r.nombre ?? ""),
    }));

    return new Response(JSON.stringify({
      ok: true,
      paciente: patient_id,
      recomendaciones,
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
