import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decrypt } from "../_shared/crypto.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

let _rid = 0;
function rid(): string { return `bridge-${Date.now()}-${++_rid}`; }
function log(tag: string, r: string, msg: string) { console.log(`[${r}] [${tag}] ${msg}`); }
function logE(tag: string, r: string, msg: string) { console.error(`[${r}] [${tag}] ${msg}`); }

type SupabaseClient = ReturnType<typeof createClient>;

/* ---------- Concurrency & retry helpers ---------- */

const CONCURRENCY = 25;

/* ---------- Limites de proteccion de capital ---------- */
const MAX_OPEN_POSITIONS = 20;

// Proteccion de posicion (limit_order nativo de Deriv), % del stake, POR ACTIVO.
// SL = percentil 90 de las ganancias de ese activo (calibrado con datos reales). SIN take-profit:
// las ganancias las cierra el proveedor. Default 30% para activos sin datos.
const DEFAULT_SL_PCT = 30;
// Fraccion del camino a TP1 donde se toma ganancia (asegurar). 0.85 = 15% antes del TP1.
const TP_FRACTION = 0.85;
// Stop-loss de emergencia (backstop) como % del stake, para evitar stop-outs de ~90%.
const BACKSTOP_SL_PCT = 20;
const SL_PCT_BY_SYMBOL: Record<string, number> = {
  BOOM50: 2.6, BOOM150: 6.4, BOOM300: 3.5, BOOM500: 8.6, BOOM600: 15.7, BOOM900: 15.0, BOOM1000: 3.4,
  CRASH50: 3.0, CRASH150: 2.7, CRASH300: 10.3, CRASH600: 11.4, CRASH900: 12.8, CRASH1000: 12.9,
};

// Riesgo por tramo de saldo (demo y real):
// <10 no opera | 10-99: 1% | 100-1000: 3% | 1001-10000: 2% | >10000: 1%
function riskPercentForBalance(balance: number): number | null {
  if (balance < 10) return null;
  if (balance < 100) return 1;
  if (balance <= 1000) return 3;
  if (balance <= 10000) return 2;
  return 1;
}

async function mapWithConcurrency<T, R>(items: T[], limit: number, fn: (x: T) => Promise<R>): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let i = 0;
  async function worker() {
    while (true) {
      const idx = i++;
      if (idx >= items.length) return;
      results[idx] = await fn(items[idx]);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

async function withRetry<T>(fn: () => Promise<T>, attempts: number, r: string, tag: string): Promise<T> {
  let lastErr: unknown;
  for (let a = 0; a < attempts; a++) {
    try { return await fn(); }
    catch (e) {
      lastErr = e;
      const msg = String(e);
      const transitorio = /429|rate.?limit|ws_connect|ws_error|ws_timeout|timeout|ETIMEDOUT|socket|otp|fetch failed|network|ECONNRESET|ENOTFOUND|502|503|504/i.test(msg);
      if (!transitorio || a === attempts - 1) throw e;
      const backoff = 500 * Math.pow(2, a);
      log("RETRY", r, `${tag}: intento ${a + 1} falló (${msg.substring(0, 80)}); reintento en ${backoff}ms`);
      await new Promise((res) => setTimeout(res, backoff));
    }
  }
  throw lastErr;
}

/* ---------- Deriv WS helpers ---------- */

function derivWs(wsUrl: string): WebSocket { return new WebSocket(wsUrl); }

function wsSend(ws: WebSocket, msg: Record<string, unknown>, timeoutMs = 15_000): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => { try { ws.close(); } catch (_){} reject(new Error("ws_timeout")); }, timeoutMs);
    ws.onmessage = (ev) => {
      clearTimeout(t);
      try {
        const data = JSON.parse(ev.data as string);
        if (data.error) { reject(new Error(data.error.message || JSON.stringify(data.error))); return; }
        resolve(data);
      } catch (e) { reject(e); }
    };
    ws.onerror = () => { clearTimeout(t); reject(new Error("ws_error")); };
    ws.send(JSON.stringify(msg));
  });
}

