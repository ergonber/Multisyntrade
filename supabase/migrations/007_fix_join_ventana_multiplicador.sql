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
