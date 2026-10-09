import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decrypt } from "../_shared/crypto.ts";

const cors = { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" };
const KEY = Deno.env.get("RECONCILE_KEY") ?? "";
// TP/SL fijos (en % del precio) segun optimizacion estadistica.
const TP_USD = 3;   // (default) asegurar ganancia (USD)
const SL_USD = 4;   // tope de perdida (USD)
// TP optimo por activo (USD), segun sweep estadistico. Solo se operan estos activos.
const TP_BY_SYMBOL: Record<string, number> = {
  BOOM300: 8, BOOM500: 20, BOOM600: 12, BOOM900: 15, BOOM1000: 20,
  CRASH150: 8, CRASH300: 3, CRASH500: 15, CRASH600: 20, CRASH900: 10, CRASH1000: 20,
};
const SPIKE_PCT = 0.05; // % de vela para considerar "spike" (reset del segmento)
const CALM_TICKS = 3;   // ticks/velas calmos despues del spike antes de entrar
const EMA_PERIOD = 100;  // EMA (close) para la tendencia de fondo
const EMA_OFFSET = 100;  // offset (barras) de la MA: compara el precio con la EMA de hace N velas

function emaLast(vals: number[], n: number): number {
  const k = 2 / (n + 1);
  let p = vals[0];
  for (let i = 1; i < vals.length; i++) p = vals[i] * k + p * (1 - k);
  return p;
}
const ASSETS = Object.keys(TP_BY_SYMBOL); // solo activos con entrada y positivo
const MAP: Record<string, string> = { BOOM150: "BOOM150N", BOOM300: "BOOM300N", CRASH150: "CRASH150N", CRASH300: "CRASH300N" };
const TREND_LOOKBACK = 5;

async function otp(t: string, a: string): Promise<string> {
  const r = await fetch(`https://api.derivws.com/trading/v1/options/accounts/${a}/otp`, { method: "POST", headers: { Authorization: `Bearer ${t}`, "Content-Type": "application/json" } });
  const d = await r.json(); if (!d?.data?.url) throw new Error("OTP"); return d.data.url;
}
function wsSend(ws: WebSocket, m: any, t = 20000): Promise<any> {
  return new Promise((res, rej) => { const to = setTimeout(() => rej(new Error("timeout")), t);
    ws.onmessage = (e) => { clearTimeout(to); const d = JSON.parse(e.data as string); if (d.error) rej(new Error(d.error.message)); else res(d); };
    ws.onerror = () => { clearTimeout(to); rej(new Error("ws_error")); }; ws.send(JSON.stringify(m)); });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    if (!KEY || req.headers.get("x-reconcile-key") !== KEY) return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });

    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: conn } = await admin.from("deriv_connections").select("ciphertext, loginid").limit(1).maybeSingle();
    const token = await decrypt(conn!.ciphertext);
    const acc = await (await fetch("https://api.derivws.com/trading/v1/options/accounts", { headers: { Authorization: `Bearer ${token}` } })).json();
    const demo = (acc?.data ?? acc?.accounts ?? []).find((a: any) => a.account_type === "demo") ?? (acc?.data ?? acc?.accounts ?? [])[0];
    const ws = new WebSocket(await otp(token, demo.account_id));
    await new Promise<void>((res, rej) => { ws.onopen = () => res(); ws.onerror = () => rej(new Error("fail")); setTimeout(() => rej(new Error("t")), 10000); });

    const created: any[] = [];
    for (const sym of ASSETS) {
      const dSym = MAP[sym] ?? sym;
      try {
        // sin posicion activa propia en ese activo
        const { data: act } = await admin.from("ventanas_senales").select("id").eq("deriv_symbol", sym).eq("origen", "auto").eq("estado", "activa").limit(1);
        if (act && act.length) continue;

        const r = await wsSend(ws, { ticks_history: dSym, adjust_start_time: 1, count: EMA_PERIOD + EMA_OFFSET + 20, end: "latest", style: "candles", granularity: 60 });
        const cs: any[] = r.candles ?? [];
        if (cs.length < EMA_PERIOD + EMA_OFFSET + 1) continue;
        const closes = cs.map((c: any) => Number(c.close));
        const last = closes[closes.length - 1];
        const up = sym.startsWith("BOOM") ? false : true; // Boom deriva abajo, Crash arriba

        // Filtro EMA(period) con OFFSET: compara el precio actual con la EMA de hace N velas.
        const emaBase = closes.slice(0, closes.length - EMA_OFFSET);
        const ema = emaLast(emaBase, EMA_PERIOD);
        const maOk = up ? (last > ema) : (last < ema);
        if (!maOk) continue;

        // SIEMPRE (tras cualquier cierre, ganada o perdida): no entrar hasta que el ultimo
        // spike haya quedado CALM_TICKS velas atras (evita entrar en pleno spike o en racimo).
        {
          const isSpike = (c: any) => Math.abs(Number(c.close) - Number(c.open)) / Number(c.open) * 100 >= SPIKE_PCT;
          const w = cs.slice(-12);
          let lastSpike = -1;
          for (let k = 0; k < w.length; k++) if (isSpike(w[k])) lastSpike = k;
          const sinceSpike = lastSpike < 0 ? -1 : (w.length - 1 - lastSpike);
          if (!(lastSpike >= 0 && sinceSpike >= CALM_TICKS)) continue; // hubo spike + N ticks calmos
        }

        const dir = up ? "compra" : "venta";
        const tipo = sym.startsWith("BOOM") ? "boom" : "crash";
        const now = new Date().toISOString();
        const { data: ins } = await admin.from("ventanas_senales").insert({
          deriv_symbol: sym, tipo, direccion: dir, estado: "activa", senal_apertura: now, fecha_inicio: now,
          origen: "auto", entry_ref: last, tp_usd: (TP_BY_SYMBOL[sym] ?? TP_USD), sl_usd: SL_USD,
          external_signal_id: `auto-${sym}-${Date.now()}`,
        }).select("id").single();
        if (ins?.id) {
          created.push({ sym, dir, tp: (TP_BY_SYMBOL[sym] ?? TP_USD), sl: SL_USD });
          await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/deriv-bridge`, {
            method: "POST",
            headers: { "Content-Type": "application/json", Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}` },
            body: JSON.stringify({ action: "execute", ventana_id: ins.id }),
          });
        }
      } catch (e) { /* seguir con el resto */ }
    }
    try { ws.close(); } catch (_) {}
    return new Response(JSON.stringify({ created: created.length, signals: created }), { headers: cors });
  } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: cors }); }
});
