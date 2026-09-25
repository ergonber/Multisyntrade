import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encrypt } from "../_shared/crypto.ts";

const CLIENT_ID = Deno.env.get("DERIV_CLIENT_ID")!;
const REDIRECT_URI = Deno.env.get("DERIV_REDIRECT_URI")!;
const DEFAULT_DEEP_LINK = Deno.env.get("DERIV_DEEP_LINK") ?? "https://multisyntrade.vercel.app";

function redirectTo(target: string, status: string, msg = ""): Response {
  const sep = target.includes("?") ? "&" : "?";
  const link = `${target}${sep}status=${encodeURIComponent(status)}&message=${encodeURIComponent(msg)}`;
  return new Response(null, { status: 302, headers: { Location: link } });
}

Deno.serve(async (req) => {
  const p = new URL(req.url).searchParams;
  const code = p.get("code"), state = p.get("state"), error = p.get("error");

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  if (error) {
    let target = DEFAULT_DEEP_LINK;
    if (state) {
      const { data: st } = await admin.from("deriv_oauth_states")
        .select("redirect_target").eq("state", state).single();
      if (st?.redirect_target) target = st.redirect_target;
    }
    return redirectTo(target, "error", error);
  }
  if (!code || !state) return redirectTo(DEFAULT_DEEP_LINK, "error", "faltan code/state");

  const { data: st } = await admin.from("deriv_oauth_states")
    .select("user_id, code_verifier, expires_at, redirect_target").eq("state", state).single();
  if (!st) return redirectTo(DEFAULT_DEEP_LINK, "error", "state invalido");
  if (new Date(st.expires_at) < new Date()) return redirectTo(DEFAULT_DEEP_LINK, "error", "state expirado");

  const target = st.redirect_target || DEFAULT_DEEP_LINK;

  const tokRes = await fetch("https://auth.deriv.com/oauth2/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code", client_id: CLIENT_ID, code,
      code_verifier: st.code_verifier, redirect_uri: REDIRECT_URI,
    }),
  });
  if (!tokRes.ok) return redirectTo(target, "error", "token_exchange_failed");
  const tok = await tokRes.json();

  // Solo DEMO: elegir siempre la cuenta demo del usuario.
  let loginid: string | null = null;
  try {
    const r = await fetch("https://api.derivws.com/trading/v1/options/accounts",
      { headers: { Authorization: `Bearer ${tok.access_token}` } });
    if (r.ok) {
      const d = await r.json();
      const list = d?.data ?? d?.accounts ?? [];
      if (Array.isArray(list) && list.length) {
        const chosen = list.find((a: any) => a.account_type === "demo") ?? list[0];
        loginid = chosen.account_id ?? chosen.loginid ?? null;
      }
    }
  } catch (_) {}

  const expiresAt = tok.expires_in ? new Date(Date.now() + tok.expires_in * 1000).toISOString() : null;

  // Guardar conexión (service_role, upsert sobre user_id único).
  const { error: saveErr } = await admin.from("deriv_connections").upsert(
    {
      user_id: st.user_id,
      loginid,
      ciphertext: await encrypt(tok.access_token),
      expires_at: expiresAt,
      scopes: tok.scope ?? null,
    },
    { onConflict: "user_id" },
  );
  if (saveErr) return redirectTo(target, "error", "save_failed");

  await admin.from("profiles").update({ deriv_connection_status: "connected" }).eq("id", st.user_id);

  await admin.from("deriv_oauth_states").delete().eq("state", state);
  return redirectTo(target, "ok");
});
