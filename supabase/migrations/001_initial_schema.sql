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
