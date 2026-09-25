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
