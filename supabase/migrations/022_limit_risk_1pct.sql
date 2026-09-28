-- 022_limit_risk_1pct.sql
-- Riesgo por operacion FIJO en 1% (proteccion de capital del usuario).
-- El deriv-bridge ademas fuerza el 1% en tiempo de ejecucion.

-- 1) Fijar todas las filas a 1%
UPDATE public.profiles SET risk_percentage = 1 WHERE risk_percentage IS DISTINCT FROM 1;

-- 2) Constraint: solo 1%
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_risk_percentage_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_risk_percentage_check CHECK (risk_percentage = 1);

-- 3) RPC: solo acepta 1%
CREATE OR REPLACE FUNCTION public.set_risk_profile(
  p_risk_percentage NUMERIC
)
RETURNS VOID AS $$
BEGIN
  IF p_risk_percentage IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION 'El riesgo esta fijo en 1%%';
  END IF;

  UPDATE public.profiles
  SET risk_percentage = 1
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
