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
