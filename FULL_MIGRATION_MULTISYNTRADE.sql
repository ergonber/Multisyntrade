-- ============================================================
-- Multisyntrade - SQL completo para Supabase (SQL Editor)
-- Esquema final: migraciones 001..019 (sin cron, sin multiplicador)
-- Incluye 004b (deriv_oauth_states) y 019 (drop multiplicador + vista).
-- Pegar TODO en Supabase > SQL Editor > Run.
-- ============================================================

-- ================= 001_initial_schema.sql =================
-- =============================================
-- Syntrade - Schema inicial
-- =============================================

-- Perfil publico de cada usuario (1:1 con auth.users)
CREATE TABLE public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nombre        TEXT,
  telefono      TEXT,
  foto_url      TEXT,
  rol           TEXT NOT NULL DEFAULT 'user' CHECK (rol IN ('user','admin')),
  deriv_connection_status TEXT DEFAULT 'disconnected' CHECK (deriv_connection_status IN ('disconnected','connected','error')),
  capital_inicial        NUMERIC DEFAULT 0,
  capital_inicial_configurado BOOLEAN DEFAULT false,
  ganancia_acumulada     NUMERIC DEFAULT 0,
  fcm_token     TEXT,
  fecha_registro TIMESTAMPTZ DEFAULT now()
);

-- Suscripciones / planes
CREATE TABLE public.subscriptions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  plan         TEXT NOT NULL DEFAULT 'gratis' CHECK (plan IN ('gratis','basico','pro','vip')),
  precio       NUMERIC DEFAULT 0,
  fecha_inicio TIMESTAMPTZ NOT NULL DEFAULT now(),
  fecha_fin    TIMESTAMPTZ,
  estado       TEXT NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa','vencida','cancelada')),
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- Activos disponibles para senales
CREATE TABLE public.activos (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre          TEXT UNIQUE NOT NULL,
  deriv_symbol    TEXT NOT NULL,
  multiplicadores NUMERIC[] DEFAULT '{}',
  habilitado      BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- Ventanas de senales (sesiones)
CREATE TABLE public.ventanas_senales (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  titulo           TEXT,
  activo_id        UUID REFERENCES public.activos(id),
  deriv_symbol     TEXT NOT NULL,
  tipo             TEXT NOT NULL CHECK (tipo IN ('boom','crash')),
  direccion        TEXT CHECK (direccion IN ('compra','venta')),
  duracion_minutos INT,
  fecha_inicio     TIMESTAMPTZ NOT NULL,
  fecha_fin        TIMESTAMPTZ,
  estado           TEXT NOT NULL DEFAULT 'programada' CHECK (estado IN ('programada','activa','cerrada','cancelada')),
  creado_por_admin_id UUID REFERENCES public.profiles(id),
  senal_apertura   TIMESTAMPTZ,
  senal_cierre     TIMESTAMPTZ,
  resultado        TEXT CHECK (resultado IN ('ganada','perdida','sin_operar')),
  created_at       TIMESTAMPTZ DEFAULT now()
);

-- Participacion: quien esta dentro de cada ventana
CREATE TABLE public.ventanas_participacion (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ventana_id UUID NOT NULL REFERENCES public.ventanas_senales(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  monto      NUMERIC DEFAULT 0,
  multiplicador NUMERIC DEFAULT 1,
  estado     TEXT DEFAULT 'activa' CHECK (estado IN ('activa','cancelada','cerrada')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (ventana_id, user_id)
);

-- Ejecuciones reales en Deriv (auto-copy / manual)
CREATE TABLE public.auto_trade_executions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id),
  ventana_id      UUID REFERENCES public.ventanas_senales(id),
  activo          TEXT,
  deriv_symbol    TEXT,
  monto           NUMERIC,
  multiplicador   NUMERIC,
  contract_id     TEXT,
  estado          TEXT DEFAULT 'en_curso' CHECK (estado IN ('en_curso','ganada','perdida','rechazada','cancelada')),
  resultado       NUMERIC,
  execution_id    TEXT,
  creado_en       TIMESTAMPTZ DEFAULT now()
);

-- Configuracion de auto-copy por usuario
CREATE TABLE public.auto_trade_config (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  activo_id       UUID REFERENCES public.activos(id),
  enabled         BOOLEAN DEFAULT false,
  monto_default   NUMERIC DEFAULT 0,
  multiplicador_default NUMERIC DEFAULT 1,
  created_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, activo_id)
);

