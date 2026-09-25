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
