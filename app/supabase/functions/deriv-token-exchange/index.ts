// Supabase Edge Function: deriv-token-exchange
// Intercambia el code de OAuth de Deriv por access/refresh tokens
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const DERIV_CLIENT_ID = Deno.env.get('DERIV_CLIENT_ID')!
const DERIV_CLIENT_SECRET = Deno.env.get('DERIV_CLIENT_SECRET') || ''
const DERIV_REDIRECT_URI = Deno.env.get('DERIV_REDIRECT_URI')!

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 })
  }

  try {
    const { code, code_verifier, state } = await req.json()

    if (!code || !code_verifier || !state) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), { status: 400 })
    }

    // Intercambiar code por tokens
    const tokenResponse = await fetch('https://auth.deriv.com/oauth2/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: DERIV_CLIENT_ID,
        ...(DERIV_CLIENT_SECRET && { client_secret: DERIV_CLIENT_SECRET }),
        code,
        code_verifier,
        grant_type: 'authorization_code',
        redirect_uri: DERIV_REDIRECT_URI,
      }),
    })

    const tokenData = await tokenResponse.json()

    if (!tokenResponse.ok) {
      console.error('Deriv token exchange error:', tokenData)
      return new Response(JSON.stringify({ error: 'Token exchange failed', details: tokenData }), { status: 400 })
    }

    const { access_token, refresh_token, expires_in, scope, loginid } = tokenData

    // Cifrar tokens (en produccion usarAES-256 o similar)
    // Por simplicidad, aqui almacenamos como base64 (en prod usar encryption real)
    const ciphertext = btoa(JSON.stringify({
      access_token,
      refresh_token,
      loginid,
    }))

    // Guardar en Supabase con service role
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    const expires_at = new Date(Date.now() + (expires_in || 3600) * 1000).toISOString()

    const { error } = await supabase.rpc('save_deriv_connection', {
      p_loginid: loginid || null,
      p_ciphertext: ciphertext,
      p_expires_at: expires_at,
      p_scopes: scope || '',
    })

    if (error) {
      console.error('Supabase save error:', error)
      return new Response(JSON.stringify({ error: 'Failed to save connection' }), { status: 500 })
    }

    return new Response(JSON.stringify({
      success: true,
      loginid,
      expires_at,
    }), {
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (err) {
    console.error('Error:', err)
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500 })
  }
})
