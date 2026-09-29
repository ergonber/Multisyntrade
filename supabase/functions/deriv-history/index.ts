import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decrypt } from "../_shared/crypto.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

async function getOtpWsUrl(token: string, accountId: string): Promise<string> {
  const resp = await fetch(
    `https://api.derivws.com/trading/v1/options/accounts/${accountId}/otp`,
    { method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" } },
  );
  const data = await resp.json();
  if (!data?.data?.url) throw new Error("OTP failed");
  return data.data.url;
}

function wsSend(ws: WebSocket, msg: Record<string, unknown>, t = 20000): Promise<any> {
  return new Promise((res, rej) => {
    const to = setTimeout(() => rej(new Error("ws_timeout")), t);
    ws.onmessage = (ev) => {
      clearTimeout(to);
      const d = JSON.parse(ev.data as string);
      if (d.error) rej(new Error(d.error.message || JSON.stringify(d.error))); else res(d);
    };
    ws.onerror = () => { clearTimeout(to); rej(new Error("ws_error")); };
    ws.send(JSON.stringify(msg));
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response(JSON.stringify({ error: "No autenticado" }), { status: 401, headers: cors });

    const body = await req.json().catch(() => ({}));
    const limit = Math.min(Number(body?.limit) || 100, 500);

    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: conn } = await admin
      .from("deriv_connections")
      .select("ciphertext, loginid")
      .eq("user_id", user.id)
      .maybeSingle();
    if (!conn?.ciphertext) {
      return new Response(JSON.stringify({ transactions: [], connected: false }), { headers: cors });
    }

    const token = await decrypt(conn.ciphertext);
    const acc = await (await fetch("https://api.derivws.com/trading/v1/options/accounts", { headers: { Authorization: `Bearer ${token}` } })).json();
    const list = acc?.data ?? acc?.accounts ?? [];
    const demo = list.find((a: any) => a.account_type === "demo") ?? list[0];
    if (!demo?.account_id) return new Response(JSON.stringify({ transactions: [], connected: true }), { headers: cors });

    const wsUrl = await getOtpWsUrl(token, demo.account_id);
    const ws = new WebSocket(wsUrl);
    await new Promise<void>((res, rej) => {
      ws.onopen = () => res();
      ws.onerror = () => rej(new Error("ws_fail"));
      setTimeout(() => rej(new Error("ws_timeout")), 10000);
    });

    const pt = await wsSend(ws, { profit_table: 1, description: 1, limit, sort: "DESC" });
    try { ws.close(); } catch (_) {}

    const transactions = (pt?.profit_table?.transactions ?? []).map((t: any) => ({
      contract_id: String(t.contract_id),
      symbol: t.underlying_symbol,
      type: t.contract_type,
      buy_price: t.buy_price,
      sell_price: t.sell_price,
      payout: t.payout,
      profit: Number(t.sell_price ?? 0) - Number(t.buy_price ?? 0),
      purchase_time: t.purchase_time,
      sell_time: t.sell_time,
      shortcode: t.shortcode,
    }));

    return new Response(JSON.stringify({ connected: true, account: demo.account_id, transactions }), { headers: cors });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: cors });
  }
});
