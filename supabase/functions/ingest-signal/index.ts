import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-api-key",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function callBridge(action: "execute" | "close", ventanaId: string): Promise<void> {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRole) return;
  try {
    await fetch(`${url}/functions/v1/deriv-bridge`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${serviceRole}`,
      },
      body: JSON.stringify({ action, ventana_id: ventanaId }),
    });
  } catch (_) {
    console.error(`[ingest] callBridge ${action} failed`);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const apiKey = req.headers.get("x-api-key");
    const expected = Deno.env.get("INGEST_API_KEY");
    if (!apiKey || !expected || apiKey !== expected) {
      return json({ ok: false, error: "Unauthorized" }, 401);
    }

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch (_) {
      return json({ ok: false, error: "Invalid JSON body" }, 400);
    }

    const payload = (body.entry ?? body.close ?? body) as Record<string, unknown>;
    const type = payload?.type;

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    if (type === "entry") {
      const { signal_id, symbol, direction } = payload as {
        signal_id?: unknown; symbol?: unknown; direction?: unknown;
      };

      if (!signal_id || !symbol || !direction) {
        return json({ ok: false, error: "Missing required fields" }, 400);
      }
      if (direction !== "compra" && direction !== "venta") {
        return json({ ok: false, error: "Direccion invalida" }, 400);
      }

      const sym = String(symbol).toUpperCase();
      const tipo = sym.includes("BOOM") ? "boom" : sym.includes("CRASH") ? "crash" : null;
      if (!tipo) {
        return json({ ok: false, error: "Simbolo no soportado" }, 400);
      }

      const { data: inserted, error } = await admin
        .from("ventanas_senales")
        .insert({
          deriv_symbol: String(symbol),
          tipo,
          direccion: String(direction),
          estado: "activa",
          senal_apertura: new Date().toISOString(),
          fecha_inicio: new Date().toISOString(),
          external_signal_id: String(signal_id),
        })
        .select("id")
        .single();

      if (error) {
        if (error.code === "23505") return json({ ok: true, duplicated: true });
        throw error;
      }

      if (inserted?.id) await callBridge("execute", inserted.id);

      return json({ ok: true });
    }

    if (type === "close") {
      const { signal_id, result } = payload as {
        signal_id?: unknown; result?: unknown;
      };

      if (!signal_id || !result) {
        return json({ ok: false, error: "Missing required fields" }, 400);
      }
      if (result !== "ganada" && result !== "perdida") {
        return json({ ok: false, error: "Resultado invalido" }, 400);
      }

      const { data: ventana } = await admin
        .from("ventanas_senales")
        .select("id")
        .eq("external_signal_id", String(signal_id))
        .eq("estado", "activa")
        .maybeSingle();

      if (!ventana) {
        return json({ ok: true, not_found: true });
      }

      const { error } = await admin
        .from("ventanas_senales")
        .update({
          estado: "cerrada",
          resultado: String(result),
          senal_cierre: new Date().toISOString(),
        })
        .eq("id", ventana.id);

      if (error) throw error;

      await callBridge("close", ventana.id);

      return json({ ok: true });
    }

    return json({ ok: false, error: "Unknown type" }, 400);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});
