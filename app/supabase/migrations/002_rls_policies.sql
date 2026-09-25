-- =============================================
-- Syntrade - Row Level Security (RLS) Policies
-- =============================================

-- Habilitar RLS en todas las tablas
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ventanas_senales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ventanas_participacion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auto_trade_executions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auto_trade_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.metas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deriv_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- =============================================
-- PROFILES
-- =============================================

-- Cada usuario puede ver su propio perfil
CREATE POLICY "users_select_own_profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Cualquier usuario autenticado puede ver nombre de otros (para leaderboard)
CREATE POLICY "users_select_public_profile"
  ON public.profiles FOR SELECT
  USING (auth.role() = 'authenticated');

-- Cada usuario actualiza su propio perfil
CREATE POLICY "users_update_own_profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Admin puede ver todos los perfiles
CREATE POLICY "admin_select_all_profiles"
  ON public.profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND rol = 'admin'
    )
  );

-- =============================================
-- SUBSCRIPTIONS
-- =============================================

-- Usuario ve sus suscripciones
CREATE POLICY "users_select_own_subscriptions"
  ON public.subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- Admin ve todas las suscripciones
CREATE POLICY "admin_select_all_subscriptions"
  ON public.subscriptions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND rol = 'admin'
    )
  );

-- Solo via funciones RPC (security definer) se inserta/actualiza

-- =============================================
-- ACTIVOS
-- =============================================

-- Cualquier autenticado puede ver activos habilitados
CREATE POLICY "users_select_activos"
  ON public.activos FOR SELECT
  USING (habilitado = true AND auth.role() = 'authenticated');

-- Admin ve todos
CREATE POLICY "admin_select_all_activos"
  ON public.activos FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND rol = 'admin'
    )
  );

-- =============================================
-- VENTANAS_SENALES
-- =============================================

-- Usuarios con plan activo pueden ver ventanas programadas/activas
CREATE POLICY "users_select_ventanas"
  ON public.ventanas_senales FOR SELECT
  USING (
    auth.role() = 'authenticated'
    AND estado IN ('programada', 'activa', 'cerrada')
    AND EXISTS (
      SELECT 1 FROM public.subscriptions
      WHERE user_id = auth.uid()
        AND estado = 'activa'
        AND fecha_fin > now()
    )
  );

-- Admin ve todo
CREATE POLICY "admin_select_all_ventanas"
  ON public.ventanas_senales FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND rol = 'admin'
    )
  );

-- =============================================
-- VENTANAS_PARTICIPACION
-- =============================================

-- Usuario ve sus participaciones
CREATE POLICY "users_select_own_participacion"
  ON public.ventanas_participacion FOR SELECT
  USING (auth.uid() = user_id);

-- Admin ve todas
CREATE POLICY "admin_select_all_participacion"
  ON public.ventanas_participacion FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND rol = 'admin'
    )
  );

-- =============================================
-- AUTO_TRADE_EXECUTIONS
-- =============================================

-- Usuario ve sus ejecuciones
CREATE POLICY "users_select_own_executions"
  ON public.auto_trade_executions FOR SELECT
  USING (auth.uid() = user_id);

-- Admin ve todas
CREATE POLICY "admin_select_all_executions"
  ON public.auto_trade_executions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND rol = 'admin'
    )
  );

-- =============================================
-- AUTO_TRADE_CONFIG
-- =============================================

-- Usuario gestiona su config
CREATE POLICY "users_select_own_config"
  ON public.auto_trade_config FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_config"
  ON public.auto_trade_config FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own_config"
  ON public.auto_trade_config FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "users_delete_own_config"
  ON public.auto_trade_config FOR DELETE
  USING (auth.uid() = user_id);

-- =============================================
-- METAS
-- =============================================

-- Usuario gestiona sus metas
CREATE POLICY "users_select_own_metas"
  ON public.metas FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_metas"
  ON public.metas FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own_metas"
  ON public.metas FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "users_delete_own_metas"
  ON public.metas FOR DELETE
  USING (auth.uid() = user_id);

-- =============================================
-- APP_CONFIG
-- =============================================

-- Cualquier autenticado puede leer config (mantenimiento)
CREATE POLICY "users_select_app_config"
  ON public.app_config FOR SELECT
  USING (auth.role() = 'authenticated');

-- =============================================
-- ANNOUNCEMENTS
-- =============================================

-- Cualquier autenticado puede ver anuncios activos
CREATE POLICY "users_select_announcements"
  ON public.announcements FOR SELECT
  USING (activo = true AND auth.role() = 'authenticated');

-- Admin ve todos
CREATE POLICY "admin_select_all_announcements"
  ON public.announcements FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND rol = 'admin'
    )
  );

-- =============================================
-- DERIV_CONNECTIONS
-- =============================================

-- Solo el usuario ve su conexion (nunca el token plano)
CREATE POLICY "users_select_own_deriv"
  ON public.deriv_connections FOR SELECT
  USING (auth.uid() = user_id);

-- Admin no debe ver tokens de otros - solo via Edge Functions

-- =============================================
-- PAYMENTS
-- =============================================

-- Usuario ve sus pagos
CREATE POLICY "users_select_own_payments"
  ON public.payments FOR SELECT
  USING (auth.uid() = user_id);

-- Admin ve todos
CREATE POLICY "admin_select_all_payments"
  ON public.payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND rol = 'admin'
    )
  );
