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

    const { ingrediente_id } = await req.json();
    if (!ingrediente_id || Number(ingrediente_id) <= 0) {
      return new Response(JSON.stringify({ error: "ingrediente_id is required" }), {
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

    const { data, error } = await admin
      .schema("nutricion")
      .from("sustituto_ingrediente")
      .select("id_ingrediente_reemplazo, ratio_conversion, mensaje_aviso, ingrediente:id_ingrediente_reemplazo(nombre)")
      .eq("id_ingrediente_original", ingrediente_id)
      .eq("activo", true)
      .order("id", { ascending: true })
      .limit(10);

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const reemplazos = (data ?? []).map((item) => ({
      id_ingrediente_reemplazo: item.id_ingrediente_reemplazo,
      nombre: item.ingrediente?.nombre ?? null,
      ratio_conversion: item.ratio_conversion,
      mensaje_aviso: item.mensaje_aviso,
    }));

    return new Response(JSON.stringify({ ok: true, reemplazos }), {
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
