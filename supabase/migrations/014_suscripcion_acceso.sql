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
