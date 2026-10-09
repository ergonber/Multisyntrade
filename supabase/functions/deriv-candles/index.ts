import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decrypt } from "../_shared/crypto.ts";
const cors = { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" };
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
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: conn } = await admin.from("deriv_connections").select("ciphertext").limit(1).maybeSingle();
    const token = await decrypt(conn!.ciphertext);
    const acc = await (await fetch("https://api.derivws.com/trading/v1/options/accounts", { headers: { Authorization: `Bearer ${token}` } })).json();
    const demo = (acc?.data ?? acc?.accounts ?? []).find((a: any) => a.account_type === "demo") ?? (acc?.data ?? acc?.accounts ?? [])[0];
    const ws = new WebSocket(await otp(token, demo.account_id));
    await new Promise<void>((res, rej) => { ws.onopen = () => res(); ws.onerror = () => rej(new Error("fail")); setTimeout(() => rej(new Error("t")), 10000); });
    const out: any = {};
    for (const [ep, req2] of [["ticks_history", { ticks_history: "BOOM500", adjust_start_time: 1, count: 10, end: "latest", style: "candles", granularity: 60 }],
                              ["active_symbols", { active_symbols: "brief", product_type: "basic" }]] as any) {
      try { const r = await wsSend(ws, req2); out[ep] = { keys: Object.keys(r), sample: (r.candles ?? r.active_symbols ?? []).slice(0, 3), count: (r.candles ?? r.active_symbols ?? []).length }; }
      catch (e) { out[ep] = { error: String(e) }; }
    }
    try { ws.close(); } catch (_) {}
    return new Response(JSON.stringify(out), { headers: cors });
  } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: cors }); }
});
