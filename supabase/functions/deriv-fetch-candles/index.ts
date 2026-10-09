import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decrypt } from "../_shared/crypto.ts";
const cors = { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" };
async function otp(t: string, a: string): Promise<string> {
  const r = await fetch(`https://api.derivws.com/trading/v1/options/accounts/${a}/otp`, { method: "POST", headers: { Authorization: `Bearer ${t}`, "Content-Type": "application/json" } });
  const d = await r.json(); if (!d?.data?.url) throw new Error("OTP"); return d.data.url;
}
function wsSend(ws: WebSocket, m: any, t = 25000): Promise<any> {
  return new Promise((res, rej) => { const to = setTimeout(() => rej(new Error("timeout")), t);
    ws.onmessage = (e) => { clearTimeout(to); const d = JSON.parse(e.data as string); if (d.error) rej(new Error(d.error.message)); else res(d); };
    ws.onerror = () => { clearTimeout(to); rej(new Error("ws_error")); }; ws.send(JSON.stringify(m)); });
}
const MAP: Record<string, string> = { BOOM150: "BOOM150N", BOOM300: "BOOM300N", CRASH150: "CRASH150N", CRASH300: "CRASH300N" };

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const body = await req.json().catch(() => ({}));
    const granularity = Number(body?.granularity ?? 60);
    const count = Math.min(Number(body?.count ?? 5000), 5000);
    const symbols: string[] = body?.symbols ?? ["BOOM50","BOOM150","BOOM300","BOOM500","BOOM600","BOOM900","BOOM1000","CRASH50","CRASH150","CRASH300","CRASH500","CRASH600","CRASH900","CRASH1000"];
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: conn } = await admin.from("deriv_connections").select("ciphertext").limit(1).maybeSingle();
    const token = await decrypt(conn!.ciphertext);
    const acc = await (await fetch("https://api.derivws.com/trading/v1/options/accounts", { headers: { Authorization: `Bearer ${token}` } })).json();
    const demo = (acc?.data ?? acc?.accounts ?? []).find((a: any) => a.account_type === "demo") ?? (acc?.data ?? acc?.accounts ?? [])[0];
    const ws = new WebSocket(await otp(token, demo.account_id));
    await new Promise<void>((res, rej) => { ws.onopen = () => res(); ws.onerror = () => rej(new Error("fail")); setTimeout(() => rej(new Error("t")), 10000); });

    const out: any = {};
    for (const chSym of symbols) {
      const dSym = MAP[chSym] ?? chSym;
      try {
        const all: any[] = [];
        let end: string | number = "latest";
        while (all.length < count) {
          const r = await wsSend(ws, { ticks_history: dSym, adjust_start_time: 1, count: Math.min(1000, count - all.length), end, style: "candles", granularity });
          const cs: any[] = r.candles ?? [];
          if (!cs.length) break;
          all.push(...cs);
          end = cs[0].epoch - 1;
          if (cs.length < 1000) break;
        }
        const rows = all.map((c: any) => ({ symbol: chSym, granularity, epoch: Number(c.epoch), open: c.open, high: c.high, low: c.low, close: c.close }));
        for (let i = 0; i < rows.length; i += 1000) {
          await admin.from("candles").upsert(rows.slice(i, i + 1000), { onConflict: "symbol,granularity,epoch" });
        }
        out[chSym] = rows.length ? `${rows.length} velas (${rows[rows.length-1].epoch}..${rows[0].epoch})` : "0";
      } catch (e) { out[chSym] = "ERR " + String(e); }
    }
    try { ws.close(); } catch (_) {}
    return new Response(JSON.stringify({ granularity, count, out }), { headers: cors });
  } catch (e) { return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: cors }); }
});
