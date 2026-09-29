import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decrypt } from "../_shared/crypto.ts";

const cors = { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" };
const RECONCILE_KEY = Deno.env.get("RECONCILE_KEY") ?? "";

async function getOtpWsUrl(token: string, accountId: string): Promise<string> {
  const resp = await fetch(`https://api.derivws.com/trading/v1/options/accounts/${accountId}/otp`,
    { method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" } });
  const data = await resp.json();
  if (!data?.data?.url) throw new Error("OTP failed");
  return data.data.url;
}
function wsSend(ws: WebSocket, msg: Record<string, unknown>, t = 20000): Promise<any> {
  return new Promise((res, rej) => {
    const to = setTimeout(() => rej(new Error("ws_timeout")), t);
    ws.onmessage = (ev) => { clearTimeout(to); const d = JSON.parse(ev.data as string); if (d.error) rej(new Error(d.error.message || JSON.stringify(d.error))); else res(d); };
    ws.onerror = () => { clearTimeout(to); rej(new Error("ws_error")); };
    ws.send(JSON.stringify(msg));
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    if (!RECONCILE_KEY || req.headers.get("x-reconcile-key") !== RECONCILE_KEY) {
      return new Response(JSON.stringify({ error: "No autorizado" }), { status: 401, headers: cors });
    }
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    const { data: execs } = await admin
      .from("auto_trade_executions")
      .select("id, user_id, ventana_id, contract_id, monto, deriv_symbol")
      .eq("estado", "en_curso")
      .not("contract_id", "is", null);

    if (!execs?.length) return new Response(JSON.stringify({ ok: true, en_curso: 0 }), { headers: cors });

    const byUser = new Map<string, any[]>();
    for (const e of execs) {
      if (!byUser.has(e.user_id)) byUser.set(e.user_id, []);
      byUser.get(e.user_id)!.push(e);
    }

    const out: any = { users: byUser.size, sold: 0, reconciled: 0, abiertas: 0, detalle: [] };

    for (const [userId, list] of byUser) {
      const { data: conn } = await admin.from("deriv_connections").select("ciphertext, loginid").eq("user_id", userId).maybeSingle();
      if (!conn?.ciphertext) continue;
      let ws: WebSocket | null = null;
      try {
        const token = await decrypt(conn.ciphertext);
        const acc = await (await fetch("https://api.derivws.com/trading/v1/options/accounts", { headers: { Authorization: `Bearer ${token}` } })).json();
        const demo = (acc?.data ?? acc?.accounts ?? []).find((a: any) => a.account_type === "demo") ?? (acc?.data ?? acc?.accounts ?? [])[0];
        ws = new WebSocket(await getOtpWsUrl(token, demo.account_id));
        await new Promise<void>((res, rej) => { ws!.onopen = () => res(); ws!.onerror = () => rej(new Error("ws_fail")); setTimeout(() => rej(new Error("ws_timeout")), 10000); });

        const port = await wsSend(ws, { portfolio: 1 });
        const openIds = new Set((port?.portfolio?.contracts ?? []).map((c: any) => String(c.contract_id)));

        const pt = await wsSend(ws, { profit_table: 1, description: 1, limit: 200, sort: "DESC" });
        const profitById = new Map<string, number>((pt?.profit_table?.transactions ?? []).map((t: any) => [String(t.contract_id), Number(t.profit)]));

        const vids = [...new Set(list.map((e) => e.ventana_id))];
        const { data: vrows } = await admin.from("ventanas_senales").select("id, estado").in("id", vids as string[]);
        const vestado = new Map((vrows ?? []).map((v: any) => [v.id, v.estado]));

        for (const e of list) {
          const cid = String(e.contract_id);
          if (!openIds.has(cid)) {
            // Ya cerrada en Deriv (stop-out u otro). Reconciliar desde profit_table.
            const p = profitById.has(cid) ? profitById.get(cid)! : 0;
            await admin.from("auto_trade_executions").update({ estado: p >= 0 ? "ganada" : "perdida", resultado: p, execution_id: "recon_deriv" }).eq("id", e.id);
            await admin.rpc("register_close", { p_user_id: userId, p_profit: p });
            out.reconciled++;
            out.detalle.push({ contract: cid, symbol: e.deriv_symbol, accion: "reconciliada", profit: p });
          } else if (vestado.get(e.ventana_id) !== "activa") {
            // Abierta en Deriv pero su ventana ya cerró -> huérfana: vender.
            try {
              const r = await wsSend(ws, { sell: cid, price: 0 });
              const p = Number(r?.sell?.sold_for ?? 0) - Number(e.monto ?? 0);
              await admin.from("auto_trade_executions").update({ estado: p >= 0 ? "ganada" : "perdida", resultado: p, execution_id: "recon_sold" }).eq("id", e.id);
              await admin.rpc("register_close", { p_user_id: userId, p_profit: p });
              out.sold++;
              out.detalle.push({ contract: cid, symbol: e.deriv_symbol, accion: "vendida_huerfana", profit: p });
            } catch (err) {
              out.detalle.push({ contract: cid, symbol: e.deriv_symbol, accion: "sell_fail", error: String(err) });
            }
          } else {
            out.abiertas++;
          }
        }
      } catch (err) {
        out.detalle.push({ user: userId, error: String(err) });
      } finally {
        try { ws?.close(); } catch (_) {}
      }
    }

    // Cerrar ventanas activas cuyas ejecuciones ya terminaron (SL/TP, stop-out, reconciliacion).
    // Solo si ya tienen al menos una ejecucion y ninguna sigue abierta/en curso.
    const { data: activas } = await admin.from("ventanas_senales").select("id").eq("estado", "activa");
    let closedVentanas = 0;
    for (const v of activas ?? []) {
      const { count: openCnt } = await admin
        .from("auto_trade_executions").select("id", { count: "exact", head: true })
        .eq("ventana_id", v.id).in("estado", ["en_curso", "pendiente"]);
      if ((openCnt ?? 0) > 0) continue;
      const { count: total } = await admin
        .from("auto_trade_executions").select("id", { count: "exact", head: true })
        .eq("ventana_id", v.id);
      if ((total ?? 0) === 0) continue;
      await admin.from("ventanas_senales")
        .update({ estado: "cerrada", senal_cierre: new Date().toISOString() })
        .eq("id", v.id);
      closedVentanas++;
    }
    out.ventanas_cerradas = closedVentanas;

    return new Response(JSON.stringify(out), { headers: cors });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: cors });
  }
});