-- Metas del usuario
CREATE TABLE public.metas (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  objetivo     TEXT,
  monto_meta   NUMERIC DEFAULT 0,
  progreso     NUMERIC DEFAULT 0,
  estado       TEXT DEFAULT 'activa' CHECK (estado IN ('activa','completada','cancelada')),
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- Config global (mantenimiento, anuncios)
CREATE TABLE public.app_config (
  id                  BOOLEAN PRIMARY KEY DEFAULT true,
  mantenimiento       BOOLEAN DEFAULT false,
  mensaje_mantenimiento TEXT,
  updated_at          TIMESTAMPTZ DEFAULT now()
);

-- Anuncios
CREATE TABLE public.announcements (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title      TEXT,
  body       TEXT,
  image_url  TEXT,
  activo     BOOLEAN DEFAULT true,
  creado_en  TIMESTAMPTZ DEFAULT now()
);

-- Tokens de Deriv (cifrados)
CREATE TABLE public.deriv_connections (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  loginid         TEXT,
  ciphertext      TEXT NOT NULL,
  expires_at      TIMESTAMPTZ,
  scopes          TEXT,
  connected_at    TIMESTAMPTZ DEFAULT now()
);

-- Historial de pagos (fase 2)
CREATE TABLE public.payments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id),
  plan            TEXT NOT NULL,
  monto           NUMERIC,
  moneda          TEXT DEFAULT 'USD',
  provider        TEXT,
  provider_ref    TEXT,
  estado          TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente','aprobado','rechazado')),
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_subscriptions_user ON public.subscriptions(user_id);
CREATE INDEX idx_ventanas_estado ON public.ventanas_senales(estado);
CREATE INDEX idx_ventanas_fecha ON public.ventanas_senales(fecha_inicio);
CREATE INDEX idx_participacion_ventana ON public.ventanas_participacion(ventana_id);
CREATE INDEX idx_participacion_user ON public.ventanas_participacion(user_id);
CREATE INDEX idx_trade_executions_user ON public.auto_trade_executions(user_id);
CREATE INDEX idx_trade_executions_ventana ON public.auto_trade_executions(ventana_id);
CREATE INDEX idx_metas_user ON public.metas(user_id);
CREATE INDEX idx_deriv_connections_user ON public.deriv_connections(user_id);

-- Insertar config inicial
INSERT INTO public.app_config (id, mantenimiento, mensaje_mantenimiento)
VALUES (true, false, 'Sistema en mantenimiento. Volvemos pronto.');

-- Funcion para auto-crear perfil al registrarse
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, nombre)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'nombre', NEW.email));
  
  -- Crear suscripcion gratis por defecto
  INSERT INTO public.subscriptions (user_id, plan, fecha_fin)
  VALUES (NEW.id, 'gratis', NOW() + INTERVAL '365 days');
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para auto-crear perfil
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ================= 002_rls_policies.sql =================
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


-- ================= 003_risk_profile_and_extras.sql =================
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


-- ================= 004_rpc_functions.sql =================
-- =============================================
-- Syntrade - Funciones RPC
-- =============================================

-- =============================================
-- FUNCIONES DE ADMIN
-- =============================================

-- Verificar si el usuario actual es admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND rol = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin: crear ventana de senales
CREATE OR REPLACE FUNCTION public.admin_create_ventana(
  p_titulo TEXT,
  p_activo_id UUID,
  p_deriv_symbol TEXT,
  p_tipo TEXT,
  p_direccion TEXT,
  p_duracion_minutos INT,
  p_fecha_inicio TIMESTAMPTZ,
  p_riesgo_recomendado NUMERIC DEFAULT 5
)
RETURNS UUID AS $$
DECLARE
  v_ventana_id UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  INSERT INTO public.ventanas_senales (
    titulo, activo_id, deriv_symbol, tipo, direccion,
    duracion_minutos, fecha_inicio, fecha_fin,
    estado, creado_por_admin_id, riesgo_recomendado
  ) VALUES (
    p_titulo, p_activo_id, p_deriv_symbol, p_tipo, p_direccion,
    p_duracion_minutos, p_fecha_inicio,
    p_fecha_inicio + (p_duracion_minutos || ' minutes')::INTERVAL,
    'programada', auth.uid(), p_riesgo_recomendado
  ) RETURNING id INTO v_ventana_id;

  RETURN v_ventana_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin: publicar senal (marcar como activa)
CREATE OR REPLACE FUNCTION public.admin_publish_signal(
  p_ventana_id UUID
)
RETURNS VOID AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  UPDATE public.ventanas_senales
  SET estado = 'activa',
      senal_apertura = now()
  WHERE id = p_ventana_id AND estado = 'programada';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin: cerrar ventana con resultado
CREATE OR REPLACE FUNCTION public.admin_close_ventana(
  p_ventana_id UUID,
  p_resultado TEXT
)
RETURNS VOID AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  UPDATE public.ventanas_senales
  SET estado = 'cerrada',
      senal_cierre = now(),
      resultado = p_resultado
  WHERE id = p_ventana_id AND estado = 'activa';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin: cancelar ventana
CREATE OR REPLACE FUNCTION public.admin_cancel_ventana(
  p_ventana_id UUID
)
RETURNS VOID AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  UPDATE public.ventanas_senales
  SET estado = 'cancelada'
  WHERE id = p_ventana_id AND estado IN ('programada', 'activa');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin: gestionar suscripcion de usuario
