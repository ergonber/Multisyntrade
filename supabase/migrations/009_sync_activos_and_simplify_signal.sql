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
