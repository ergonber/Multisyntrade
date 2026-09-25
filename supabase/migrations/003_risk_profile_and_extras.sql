-- =============================================
-- Syntrade - Migracion: campos del requisitos.txt
-- (perfil de riesgo, notif config, planes con nombres, etc.)
-- =============================================

-- Campo de perfil de riesgo en profiles (1-10%)
ALTER TABLE public.profiles ADD COLUMN risk_percentage NUMERIC DEFAULT 5 CHECK (risk_percentage IN (1, 2, 3, 4, 5, 10));

-- Configuracion de notificaciones por usuario
ALTER TABLE public.profiles ADD COLUMN notif_nueva_operacion BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN notif_operacion_cerrada BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN notif_resultado BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN notif_anuncios BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN notif_sistema BOOLEAN DEFAULT true;

-- Campo de sesiones activas (control dispositivo)
ALTER TABLE public.profiles ADD COLUMN device_id TEXT;
ALTER TABLE public.profiles ADD COLUMN last_login_at TIMESTAMPTZ;

-- Agregar riesgo por operacion en ventanas_senales
ALTER TABLE public.ventanas_senales ADD COLUMN riesgo_recomendado NUMERIC DEFAULT 5;

-- Planes con nombres (agregar campo display_name)
ALTER TABLE public.subscriptions ADD COLUMN plan_display_name TEXT;

-- Funcion para obtener el nombre visible del plan
CREATE OR REPLACE FUNCTION get_plan_display_name(plan_name TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN CASE plan_name
    WHEN 'gratis' THEN 'Gratuito'
    WHEN 'basico' THEN 'Plan Basico'
    WHEN 'pro' THEN 'Plan Pro'
    WHEN 'vip' THEN 'Plan VIP'
    ELSE plan_name
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Vista de estadisticas de usuario (para dashboard)
CREATE OR REPLACE VIEW user_stats AS
SELECT
  p.id as user_id,
  p.nombre,
  p.capital_inicial,
  p.ganancia_acumulada,
  p.risk_percentage,
  COALESCE(s.plan, 'gratis') as plan,
  s.fecha_fin as subscription_end,
  (SELECT COUNT(*) FROM auto_trade_executions ate WHERE ate.user_id = p.id AND ate.estado = 'ganada') as wins,
  (SELECT COUNT(*) FROM auto_trade_executions ate WHERE ate.user_id = p.id AND ate.estado = 'perdida') as losses,
  (SELECT COUNT(*) FROM auto_trade_executions ate WHERE ate.user_id = p.id) as total_trades,
  (SELECT COALESCE(SUM(ate.resultado), 0) FROM auto_trade_executions ate WHERE ate.user_id = p.id) as total_pnl
FROM public.profiles p
LEFT JOIN public.subscriptions s ON s.user_id = p.id AND s.estado = 'activa';

-- Vista de operaciones recientes del usuario
CREATE OR REPLACE VIEW user_recent_trades AS
SELECT
  ate.*,
  v.titulo as ventana_titulo,
  v.direccion as ventana_direccion
FROM public.auto_trade_executions ate
LEFT JOIN public.ventanas_senales v ON v.id = ate.ventana_id
ORDER BY ate.creado_en DESC;

-- Vista de dashboard admin
CREATE OR REPLACE VIEW admin_dashboard_stats AS
SELECT
  (SELECT COUNT(*) FROM profiles) as total_users,
  (SELECT COUNT(*) FROM profiles WHERE fecha_registro > now() - INTERVAL '7 days') as new_users_week,
  (SELECT COUNT(*) FROM subscriptions WHERE estado = 'activa') as active_subscriptions,
  (SELECT COUNT(*) FROM subscriptions WHERE estado = 'activa' AND fecha_fin < now() + INTERVAL '3 days') as expiring_soon,
  (SELECT COUNT(*) FROM subscriptions WHERE estado = 'vencida') as expired_subscriptions,
  (SELECT COUNT(*) FROM ventanas_senales WHERE estado IN ('programada','activa')) as active_signals,
  (SELECT COUNT(*) FROM ventanas_senales WHERE estado = 'cerrada' AND senal_cierre > now() - INTERVAL '24 hours') as signals_today;