CREATE OR REPLACE FUNCTION public.admin_set_user_subscription(
  p_user_id UUID,
  p_plan TEXT,
  p_fecha_fin TIMESTAMPTZ DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_fecha_fin TIMESTAMPTZ;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  -- Default: 30 dias si no se especifica
  v_fecha_fin := COALESCE(p_fecha_fin, now() + INTERVAL '30 days');

  -- Marcar suscripciones anteriores como vencidas
  UPDATE public.subscriptions
  SET estado = 'vencida'
  WHERE user_id = p_user_id AND estado = 'activa';

  -- Crear nueva suscripcion
  INSERT INTO public.subscriptions (user_id, plan, fecha_inicio, fecha_fin, estado, plan_display_name)
  VALUES (p_user_id, p_plan, now(), v_fecha_fin, 'activa', get_plan_display_name(p_plan));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin: actualizar rol de usuario
CREATE OR REPLACE FUNCTION public.admin_set_user_role(
  p_user_id UUID,
  p_rol TEXT
)
RETURNS VOID AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  UPDATE public.profiles
  SET rol = p_rol
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin: activar/desactivar usuario
CREATE OR REPLACE FUNCTION public.admin_toggle_user_status(
  p_user_id UUID
)
RETURNS VOID AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  UPDATE public.subscriptions
  SET estado = CASE WHEN estado = 'activa' THEN 'cancelada' ELSE 'activa' END
  WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FUNCIONES DE USUARIO
-- =============================================

-- Unirse a una ventana (participar)
CREATE OR REPLACE FUNCTION public.join_ventana(
  p_ventana_id UUID,
  p_monto NUMERIC DEFAULT 0
)
RETURNS UUID AS $$
DECLARE
  v_participation_id UUID;
  v_subscription RECORD;
  v_ventana RECORD;
BEGIN
  -- Verificar suscripcion activa
  SELECT * INTO v_subscription
  FROM public.subscriptions
  WHERE user_id = auth.uid() AND estado = 'activa' AND fecha_fin > now()
  LIMIT 1;

  IF v_subscription IS NULL THEN
    RAISE EXCEPTION 'Se requiere suscripcion activa para participar';
  END IF;

  -- Verificar ventana abierta
  SELECT * INTO v_ventana
  FROM public.ventanas_senales
  WHERE id = p_ventana_id AND estado IN ('programada', 'activa');

  IF v_ventana IS NULL THEN
    RAISE EXCEPTION 'La ventana no esta disponible';
  END IF;

  -- Verificar que no este ya participando
  IF EXISTS (
    SELECT 1 FROM public.ventanas_participacion
    WHERE ventana_id = p_ventana_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Ya estas participando en esta ventana';
  END IF;

  -- Verificar capital configurado
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND capital_inicial_configurado = true
  ) THEN
    RAISE EXCEPTION 'Debes configurar tu capital inicial primero';
  END IF;

  INSERT INTO public.ventanas_participacion (ventana_id, user_id, monto)
  VALUES (p_ventana_id, auth.uid(), p_monto)
  RETURNING id INTO v_participation_id;

  RETURN v_participation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cancelar participacion (si no ha empezado)
CREATE OR REPLACE FUNCTION public.cancelar_ventana_participacion(
  p_ventana_id UUID
)
RETURNS VOID AS $$
BEGIN
  UPDATE public.ventanas_participacion
  SET estado = 'cancelada'
  WHERE ventana_id = p_ventana_id
    AND user_id = auth.uid()
    AND estado = 'activa';

  -- Solo si la ventana no ha empezado
  IF NOT EXISTS (
    SELECT 1 FROM public.ventanas_senales
    WHERE id = p_ventana_id AND senal_apertura IS NOT NULL
  ) THEN
    DELETE FROM public.ventanas_participacion
    WHERE ventana_id = p_ventana_id
      AND user_id = auth.uid()
      AND estado = 'cancelada';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Configurar capital inicial
CREATE OR REPLACE FUNCTION public.set_capital_inicial(
  p_capital NUMERIC
)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET capital_inicial = p_capital,
      capital_inicial_configurado = true
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Configurar perfil de riesgo
CREATE OR REPLACE FUNCTION public.set_risk_profile(
  p_risk_percentage NUMERIC
)
RETURNS VOID AS $$
BEGIN
  IF p_risk_percentage NOT IN (1, 2, 3, 4, 5, 10) THEN
    RAISE EXCEPTION 'Porcentaje de riesgo no valido';
  END IF;

  UPDATE public.profiles
  SET risk_percentage = p_risk_percentage
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Obtener senales activas del usuario
CREATE OR REPLACE FUNCTION public.get_mis_senales_activas()
RETURNS TABLE (
  ventana_id UUID,
  titulo TEXT,
  activo_nombre TEXT,
  deriv_symbol TEXT,
  tipo TEXT,
  direccion TEXT,
  duracion_minutos INT,
  fecha_inicio TIMESTAMPTZ,
  fecha_fin TIMESTAMPTZ,
  estado TEXT,
  resultado TEXT,
  riesgo_recomendado NUMERIC,
  monto NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    v.id, v.titulo, a.nombre, v.deriv_symbol, v.tipo,
    v.direccion, v.duracion_minutos, v.fecha_inicio, v.fecha_fin,
    v.estado, v.resultado, v.riesgo_recomendado, vp.monto
  FROM public.ventanas_senales v
  JOIN public.ventanas_participacion vp ON vp.ventana_id = v.id
  LEFT JOIN public.activos a ON a.id = v.activo_id
  WHERE vp.user_id = auth.uid()
    AND v.estado IN ('activa', 'programada')
  ORDER BY v.fecha_inicio DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Obtener historial de senales del usuario
CREATE OR REPLACE FUNCTION public.get_mis_senales_cerradas()
RETURNS TABLE (
  ventana_id UUID,
  titulo TEXT,
  activo_nombre TEXT,
  deriv_symbol TEXT,
  tipo TEXT,
  direccion TEXT,
  fecha_cierre TIMESTAMPTZ,
  resultado TEXT,
  riesgo_recomendado NUMERIC,
  monto NUMERIC,
  ganancia NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    v.id, v.titulo, a.nombre, v.deriv_symbol, v.tipo,
    v.direccion, v.senal_cierre, v.resultado, v.riesgo_recomendado,
    vp.monto, ate.resultado
  FROM public.ventanas_senales v
  JOIN public.ventanas_participacion vp ON vp.ventana_id = v.id
  LEFT JOIN public.activos a ON a.id = v.activo_id
  LEFT JOIN public.auto_trade_executions ate ON ate.ventana_id = v.id AND ate.user_id = auth.uid()
  WHERE vp.user_id = auth.uid()
    AND v.estado = 'cerrada'
  ORDER BY v.senal_cierre DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Estadisticas de rendimiento del usuario
CREATE OR REPLACE FUNCTION public.get_user_performance(
  p_period TEXT DEFAULT 'all' -- 'day', 'week', 'month', 'all'
)
RETURNS TABLE (
  total_trades BIGINT,
  wins BIGINT,
  losses BIGINT,
  win_rate NUMERIC,
  total_pnl NUMERIC,
  avg_pnl NUMERIC
) AS $$
DECLARE
  v_since TIMESTAMPTZ;
BEGIN
  v_since := CASE p_period
    WHEN 'day' THEN now() - INTERVAL '1 day'
    WHEN 'week' THEN now() - INTERVAL '7 days'
    WHEN 'month' THEN now() - INTERVAL '30 days'
    ELSE '2000-01-01'::TIMESTAMPTZ
  END;

  RETURN QUERY
  SELECT
    COUNT(*)::BIGINT,
    COUNT(*) FILTER (WHERE estado = 'ganada')::BIGINT,
    COUNT(*) FILTER (WHERE estado = 'perdida')::BIGINT,
    CASE WHEN COUNT(*) > 0
      THEN ROUND(COUNT(*) FILTER (WHERE estado = 'ganada')::NUMERIC / COUNT(*) * 100, 1)
      ELSE 0
    END,
    COALESCE(SUM(resultado), 0),
    CASE WHEN COUNT(*) > 0
      THEN ROUND(COALESCE(SUM(resultado), 0) / COUNT(*), 2)
      ELSE 0
    END
  FROM public.auto_trade_executions
  WHERE user_id = auth.uid()
    AND creado_en >= v_since;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Actualizar fcm_token
CREATE OR REPLACE FUNCTION public.update_fcm_token(
  p_token TEXT
)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET fcm_token = p_token
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Guardar conexion Deriv (cifrada via Edge Function)
CREATE OR REPLACE FUNCTION public.save_deriv_connection(
  p_loginid TEXT,
  p_ciphertext TEXT,
  p_expires_at TIMESTAMPTZ,
  p_scopes TEXT
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.deriv_connections (user_id, loginid, ciphertext, expires_at, scopes)
  VALUES (auth.uid(), p_loginid, p_ciphertext, p_expires_at, p_scopes)
  ON CONFLICT (user_id) DO UPDATE SET
    loginid = EXCLUDED.loginid,
    ciphertext = EXCLUDED.ciphertext,
    expires_at = EXCLUDED.expires_at,
    scopes = EXCLUDED.scopes,
    connected_at = now();

  UPDATE public.profiles
  SET deriv_connection_status = 'connected'
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Desconectar Deriv
CREATE OR REPLACE FUNCTION public.disconnect_deriv()
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.deriv_connections
  WHERE user_id = auth.uid();

  UPDATE public.profiles
  SET deriv_connection_status = 'disconnected'
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ================= 004b_create_deriv_oauth_states.sql =================
-- =============================================
-- Migration 004b: crear deriv_oauth_states
-- (En el proyecto original esta tabla se creo a mano; faltaba en migraciones.)
-- Guarda el estado/code_verifier del OAuth PKCE de Deriv.
-- =============================================

CREATE TABLE IF NOT EXISTS public.deriv_oauth_states (
  state           TEXT PRIMARY KEY,
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  code_verifier   TEXT NOT NULL,
  redirect_target TEXT,
  expires_at      TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '10 minutes'),
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_deriv_oauth_states_user
  ON public.deriv_oauth_states (user_id);

ALTER TABLE public.deriv_oauth_states ENABLE ROW LEVEL SECURITY;
-- Sin politicas: solo service_role (Edge Functions) accede.


-- ================= 005_add_redirect_target.sql =================
-- Migration: Add redirect_target to deriv_oauth_states
-- Allows web and mobile to use different redirect URLs after OAuth

ALTER TABLE public.deriv_oauth_states
ADD COLUMN IF NOT EXISTS redirect_target text;


-- ================= 006_protect_admin_role.sql =================
-- =============================================
-- Syntrade — 006: proteger el rol de admin
-- Impide que un usuario autenticado no-admin cambie su propio rol.
-- Permite SQL Editor / service_role (auth.uid() = null) y a admins reales.
-- =============================================

create or replace function public.protect_profile_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.rol is distinct from old.rol
     and auth.uid() is not null
     and not public.is_admin() then
    raise exception 'No autorizado a cambiar el rol';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_profile_fields on public.profiles;
create trigger trg_protect_profile_fields
  before update on public.profiles
  for each row
  execute function public.protect_profile_fields();


-- ================= 007_fix_join_ventana_multiplicador.sql =================
-- Fix join_ventana to accept p_multiplicador (called by Flutter app)
DROP FUNCTION IF EXISTS public.join_ventana(uuid, numeric);
CREATE OR REPLACE FUNCTION public.join_ventana(
  p_ventana_id uuid,
  p_monto numeric DEFAULT 0,
  p_multiplicador numeric DEFAULT 1
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_participation_id uuid;
  v_subscription record;
  v_vent record;
BEGIN
  SELECT * INTO v_subscription
  FROM public.subscriptions
  WHERE user_id = auth.uid() AND estado = 'activa' AND fecha_fin > now()
  LIMIT 1;

  IF v_subscription IS NULL THEN
    RAISE EXCEPTION 'Se requiere suscripcion activa para participar';
  END IF;

  SELECT * INTO v_vent
  FROM public.ventanas_senales
  WHERE id = p_ventana_id AND estado IN ('programada', 'activa');

  IF v_vent IS NULL THEN
    RAISE EXCEPTION 'La ventana no esta disponible';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.ventanas_participacion
    WHERE ventana_id = p_ventana_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Ya estas participando en esta ventana';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND capital_inicial_configurado = true
  ) THEN
    RAISE EXCEPTION 'Debes configurar tu capital inicial primero';
  END IF;

  INSERT INTO public.ventanas_participacion (ventana_id, user_id, monto, multiplicador)
  VALUES (p_ventana_id, auth.uid(), p_monto, p_multiplicador)
  RETURNING id INTO v_participation_id;

  RETURN v_participation_id;
END;
$$;


-- ================= 009_sync_activos_and_simplify_signal.sql =================
-- =============================================
-- Migration 009: Sync activos from Deriv + simplify signal form
-- =============================================

-- 0. Ensure UNIQUE constraint on deriv_symbol (required for upsert)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'activos_deriv_symbol_key'
  ) THEN
    ALTER TABLE public.activos ADD CONSTRAINT activos_deriv_symbol_key UNIQUE (deriv_symbol);
  END IF;
END $$;

-- 1. Add 'tipo' column to activos
ALTER TABLE public.activos ADD COLUMN IF NOT EXISTS tipo TEXT DEFAULT 'volatility'
  CHECK (tipo IN ('volatility','boom','crash'));

-- Backfill tipo from deriv_symbol
UPDATE public.activos SET tipo = CASE
  WHEN UPPER(deriv_symbol) LIKE 'BOOM%' THEN 'boom'
  WHEN UPPER(deriv_symbol) LIKE 'CRASH%' THEN 'crash'
  ELSE 'volatility'
END WHERE tipo IS NULL OR tipo = 'volatility';

-- 2. Expand ventanas_senales.tipo CHECK to include volatility
ALTER TABLE public.ventanas_senales DROP CONSTRAINT IF EXISTS ventanas_senales_tipo_check;
ALTER TABLE public.ventanas_senales ADD CONSTRAINT ventanas_senales_tipo_check
  CHECK (tipo IN ('boom','crash','volatility'));

-- 3. Add multiplicador (numeric) to ventanas_senales
ALTER TABLE public.ventanas_senales ADD COLUMN IF NOT EXISTS multiplicador NUMERIC;

-- 4. Drop old columns from ventanas_senales
ALTER TABLE public.ventanas_senales DROP COLUMN IF EXISTS multiplicador_recomendado;
ALTER TABLE public.ventanas_senales DROP COLUMN IF EXISTS confianza;

-- 5. Recreate admin_create_ventana with new signature
-- (DROP the old signature first to avoid an overload / "function is not unique")
DROP FUNCTION IF EXISTS public.admin_create_ventana(
  text, uuid, text, text, text, integer, timestamptz, numeric, text, integer
);

CREATE OR REPLACE FUNCTION public.admin_create_ventana(
  p_activo_id UUID,
  p_deriv_symbol TEXT,
  p_tipo TEXT,
  p_direccion TEXT,
  p_fecha_inicio TIMESTAMPTZ,
  p_multiplicador NUMERIC,
  p_riesgo_recomendado NUMERIC DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_ventana_id UUID;
  v_activo_nombre TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  SELECT nombre INTO v_activo_nombre FROM public.activos WHERE id = p_activo_id;

  INSERT INTO public.ventanas_senales (
    titulo, activo_id, deriv_symbol, tipo, direccion,
    duracion_minutos, fecha_inicio, fecha_fin,
    estado, creado_por_admin_id, riesgo_recomendado, multiplicador
  ) VALUES (
    COALESCE(v_activo_nombre, p_deriv_symbol),
    p_activo_id, p_deriv_symbol, p_tipo, p_direccion,
    5, p_fecha_inicio,
    p_fecha_inicio + INTERVAL '5 minutes',
    'programada', auth.uid(), p_riesgo_recomendado, p_multiplicador
  ) RETURNING id INTO v_ventana_id;

  RETURN v_ventana_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Update join_ventana to use ventana's multiplicador if participant doesn't specify
CREATE OR REPLACE FUNCTION public.join_ventana(
  p_ventana_id UUID,
  p_monto NUMERIC DEFAULT 0,
  p_multiplicador NUMERIC DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_participation_id UUID;
  v_subscription RECORD;
  v_vent RECORD;
  v_mult NUMERIC;
BEGIN
  SELECT * INTO v_subscription
  FROM public.subscriptions
  WHERE user_id = auth.uid() AND estado = 'activa' AND fecha_fin > now()
  LIMIT 1;

  IF v_subscription IS NULL THEN
    RAISE EXCEPTION 'Se requiere suscripcion activa para participar';
  END IF;

  SELECT * INTO v_vent
  FROM public.ventanas_senales
  WHERE id = p_ventana_id AND estado IN ('programada', 'activa');

  IF v_vent IS NULL THEN
    RAISE EXCEPTION 'La ventana no esta disponible';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.ventanas_participacion
    WHERE ventana_id = p_ventana_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Ya estas participando en esta ventana';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND capital_inicial_configurado = true
  ) THEN
    RAISE EXCEPTION 'Debes configurar tu capital inicial primero';
  END IF;

  -- Use provided multiplicador, or fall back to ventana's multiplicador
  v_mult := COALESCE(p_multiplicador, v_vent.multiplicador, 100);

  INSERT INTO public.ventanas_participacion (ventana_id, user_id, monto, multiplicador)
  VALUES (p_ventana_id, auth.uid(), p_monto, v_mult)
  RETURNING id INTO v_participation_id;

  RETURN v_participation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ================= 011_risk_percentages_up_to_50.sql =================
-- Ampliar porcentajes de riesgo permitidos de (1,2,3,4,5,10) hasta 50%
-- para operar con capitales/saldos bajos (stake minimo Deriv ~1 USD).

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_risk_percentage_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_risk_percentage_check
  CHECK (risk_percentage IN (1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 50));

CREATE OR REPLACE FUNCTION public.set_risk_profile(
  p_risk_percentage NUMERIC
)
RETURNS VOID AS $$
BEGIN
  IF p_risk_percentage NOT IN (1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 50) THEN
    RAISE EXCEPTION 'Porcentaje de riesgo no valido';
  END IF;

  UPDATE public.profiles
  SET risk_percentage = p_risk_percentage
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ================= 012_bridge_scalability.sql =================
-- 012_bridge_scalability.sql
-- Escalar bridge a 100+ usuarios: lotes, pendiente, reconciliación, índices

-- permitir estado 'pendiente' y 'cancelada'
ALTER TABLE public.auto_trade_executions DROP CONSTRAINT IF EXISTS auto_trade_executions_estado_check;
ALTER TABLE public.auto_trade_executions
  ADD CONSTRAINT auto_trade_executions_estado_check
  CHECK (estado IN ('pendiente','en_curso','ganada','perdida','rechazada','cancelada'));

-- índices para el volumen
CREATE INDEX IF NOT EXISTS idx_exec_ventana_user ON public.auto_trade_executions (ventana_id, user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_estado ON public.subscriptions (user_id, estado);
CREATE INDEX IF NOT EXISTS idx_exec_pendiente ON public.auto_trade_executions (creado_en) WHERE estado = 'pendiente';

-- incremento atómico de ganancia (evita read-then-write race condition)
CREATE OR REPLACE FUNCTION public.add_ganancia(p_user_id uuid, p_delta numeric)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.profiles
  SET ganancia_acumulada = COALESCE(ganancia_acumulada, 0) + p_delta
  WHERE id = p_user_id;
END; $$;


-- ================= 014_suscripcion_acceso.sql =================
-- 014_suscripcion_acceso.sql
-- Control de acceso por suscripción: estado pendiente, activación admin, cascadas, limpieza.

-- ============================================================
-- 1) Permitir estado 'pendiente' en subscriptions
-- ============================================================
ALTER TABLE public.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_estado_check;
ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_estado_check
  CHECK (estado IN ('pendiente', 'activa', 'vencida', 'cancelada'));

-- ============================================================
-- 2) Cascada para borrar usuarios limpiamente
-- ============================================================
-- auto_trade_executions.user_id -> profiles: cambiar a CASCADE
ALTER TABLE public.auto_trade_executions
  DROP CONSTRAINT IF EXISTS auto_trade_executions_user_id_fkey;
ALTER TABLE public.auto_trade_executions
  ADD CONSTRAINT auto_trade_executions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- deriv_connections.user_id -> profiles: CASCADE (verificar)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'deriv_connections_user_id_fkey'
      AND table_name = 'deriv_connections'
  ) THEN
    ALTER TABLE public.deriv_connections
      DROP CONSTRAINT deriv_connections_user_id_fkey;
    ALTER TABLE public.deriv_connections
      ADD CONSTRAINT deriv_connections_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

-- subscriptions.user_id -> profiles: CASCADE (verificar)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'subscriptions_user_id_fkey'
      AND table_name = 'subscriptions'
  ) THEN
    ALTER TABLE public.subscriptions
      DROP CONSTRAINT subscriptions_user_id_fkey;
    ALTER TABLE public.subscriptions
      ADD CONSTRAINT subscriptions_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ============================================================
-- 3) handle_new_user: crear perfil SIN acceso (suscripción pendiente)
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, nombre)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'nombre', NEW.raw_user_meta_data->>'name', NEW.email));
  INSERT INTO public.subscriptions (user_id, plan, estado, fecha_inicio, fecha_fin)
  VALUES (NEW.id, 'gratis', 'pendiente', now(), now());
  RETURN NEW;
