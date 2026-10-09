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

function pickPayload(body: Record<string, unknown>): Record<string, unknown> {
  if (body && typeof body.type === "string") return body;
  for (const key of ["entry", "close"] as const) {
    const nested = body?.[key];
    if (nested && typeof nested === "object" && typeof (nested as Record<string, unknown>).type === "string") {
      return nested as Record<string, unknown>;
    }
  }
  return body;
}

const RESULT_BY_REASON: Record<string, "ganada" | "perdida"> = {
  profit: "ganada",
  tp: "ganada",
  tp1: "ganada",
  tp2: "ganada",
  gold: "perdida",
  no_operar: "perdida",
};

// "Profittt": % minimo del camino al TP1 para cerrar. Si es menor (salida ~0 del proveedor),
// se ignora y se espera el TP1.
const PROFIT_MIN_PROGRESS = 0.7;

// Indices que el canal opera y que el bridge puede ejecutar en la cuenta Deriv.
// (150 y 300 se mapean a BOOMxxxN / CRASHxxxN dentro del deriv-bridge.)
const SUPPORTED_SYMBOLS = new Set([
  "BOOM50", "BOOM150", "BOOM300", "BOOM500", "BOOM600", "BOOM900", "BOOM1000",
  "CRASH50", "CRASH150", "CRASH300", "CRASH500", "CRASH600", "CRASH900", "CRASH1000",
]);

// Activos pausados (se ignoran sus senales). Se operan solo los ganadores consistentes.
const DISABLED_SYMBOLS = new Set<string>([]); // [] = se operan TODAS las senales de Telegram

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

    const payload = pickPayload(body);
    const type = String(payload?.type ?? "");

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    if (type === "entry") {
      const symbol = payload.symbol;
      const direction = payload.direction;
      const signalId = payload.signal_id;

      if (!symbol || !direction) {
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
      if (!SUPPORTED_SYMBOLS.has(sym)) {
        return json({ ok: true, ignored: true, reason: "Simbolo no operable en la cuenta" });
      }
      if (DISABLED_SYMBOLS.has(sym)) {
        return json({ ok: true, ignored: true, reason: "Activo pausado" });
      }

      const extId = signalId ? String(signalId) : `${sym}-${Date.now()}`;
      const now = new Date().toISOString();

      const { data: inserted, error } = await admin
        .from("ventanas_senales")
        .insert({
          deriv_symbol: sym,
          tipo,
          direccion: String(direction),
          estado: "activa",
          senal_apertura: now,
          fecha_inicio: now,
          external_signal_id: extId,
          entry_ref: Number(payload.entry) || null,
          tp1: Number(payload.tp1) || null,
          tp2: Number(payload.tp2) || null,
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
      const signalId = payload.signal_id;
      const symbol = payload.symbol;
      let result = payload.result;
      const reason = String(payload.reason ?? "").toLowerCase();

      // "Profittt": el proveedor suele salir con un margen minimo (~0). Solo cerramos si la
      // ganancia ya alcanzo PROFIT_MIN_PROGRESS del camino al TP1; si es menor, esperamos TP1.
      if (!payload.result && reason === "profit") {
        const price = Number(payload.price ?? NaN);
        let progress: number | null = null;
        if (symbol && !Number.isNaN(price)) {
          const { data: v } = await admin
            .from("ventanas_senales")
            .select("entry_ref, tp1, direccion")
            .eq("estado", "activa")
            .eq("deriv_symbol", String(symbol).toUpperCase())
            .order("senal_apertura", { ascending: false })
            .limit(1)
            .maybeSingle();
          if (v?.entry_ref && v?.tp1) {
            const dist = Math.abs(Number(v.tp1) - Number(v.entry_ref));
            const move = v.direccion === "venta"
              ? Number(v.entry_ref) - price
              : price - Number(v.entry_ref);
            progress = dist > 0 ? move / dist : 0;
          }
        }
        if (progress === null || progress < PROFIT_MIN_PROGRESS) {
          return json({ ok: true, ignored: true, reason: "profit minimo: se espera TP1", progress });
        }
        result = "ganada";
      }

      if (!result && payload.reason) {
        result = RESULT_BY_REASON[reason] ?? null;
      }
      if (result !== "ganada" && result !== "perdida") {
        return json({ ok: false, error: "Resultado invalido" }, 400);
      }

      let query = admin
        .from("ventanas_senales")
        .select("id")
        .eq("estado", "activa");

      if (signalId) {
        query = query.eq("external_signal_id", String(signalId));
      } else if (symbol) {
        query = query.eq("deriv_symbol", String(symbol).toUpperCase());
      } else {
        return json({ ok: false, error: "Missing signal_id or symbol" }, 400);
      }

      const { data: ventanas } = await query;

      if (!ventanas?.length) {
        return json({ ok: true, not_found: true });
      }

      const now = new Date().toISOString();
      for (const v of ventanas) {
        await admin
          .from("ventanas_senales")
          .update({
            estado: "cerrada",
            resultado: String(result),
            senal_cierre: now,
          })
          .eq("id", v.id);
        await callBridge("close", v.id);
      }

      return json({ ok: true, closed: ventanas.length });
    }

    if (type === "no_operar") {
      const symbol = payload.symbol;
      if (!symbol) {
        return json({ ok: false, error: "Missing symbol" }, 400);
      }
      const sym = String(symbol).toUpperCase();
      const { data: ventanas } = await admin
        .from("ventanas_senales")
        .select("id")
        .eq("estado", "activa")
        .eq("deriv_symbol", sym);

      if (!ventanas?.length) {
        return json({ ok: true, not_found: true });
      }

      const now = new Date().toISOString();
      for (const v of ventanas) {
        await admin
          .from("ventanas_senales")
          .update({ estado: "cerrada", resultado: "sin_operar", senal_cierre: now })
          .eq("id", v.id);
        await callBridge("close", v.id);
      }
      return json({ ok: true, closed: ventanas.length });
    }

    if (type === "habilitar") {
      return json({ ok: true });
    }

    return json({ ok: false, error: "Unknown type" }, 400);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});
