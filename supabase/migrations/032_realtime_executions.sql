-- =============================================
-- Migration 032: realtime de auto_trade_executions
-- La app escucha la tabla con supabase .stream(), así que tiene que estar
-- en la publicación de realtime (ventanas_senales ya lo está desde la 020).
-- =============================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'auto_trade_executions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.auto_trade_executions;
  END IF;
END $$;

-- El evento UPDATE transporta la fila nueva completa.
ALTER TABLE public.auto_trade_executions REPLICA IDENTITY DEFAULT;

-- Filtro principal de la app: origen='auto' (nuestras señales propias).
CREATE INDEX IF NOT EXISTS idx_ventanas_origen
  ON public.ventanas_senales (origen);

CREATE INDEX IF NOT EXISTS idx_ventanas_origen_estado
  ON public.ventanas_senales (origen, estado);