END;
$$;

-- ============================================================
-- 4) RPC: activar_suscripcion (solo admin) — plan único VIP
-- ============================================================
CREATE OR REPLACE FUNCTION public.activar_suscripcion(
  p_user_id uuid,
  p_meses int DEFAULT 12
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_inicio timestamptz;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  SELECT COALESCE(fecha_registro, now()) INTO v_inicio
    FROM public.profiles WHERE id = p_user_id;

  UPDATE public.subscriptions
    SET estado = 'activa',
        plan = 'vip',
        fecha_inicio = v_inicio,
        fecha_fin = v_inicio + make_interval(months => p_meses),
        plan_display_name = 'VIP'
    WHERE user_id = p_user_id;

  -- Si no existía registro de suscripción, crearlo
  IF NOT FOUND THEN
    INSERT INTO public.subscriptions (user_id, plan, estado, fecha_inicio, fecha_fin, plan_display_name)
    VALUES (p_user_id, 'vip', 'activa', v_inicio, v_inicio + make_interval(months => p_meses), 'VIP');
  END IF;
END;
$$;

-- ============================================================
-- 5) RPC: mi_suscripcion (para que la app consulte su estado)
-- ============================================================
CREATE OR REPLACE FUNCTION public.mi_suscripcion()
RETURNS TABLE(
  estado text,
  plan text,
  fecha_fin timestamptz,
  plan_display_name text
)
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT s.estado, s.plan, s.fecha_fin, s.plan_display_name
  FROM public.subscriptions s
  WHERE s.user_id = auth.uid()
  LIMIT 1;
