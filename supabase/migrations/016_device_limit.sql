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
