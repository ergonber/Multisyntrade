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