$$;

-- ============================================================
-- 6) Índice para consultas por estado y fecha_fin
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_subs_estado_fin
  ON public.subscriptions (estado, fecha_fin);


-- ================= 016_device_limit.sql =================
-- 016_device_limit.sql
-- RPC para registrar el dispositivo actual del usuario.
-- Las columnas device_id y last_login_at ya existen en profiles (migración 003).

CREATE OR REPLACE FUNCTION public.register_device(p_device_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.profiles
    SET device_id = p_device_id, last_login_at = now()
    WHERE id = auth.uid();
END;
$$;


-- ================= 017_profile_email.sql =================
-- 017_profile_email.sql
-- Agrega columna email a profiles para mostrar el correo en el panel admin.

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;

-- Actualizar handle_new_user para guardar el email
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, nombre, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nombre', NEW.raw_user_meta_data->>'name', NEW.email),
    NEW.email
  );
  INSERT INTO public.subscriptions (user_id, plan, estado, fecha_inicio, fecha_fin)
  VALUES (NEW.id, 'gratis', 'pendiente', now(), now());
  RETURN NEW;
END; $$;

-- Backfill de usuarios existentes
UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE u.id = p.id AND (p.email IS NULL OR p.email = '');


-- ================= 018_external_signal_id.sql =================
-- =============================================
-- Migration 018: external_signal_id en ventanas_senales
-- Permite idempotencia de senales externas (ingest-signal).
-- =============================================

