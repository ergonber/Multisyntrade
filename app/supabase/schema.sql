-- =============================================
-- SynTrade MVP - Esquema de base de datos
-- =============================================

-- Perfil público de cada usuario (1:1 con auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nombre        TEXT,
  telefono      TEXT,
  foto_url      TEXT,
  rol           TEXT NOT NULL DEFAULT 'user' CHECK (rol IN ('user','admin')),
  capital_inicial        NUMERIC DEFAULT 0,
  ganancia_acumulada     NUMERIC DEFAULT 0,
  fecha_registro TIMESTAMPTZ DEFAULT NOW()
);

-- Activos disponibles para señales
CREATE TABLE IF NOT EXISTS public.activos (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre         TEXT UNIQUE NOT NULL,
  deriv_symbol   TEXT NOT NULL,
  multiplicadores NUMERIC[] DEFAULT '{}',
  habilitado     BOOLEAN DEFAULT TRUE
);

-- Señales de trading
CREATE TABLE IF NOT EXISTS public.signals (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activo_id      UUID REFERENCES public.activos(id),
  activo_nombre  TEXT,
  deriv_symbol   TEXT,
  tipo           TEXT CHECK (tipo IN ('compra','venta')),
  multiplicador  NUMERIC,
  precio_entrada NUMERIC,
  estado         TEXT DEFAULT 'activa' CHECK (estado IN ('activa','programada','cerrada','cancelada')),
  resultado      TEXT CHECK (resultado IN ('ganada','perdida','sin_operar')),
  r_value        NUMERIC(6,2),
  fecha_inicio   TIMESTAMPTZ DEFAULT NOW(),
  fecha_fin      TIMESTAMPTZ,
  creado_por     UUID REFERENCES auth.users(id)
);

-- Historial de operaciones del usuario
CREATE TABLE IF NOT EXISTS public.user_trades (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  signal_id    UUID REFERENCES public.signals(id),
  activo       TEXT,
  tipo         TEXT,
  monto        NUMERIC,
  resultado    NUMERIC,
  estado       TEXT DEFAULT 'activa' CHECK (estado IN ('activa','ganada','perdida')),
  creado_en    TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- Datos iniciales (seed)
-- =============================================

-- Activos disponibles
INSERT INTO public.activos (nombre, deriv_symbol, multiplicadores, habilitado) VALUES
  ('Boom 1000', 'BOOM1000', '{1,2,3,5,10,20,50,100}', true),
  ('Boom 500', 'BOOM500', '{1,2,3,5,10,20,50,100}', true),
  ('Boom 300', 'BOOM300', '{1,2,3,5,10,20,50,100}', true),
  ('Crash 1000', 'CRASH1000', '{1,2,3,5,10,20,50,100}', true),
  ('Crash 500', 'CRASH500', '{1,2,3,5,10,20,50,100}', true),
  ('Crash 300', 'CRASH300', '{1,2,3,5,10,20,50,100}', true),
  ('Volatility 75', 'V75', '{1,2,5,10,20,50,100,200}', true),
  ('Volatility 100', 'V100', '{1,2,5,10,20,50,100,200}', true),
  ('Step Index', 'STEPINDEX', '{1,2,5,10,20,50}', true);

-- Señales de ejemplo
INSERT INTO public.signals (activo_nombre, deriv_symbol, tipo, multiplicador, precio_entrada, estado, resultado, r_value) VALUES
  ('Boom 500', 'BOOM500', 'compra', 100, 8412.30, 'activa', NULL, NULL),
  ('Crash 1000', 'CRASH1000', 'venta', 50, 5234.10, 'activa', NULL, NULL),
  ('Step 100', 'STEP100', 'compra', 20, 1234.50, 'activa', NULL, NULL),
  ('Boom 1000', 'BOOM1000', 'compra', 100, 9876.50, 'cerrada', 'ganada', 1.45),
  ('Crash 300', 'CRASH300', 'venta', 5, 3456.70, 'cerrada', 'perdida', -0.80),
  ('Volatility 100', 'V100', 'compra', 20, 7654.30, 'cerrada', 'ganada', 2.10);

-- =============================================
-- RLS (Row Level Security)
-- =============================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_trades ENABLE ROW LEVEL SECURITY;

-- Profiles: el usuario ve y edita su propio perfil
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Signals: todos pueden ver las señales activas
CREATE POLICY "Anyone can view signals" ON public.signals
  FOR SELECT USING (true);

-- User trades: el usuario ve sus propias operaciones
CREATE POLICY "Users can view own trades" ON public.user_trades
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own trades" ON public.user_trades
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- =============================================
-- Función para crear perfil automáticamente
-- =============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, nombre)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', 'Trader'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para crear perfil al registrarse
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