async function getOtpWsUrl(token: string, accountId: string, r: string): Promise<string> {
  const resp = await fetch(
    `https://api.derivws.com/trading/v1/options/accounts/${accountId}/otp`,
    { method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" } },
  );
  const data = await resp.json();
  const url: string | undefined = data?.data?.url;
  if (!url) throw new Error(`OTP failed: ${JSON.stringify(data)}`);
  const accountType = url.includes("/demo") ? "DEMO" : url.includes("/real") ? "REAL" : "UNKNOWN";
  log("OTP", r, `account=${accountType} ws=${url.substring(0, 60)}...`);
  return url;
}

/* ---------- ACCOUNT (Solo DEMO) ---------- */

async function resolveAccountId(
  admin: SupabaseClient,
  userId: string,
  token: string,
  storedLoginid: string,
  r: string,
): Promise<string> {
  try {
    const resp = await fetch("https://api.derivws.com/trading/v1/options/accounts", {
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    });
    const d = await resp.json();
    const list: any[] = d?.data ?? d?.accounts ?? [];
    // Solo DEMO: siempre elegir la cuenta demo del usuario.
    const want = "demo";
    const chosen = list.find((a: any) => a.account_type === want);
    if (chosen?.account_id && chosen.account_id !== storedLoginid) {
      log("OTP", r, `account override ${storedLoginid} -> ${chosen.account_id} (${want})`);
      await admin.from("deriv_connections").update({ loginid: chosen.account_id }).eq("user_id", userId);
    }
    if (!chosen) logE("OTP", r, `no ${want} account for user ${userId}, using ${storedLoginid}`);
    return chosen?.account_id ?? storedLoginid;
  } catch (e) {
    logE("OTP", r, `resolveAccountId failed: ${String(e)}`);
    return storedLoginid;
  }
}

/* ---------- EXECUTE for a ventana ---------- */

async function executeForVentana(
  admin: SupabaseClient,
  vent: any,
  r: string,
): Promise<{ executed: number; rejected: number }> {
  const contractType = vent.direccion === "compra" ? "MULTUP" : "MULTDOWN";
  // Mapeo de nombre del canal -> simbolo real de Deriv (150/300 llevan sufijo N).
  const DERIV_SYMBOL_MAP: Record<string, string> = {
    BOOM150: "BOOM150N", BOOM300: "BOOM300N",
    CRASH150: "CRASH150N", CRASH300: "CRASH300N",
  };
  const tradeSymbol: string = DERIV_SYMBOL_MAP[vent.deriv_symbol] ?? vent.deriv_symbol;

  // Find eligible users
  const { data: profiles, error: pErr } = await admin
    .from("profiles")
    .select("id, risk_percentage")
    .eq("capital_inicial_configurado", true);

  if (pErr) { logE("EXEC", r, `profiles query error: ${pErr.message}`); return { executed: 0, rejected: 0 }; }
  if (!profiles?.length) { log("EXEC", r, "no eligible profiles"); return { executed: 0, rejected: 0 }; }

  const results = await mapWithConcurrency(profiles, CONCURRENCY, async (prof) => {
    const userId = prof.id;

    // Idempotency: skip if execution already exists for this user+ventana
    const { data: existing } = await admin
      .from("auto_trade_executions")
      .select("id")
      .eq("ventana_id", vent.id)
      .eq("user_id", userId)
      .maybeSingle();
    if (existing) return "skip" as const;

    // Check subscription
    const { data: sub } = await admin
      .from("subscriptions")
      .select("id")
      .eq("user_id", userId)
      .eq("estado", "activa")
      .gt("fecha_fin", new Date().toISOString())
      .maybeSingle();
    if (!sub) {
      log("EXEC", r, `user ${userId}: no active subscription, skip`);
      return "skip" as const;
    }

    // Check deriv connection
    const { data: conn } = await admin
      .from("deriv_connections")
      .select("ciphertext, loginid")
      .eq("user_id", userId)
      .maybeSingle();
    if (!conn?.ciphertext || !conn.loginid) {
      log("EXEC", r, `user ${userId}: no deriv connection, skip`);
      return "skip" as const;
    }

    // Limite de posiciones abiertas simultaneas (proteccion de capital)
    const { count: openCount } = await admin
      .from("auto_trade_executions")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("estado", "en_curso");
    if ((openCount ?? 0) >= MAX_OPEN_POSITIONS) {
      log("EXEC", r, `user ${userId}: ya tiene ${openCount} posiciones abiertas (max ${MAX_OPEN_POSITIONS}), skip`);
      return "skip" as const;
    }

    let amount = 0;
    let execId: string | undefined;
    let boughtContractId: string | null = null;
    let multiplier = 1;
    let entrySpot: number | null = null;

    let ws: WebSocket | null = null;
    try {
      // Deriv block with retry
      const contractId = await withRetry(async () => {
        const token = await decrypt(conn.ciphertext);
        const accountId = await resolveAccountId(admin, userId, token, conn.loginid, r);
        const wsUrl = await getOtpWsUrl(token, accountId, r);

        try { ws?.close(); } catch (_) {}
        ws = derivWs(wsUrl);
        await new Promise<void>((res, rej) => {
          ws!.onopen = () => res();
          ws!.onerror = () => rej(new Error("ws_connect_fail"));
          setTimeout(() => rej(new Error("ws_connect_timeout")), 10_000);
        });

        // Saldo real -> base del monto (el capital refleja la cuenta Deriv)
        const balResp = await wsSend(ws, { balance: 1 }) as any;
        const balance = Number(balResp?.balance?.balance ?? 0);
        const riskPct = riskPercentForBalance(balance);
        if (riskPct === null) throw new Error(`saldo minimo requerido $10 (saldo $${balance})`);
        amount = Math.round(balance * (riskPct / 100) * 100) / 100;
        if (amount <= 0) throw new Error(`saldo insuficiente (saldo $${balance})`);
        if (amount > balance) throw new Error(`saldo insuficiente (monto $${amount} > saldo $${balance})`);

        // Sincronizar el capital del perfil con el saldo real de Deriv
        await admin.from("profiles").update({ capital_inicial: balance }).eq("id", userId);

        // Fila pendiente (una sola vez, aunque haya reintentos)
        if (!execId) {
          const { data: pend } = await admin.from("auto_trade_executions").insert({
            user_id: userId, ventana_id: vent.id, deriv_symbol: vent.deriv_symbol,
            activo: vent.tipo, monto: amount, contract_id: null, estado: "pendiente", resultado: 0,
          }).select("id").single();
          execId = pend?.id;
        }

        // Validate contract support + compute multiplier from allowed range
        const cfResp = await wsSend(ws, { contracts_for: tradeSymbol }) as any;
        const contracts = cfResp?.contracts_for?.available ?? [];
        const multContract = contracts.find((c: any) => c.contract_type === contractType);
        if (!multContract) throw new Error(`${tradeSymbol} no soporta ${contractType}`);

        const mr: any = multContract.multiplier_range;
        const allowed: number[] = Array.isArray(mr) ? mr : (mr?.values ?? []);
        multiplier = allowed.length ? Math.min(...allowed) : 1;

        // TP/SL: si la senal trae tp_pct/sl_pct (nuestras propias 'auto'), usarlos (convertidos a USD).
        // Si no (Telegram), TP al TP_FRACTION del camino al TP1 y SL backstop.
        let takeProfit: number | null = null;
        let stopLoss = Math.max(0.6, Math.round(amount * BACKSTOP_SL_PCT) / 100);
        if (vent.tp_usd) {
          takeProfit = Math.max(0.1, Number(vent.tp_usd));
        } else if (vent.tp_pct) {
          takeProfit = Math.max(0.1, Math.round(amount * multiplier * Number(vent.tp_pct) / 100 * 100) / 100);
        } else {
          const entryRef = Number(vent.entry_ref ?? 0);
          const tp1Ref = Number(vent.tp1 ?? 0);
          if (entryRef > 0 && tp1Ref > 0) {
            const dP = (Math.abs(tp1Ref - entryRef) / entryRef) * TP_FRACTION;
            takeProfit = Math.max(0.1, Math.round(amount * multiplier * dP * 100) / 100);
          }
        }
        if (vent.sl_usd) stopLoss = Math.max(0.6, Number(vent.sl_usd));
        else if (vent.sl_pct) stopLoss = Math.max(0.6, Math.round(amount * multiplier * Number(vent.sl_pct) / 100 * 100) / 100);
        const limitOrder: Record<string, number> = { stop_loss: stopLoss };
        if (takeProfit !== null) limitOrder.take_profit = takeProfit;

        // Get proposal
        const propResp = await wsSend(ws, {
          proposal: 1, amount, basis: "stake", contract_type: contractType,
          currency: "USD", multiplier, underlying_symbol: tradeSymbol,
          limit_order: limitOrder,
        }) as any;
        const proposalId = propResp?.proposal?.id;
        entrySpot = propResp?.proposal?.spot ? Number(propResp.proposal.spot) : null;
        if (!proposalId) throw new Error(`No proposal: ${JSON.stringify(propResp)}`);

        // Buy
        const buyResp = await wsSend(ws, { buy: proposalId, price: amount }) as any;
        const cid = buyResp?.buy?.contract_id;
        if (!cid) throw new Error(`Buy failed: ${JSON.stringify(buyResp)}`);
        return cid;
      }, 3, r, `user=${userId}`);
      boughtContractId = contractId;

      // Update pending row to en_curso with contract_id
      await admin.from("auto_trade_executions")
        .update({ estado: "en_curso", contract_id: contractId, execution_id: contractId, entry_spot: entrySpot })
        .eq("id", execId);

      // Reconciliar carrera: si la ventana ya se cerro mientras comprabamos, vender ya.
      const { data: vNow } = await admin.from("ventanas_senales").select("estado").eq("id", vent.id).single();
      if (vNow?.estado === "cerrada" && ws && execId) {
        try {
          const sellResp = await wsSend(ws, { sell: contractId, price: 0 }) as any;
          const profit = Number(sellResp?.sell?.sold_for ?? 0) - amount;
          const estado = profit >= 0 ? "ganada" : "perdida";
          await admin.from("auto_trade_executions").update({ estado, resultado: profit }).eq("id", execId);
          await admin.rpc("register_close", { p_user_id: userId, p_profit: profit });
          log("EXEC", r, `user=${userId} contrato ${contractId} vendido por cierre concurrente profit=${profit}`);
          return "executed" as const;
        } catch (e) {
          logE("EXEC", r, `user=${userId} reconcile sell fail: ${String(e)}`);
        }
      }

      log("EXEC", r, `OK user=${userId} amount=${amount} mult=${multiplier} contract=${contractId}`);
      return "executed" as const;
    } catch (e) {
      // If the buy already succeeded, the contract exists on Deriv -> keep it tracked.
      // Only mark rejected when no contract was actually bought.
      if (execId && boughtContractId) {
        const { error: updErr } = await admin.from("auto_trade_executions")
          .update({ estado: "en_curso", contract_id: boughtContractId, execution_id: boughtContractId })
          .eq("id", execId);
        if (updErr) logE("EXEC", r, `user=${userId}: contrato ${boughtContractId} comprado pero update falló (${updErr.message}); queda para reconciliar`);
      } else if (execId) {
        const msg = String(e);
        const unsupported = /no soporta|no contract available/i.test(msg);
        await admin.from("auto_trade_executions")
          .update({ estado: unsupported ? "cancelada" : "rechazada", execution_id: msg.substring(0, 200) })
          .eq("id", execId);
        if (unsupported) {
          await admin.from("ventanas_senales")
            .update({ estado: "cancelada", resultado: "sin_operar", senal_cierre: new Date().toISOString() })
            .eq("id", vent.id);
        }
      } else {
        // Fallo antes de registrar (OTP/WS/conexion): dejar constancia para no perder la senal en silencio.
        await admin.from("auto_trade_executions").insert({
          user_id: userId, ventana_id: vent.id, deriv_symbol: vent.deriv_symbol,
          activo: vent.tipo, monto: 0, contract_id: null, estado: "rechazada",
          resultado: 0, execution_id: String(e).substring(0, 200),
        });
      }
      logE("EXEC", r, `FAIL user=${userId}: ${String(e)}`);
      return "rejected" as const;
    } finally {
      try { ws?.close(); } catch (_){}
    }
  });

  const executed = results.filter((r) => r === "executed").length;
  const rejected = results.filter((r) => r === "rejected").length;
  return { executed, rejected };
}

/* ---------- CLOSE: sell contracts for a ventana ---------- */

async function closeVentana(
  admin: SupabaseClient,
  ventanaId: string,
  r: string,
): Promise<{ closed: number; totalProfit: number }> {
  let { data: execs } = await admin
    .from("auto_trade_executions")
    .select("id, contract_id, user_id, monto")
    .eq("ventana_id", ventanaId)
    .eq("estado", "en_curso")
    .not("contract_id", "is", null);

  // Carrera: el cierre puede llegar mientras la compra esta en curso (aun sin contract_id).
  // Reintentar una vez tras esperar para captar la ejecucion ya abierta.
  if (!execs?.length) {
    await new Promise((res) => setTimeout(res, 6000));
    ({ data: execs } = await admin
      .from("auto_trade_executions")
      .select("id, contract_id, user_id, monto")
      .eq("ventana_id", ventanaId)
      .eq("estado", "en_curso")
      .not("contract_id", "is", null));
  }

  if (!execs?.length) { log("CLOSE", r, `ventana=${ventanaId}: no open executions`); return { closed: 0, totalProfit: 0 }; }

  const results = await mapWithConcurrency(execs, CONCURRENCY, async (exec) => {
    const { data: conn } = await admin
      .from("deriv_connections")
      .select("ciphertext, loginid")
      .eq("user_id", exec.user_id)
      .maybeSingle();

    if (!conn?.ciphertext || !conn.loginid) {
      log("CLOSE", r, `exec=${exec.id}: no deriv connection, skip`);
      return { profit: 0, closed: false } as const;
    }

    let ws: WebSocket | null = null;
    try {
      const profit = await withRetry(async () => {
        const token = await decrypt(conn.ciphertext);
        const wsUrl = await getOtpWsUrl(token, conn.loginid, r);

        ws = derivWs(wsUrl);
        await new Promise<void>((res, rej) => {
          ws!.onopen = () => res();
          ws!.onerror = () => rej(new Error("ws_connect_fail"));
          setTimeout(() => rej(new Error("ws_connect_timeout")), 10_000);
        });

        const sellResp = await wsSend(ws, { sell: exec.contract_id, price: 0 }) as any;
        const soldFor = Number(sellResp?.sell?.sold_for ?? 0);
        const monto = Number(exec.monto ?? 0);
        return soldFor - monto;
      }, 3, r, `exec=${exec.id}`);

      const estado = profit >= 0 ? "ganada" : "perdida";

      await admin.from("auto_trade_executions")
        .update({ estado, resultado: profit })
        .eq("id", exec.id);

      // Atomic increment of ganancia_acumulada
      await admin.rpc("register_close", { p_user_id: exec.user_id, p_profit: profit });

      log("CLOSE", r, `exec=${exec.id} profit=${profit}`);
      return { profit, closed: true } as const;
    } catch (e) {
      logE("CLOSE", r, `FAIL exec=${exec.id}: ${String(e)}`);
      return { profit: 0, closed: false } as const;
    } finally {
      try { ws?.close(); } catch (_){}
    }
  });

  let totalProfit = 0;
  let closed = 0;
  for (const r of results) {
    if (r.closed) { totalProfit += r.profit; closed++; }
  }

  log("CLOSE", r, `ventana=${ventanaId} closed=${closed} total_profit=${totalProfit}`);
  return { closed, totalProfit };
}

/* ---------- main ---------- */

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const r = rid();
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response(JSON.stringify({ error: "No auth" }), {
      status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const isServiceRole = serviceRole && authHeader === `Bearer ${serviceRole}`;

    if (!isServiceRole) {
      const supabase = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_ANON_KEY")!,
        { global: { headers: { Authorization: authHeader } } },
      );
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return new Response(JSON.stringify({ error: "No autorizado" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const { data: isAdmin } = await supabase.rpc("is_admin");
      if (!isAdmin) return new Response(JSON.stringify({ error: "No autorizado" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Parse body for action and ventana_id
    let body: any = {};
    try { body = await req.json(); } catch (_) {}
    const action = body.action as string;
    const ventanaId = body.ventana_id as string;

    log("MAIN", r, `action=${action || "default"} ventana=${ventanaId || "all"}`);

    // --- CLOSE action - FIRE AND FORGET ---
    if (action === "close" && ventanaId) {
      // Fire-and-forget: sell contracts in background, return immediately
      EdgeRuntime.waitUntil(closeVentana(admin, ventanaId, r).catch((e) => {
        logE("CLOSE-BG", r, `ventana=${ventanaId} failed: ${String(e)}`);
      }));

      return new Response(JSON.stringify({ ok: true, message: "Cerrando en segundo plano" }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // --- EXECUTE action (single ventana) - FIRE AND FORGET ---
    if (action === "execute" && ventanaId) {
      const { data: vent } = await admin
        .from("ventanas_senales")
        .select("id, deriv_symbol, tipo, direccion, entry_ref, tp1, tp_pct, sl_pct, tp_usd, sl_usd")
        .eq("id", ventanaId)
        .eq("estado", "activa")
        .single();

      if (!vent) {
        return new Response(JSON.stringify({ ok: true, executed: 0, rejected: 0, message: "Ventana not found or not active" }), {
          status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Fire-and-forget: launch execution in background, return immediately
      EdgeRuntime.waitUntil(executeForVentana(admin, vent, r).catch((e) => {
        logE("EXEC-BG", r, `ventana=${ventanaId} failed: ${String(e)}`);
      }));

      return new Response(JSON.stringify({ ok: true, message: "Ejecutando en segundo plano" }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // --- DEFAULT: legacy processOpen + processLiquidate (for backwards compat) ---
    const { data: ventanas } = await admin
      .from("ventanas_senales")
      .select("id, deriv_symbol, tipo, direccion, entry_ref, tp1, tp_pct, sl_pct, tp_usd, sl_usd")
      .eq("estado", "activa")
      .not("senal_apertura", "is", null);

    let totalExec = 0, totalRej = 0;
    if (ventanas?.length) {
      for (const vent of ventanas) {
        const res = await executeForVentana(admin, vent, r);
        totalExec += res.executed;
        totalRej += res.rejected;
      }
    }

    log("MAIN", r, `DONE executed=${totalExec} rejected=${totalRej}`);
    return new Response(JSON.stringify({ ok: true, executed: totalExec, rejected: totalRej }), {
      status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    logE("MAIN", r, `FATAL: ${String(e)}`);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