ALTER TABLE public.ventanas_senales
  ADD COLUMN IF NOT EXISTS external_signal_id text UNIQUE;

CREATE INDEX IF NOT EXISTS idx_ventanas_external_signal_id
  ON public.ventanas_senales (external_signal_id);


-- ================= 019_drop_multiplicador.sql =================
-- =============================================
-- Migration 019: eliminar el concepto "multiplicador"
-- El multiplicador lo define Index Pro Gestion (MT5).
-- Syntrade NO lo gestiona: se quita de esquema y funciones.
-- =============================================

-- 0) Quitar la vista que depende de auto_trade_executions.multiplicador
DROP VIEW IF EXISTS public.user_recent_trades;

-- 1) Recrear funciones que lo referencian, SIN multiplicador
--    (primero drop de firmas viejas para evitar overloading ambiguo)

DROP FUNCTION IF EXISTS public.admin_create_ventana(uuid, text, text, text, timestamptz, numeric, numeric);
DROP FUNCTION IF EXISTS public.admin_create_ventana(uuid, text, text, text, timestamptz, numeric);

CREATE OR REPLACE FUNCTION public.admin_create_ventana(
  p_activo_id UUID,
  p_deriv_symbol TEXT,
  p_tipo TEXT,
  p_direccion TEXT,
  p_fecha_inicio TIMESTAMPTZ,
  p_riesgo_recomendado NUMERIC DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_ventana_id UUID;
  v_activo_nombre TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  SELECT nombre INTO v_activo_nombre FROM public.activos WHERE id = p_activo_id;

  INSERT INTO public.ventanas_senales (
    titulo, activo_id, deriv_symbol, tipo, direccion,
    duracion_minutos, fecha_inicio, fecha_fin,
    estado, creado_por_admin_id, riesgo_recomendado
  ) VALUES (
    COALESCE(v_activo_nombre, p_deriv_symbol),
    p_activo_id, p_deriv_symbol, p_tipo, p_direccion,
    5, p_fecha_inicio,
    p_fecha_inicio + INTERVAL '5 minutes',
    'programada', auth.uid(), p_riesgo_recomendado
  ) RETURNING id INTO v_ventana_id;

  RETURN v_ventana_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS public.join_ventana(uuid, numeric, numeric);
DROP FUNCTION IF EXISTS public.join_ventana(uuid, numeric);

CREATE OR REPLACE FUNCTION public.join_ventana(
  p_ventana_id UUID,
  p_monto NUMERIC DEFAULT 0
)
RETURNS UUID AS $$
DECLARE
  v_participation_id UUID;
  v_subscription RECORD;
  v_vent RECORD;
BEGIN
  SELECT * INTO v_subscription
  FROM public.subscriptions
  WHERE user_id = auth.uid() AND estado = 'activa' AND fecha_fin > now()
  LIMIT 1;

  IF v_subscription IS NULL THEN
    RAISE EXCEPTION 'Se requiere suscripcion activa para participar';
  END IF;

  SELECT * INTO v_vent
  FROM public.ventanas_senales
  WHERE id = p_ventana_id AND estado IN ('programada', 'activa');

  IF v_vent IS NULL THEN
    RAISE EXCEPTION 'La ventana no esta disponible';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.ventanas_participacion
    WHERE ventana_id = p_ventana_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Ya estas participando en esta ventana';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND capital_inicial_configurado = true
  ) THEN
    RAISE EXCEPTION 'Debes configurar tu capital inicial primero';
  END IF;

  INSERT INTO public.ventanas_participacion (ventana_id, user_id, monto)
  VALUES (p_ventana_id, auth.uid(), p_monto)
  RETURNING id INTO v_participation_id;

  RETURN v_participation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2) Borrar columnas de multiplicador
ALTER TABLE public.ventanas_senales        DROP COLUMN IF EXISTS multiplicador;
ALTER TABLE public.ventanas_participacion  DROP COLUMN IF EXISTS multiplicador;
ALTER TABLE public.auto_trade_executions    DROP COLUMN IF EXISTS multiplicador;
ALTER TABLE public.auto_trade_config        DROP COLUMN IF EXISTS multiplicador_default;
ALTER TABLE public.activos                  DROP COLUMN IF EXISTS multiplicadores;

-- 3) Recrear la vista ya sin multiplicador (ate.* toma las columnas actuales)
CREATE OR REPLACE VIEW public.user_recent_trades AS
SELECT
  ate.*,
  v.titulo as ventana_titulo,
  v.direccion as ventana_direccion
FROM public.auto_trade_executions ate
LEFT JOIN public.ventanas_senales v ON v.id = ate.ventana_id
ORDER BY ate.creado_en DESC;


