import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { decrypt } from "../_shared/crypto.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Not authenticated' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data: conn } = await supabaseAdmin
      .from('deriv_connections')
      .select('ciphertext, loginid')
      .eq('user_id', user.id)
      .single()

    if (!conn?.ciphertext) {
      return new Response(JSON.stringify({ error: 'No Deriv connection found' }), {
        status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const token = await decrypt(conn.ciphertext)

    const accountsResp = await fetch('https://api.derivws.com/trading/v1/options/accounts', {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    })

    const accountsData = await accountsResp.json()

    const accounts = accountsData?.data || accountsData?.options?.accounts || []
    if (accounts.length === 0) {
      return new Response(JSON.stringify({
        error: 'No accounts found',
      }), {
        status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Solo DEMO: elegir siempre la cuenta demo del usuario.
    const chosen = accounts.find((a: any) => a.account_type === 'demo') || accounts[0]
    const accountId = chosen.account_id || chosen.loginid

    const otpResp = await fetch(`https://api.derivws.com/trading/v1/options/accounts/${accountId}/otp`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    })

    const otpData = await otpResp.json()

    const wsUrl = otpData?.data?.url
    if (!wsUrl) {
      return new Response(JSON.stringify({
        error: 'Could not get OTP WebSocket URL',
        accountId,
      }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    await supabaseAdmin
      .from('deriv_connections')
      .update({ loginid: accountId })
      .eq('user_id', user.id)

    return new Response(JSON.stringify({
      success: true,
      ws_url: wsUrl,
      account_id: accountId,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (err) {
    console.error('Error:', err)
    return new Response(JSON.stringify({ error: 'Internal server error', details: String(err) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
