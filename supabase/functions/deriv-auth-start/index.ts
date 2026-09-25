import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const CLIENT_ID = Deno.env.get("DERIV_CLIENT_ID")!;
const REDIRECT_URI = Deno.env.get("DERIV_REDIRECT_URI")!;
const SCOPES = Deno.env.get("DERIV_SCOPES") ?? "trade account_manage";
const ALLOWED_REDIRECTS = (Deno.env.get("DERIV_ALLOWED_REDIRECTS") ?? "").split(",").map(s => s.trim()).filter(Boolean);

const b64url = (b: Uint8Array) =>
  btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const sha256 = async (s: string) =>
  new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)));
const rand = (n: number) => {
  const c = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
  const a = new Uint8Array(n); crypto.getRandomValues(a);
  return Array.from(a).map(v => c[v % c.length]).join("");
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } }
  );
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return new Response(JSON.stringify({ error: "No autenticado" }), {
    status: 401, headers: { ...cors, "Content-Type": "application/json" } });

  // Read redirect_target from request body (optional)
  let redirectTarget = "";
  try {
    const body = await req.json();
    redirectTarget = body?.redirect_target ?? "";
  } catch (_) {}

  // Validate redirect_target against allowlist
  if (redirectTarget && ALLOWED_REDIRECTS.length > 0) {
    const allowed = ALLOWED_REDIRECTS.some(a => redirectTarget.startsWith(a));
    if (!allowed) return new Response(JSON.stringify({ error: "redirect_target not allowed" }), {
      status: 403, headers: { ...cors, "Content-Type": "application/json" } });
  }

  const codeVerifier = rand(64);
  const state = rand(32);
  const codeChallenge = b64url(await sha256(codeVerifier));

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { error } = await admin.from("deriv_oauth_states").insert({
    state, user_id: user.id, code_verifier: codeVerifier,
    redirect_target: redirectTarget || null,
  });
  if (error) return new Response(JSON.stringify({ error: error.message }), {
    status: 500, headers: { ...cors, "Content-Type": "application/json" } });

  const u = new URL("https://auth.deriv.com/oauth2/auth");
  u.searchParams.set("response_type", "code");
  u.searchParams.set("client_id", CLIENT_ID);
  u.searchParams.set("redirect_uri", REDIRECT_URI);
  u.searchParams.set("scope", SCOPES);
  u.searchParams.set("state", state);
  u.searchParams.set("code_challenge", codeChallenge);
  u.searchParams.set("code_challenge_method", "S256");

  return new Response(JSON.stringify({ auth_url: u.toString() }), {
    headers: { ...cors, "Content-Type": "application/json" } });
});
