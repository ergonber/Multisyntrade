-- 023_retention_24h.sql
-- Mantener Supabase por debajo de 500MB: purga diaria de datos operativos con >24h.
-- El historial DETALLADO vive en Deriv (profit_table/statement); en Supabase solo queda
-- el resumen permanente del cliente (ganancia_acumulada, totales), que NO se purga.

-- 1) Resumen permanente del cliente
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS total_ganadas INT NOT NULL DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS total_perdidas INT NOT NULL DEFAULT 0;

-- 2) Registrar cierre: acumula ganancia y contadores permanentes
CREATE OR REPLACE FUNCTION public.register_close(p_user_id uuid, p_profit numeric)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.profiles
  SET ganancia_acumulada = COALESCE(ganancia_acumulada, 0) + p_profit,
      total_ganadas = COALESCE(total_ganadas, 0) + CASE WHEN p_profit >= 0 THEN 1 ELSE 0 END,
      total_perdidas = COALESCE(total_perdidas, 0) + CASE WHEN p_profit < 0 THEN 1 ELSE 0 END
  WHERE id = p_user_id;
END; $$;

-- 3) Purga: NUNCA toca posiciones abiertas (en_curso/pendiente) ni el resumen del perfil
CREATE OR REPLACE FUNCTION public.purge_old_operational_data()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM public.auto_trade_executions
  WHERE estado IN ('ganada','perdida','cancelada','rechazada')
    AND creado_en < now() - interval '24 hours';

  DELETE FROM public.ventanas_senales v
  WHERE v.estado IN ('cerrada','cancelada')
    AND COALESCE(v.senal_cierre, v.fecha_inicio) < now() - interval '24 hours'
    AND NOT EXISTS (SELECT 1 FROM public.auto_trade_executions e WHERE e.ventana_id = v.id);
END; $$;

-- 4) Programar la purga diaria (04:00 UTC)
DO $$
BEGIN
  PERFORM cron.unschedule('purge_operational');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule('purge_operational', '0 4 * * *', 'SELECT public.purge_old_operational_data();');
