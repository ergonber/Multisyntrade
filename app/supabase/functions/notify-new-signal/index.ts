// Supabase Edge Function: notify-new-signal
// Envia push notification cuando hay una nueva senal
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')!

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 })
  }

  try {
    const { ventana_id, titulo, activo, tipo, direccion, riesgo } = await req.json()

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Obtener tokens FCM de usuarios con suscripcion activa y notif habilitada
    const { data: profiles, error } = await supabase
      .from('profiles')
      .select('fcm_token')
      .not('fcm_token', 'is', null)
      .eq('notif_nueva_operacion', true)

    if (error || !profiles || profiles.length === 0) {
      return new Response(JSON.stringify({ success: true, sent: 0 }))
    }

    // Enviar notificacion a cada usuario
    const tokens = profiles.map(p => p.fcm_token).filter(Boolean)
    
    if (tokens.length === 0) {
      return new Response(JSON.stringify({ success: true, sent: 0 }))
    }

    const notification = {
      notification: {
        title: 'Nueva Operacion en SynTrade',
        body: `${activo} - ${direccion} - Riesgo: ${riesgo}%`,
      },
      data: {
        type: 'new_signal',
        ventana_id,
        titulo,
        activo,
        tipo,
        direccion,
      },
    }

    // Enviar via FCM HTTP v1 API (en produccion usar el SDK de admin)
    // Por ahora usar legacy API con server key
    let sentCount = 0

    for (const token of tokens) {
      try {
        const response = await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `key=${FCM_SERVER_KEY}`,
          },
          body: JSON.stringify({
            ...notification,
            to: token,
          }),
        })

        if (response.ok) sentCount++
      } catch (e) {
        console.error('FCM send error for token:', e)
      }
    }

    return new Response(JSON.stringify({ success: true, sent: sentCount }))

  } catch (err) {
    console.error('Error:', err)
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500 })
  }
})
