-- =============================================
-- Syntrade - Datos iniciales (seed)
-- =============================================

-- Activos disponibles para Deriv
INSERT INTO public.activos (nombre, deriv_symbol, multiplicadores, habilitado) VALUES
  ('Boom 1000', 'BOOM1000', '{1,2,3,5,10,20,50,100}', true),
  ('Boom 500', 'BOOM500', '{1,2,3,5,10,20,50,100}', true),
  ('Boom 300', 'BOOM300', '{1,2,3,5,10,20,50,100}', true),
  ('Crash 1000', 'CRASH1000', '{1,2,3,5,10,20,50,100}', true),
  ('Crash 500', 'CRASH500', '{1,2,3,5,10,20,50,100}', true),
  ('Crash 300', 'CRASH300', '{1,2,3,5,10,20,50,100}', true),
  ('Crash 900', 'CRASH900', '{1,2,3,5,10,20,50,100}', true),
  ('Boom 900', 'BOOM900', '{1,2,3,5,10,20,50,100}', true),
  ('Volatility 75', 'V75', '{1,2,5,10,20,50,100,200}', true),
  ('Volatility 100', 'V100', '{1,2,5,10,20,50,100,200}', true),
  ('Volatility 50', 'V50', '{1,2,5,10,20,50,100,200}', true),
  ('Step Index', 'STEPINDEX', '{1,2,5,10,20,50}', true),
  ('Range Break', 'RANGEBREAK', '{1,2,5,10,20,50,100}', true),
  ('Jump 10', 'JUMP10', '{1,2,5,10,20,50,100}', true),
  ('Jump 25', 'JUMP25', '{1,2,5,10,20,50,100}', true),
  ('Jump 50', 'JUMP50', '{1,2,5,10,20,50,100}', true),
  ('Jump 75', 'JUMP75', '{1,2,5,10,20,50,100}', true),
  ('Jump 100', 'JUMP100', '{1,2,5,10,20,50,100}', true);

-- Anuncio de ejemplo
INSERT INTO public.announcements (title, body, activo) VALUES
  ('Bienvenido a SynTrade', 'La plataforma de senales de trading mas avanzada. Configura tu perfil de riesgo y comienza a operar.', true),
  ('Nuevo: Plan Pro Disponible', 'Accede a mas senales exclusivas y herramientas avanzadas. Consulta los planes disponibles.', true);
