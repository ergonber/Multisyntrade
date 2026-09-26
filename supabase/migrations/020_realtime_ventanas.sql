-- =============================================
-- Migration 020: Realtime en ventanas_senales
-- Permite que la app reciba INSERT/UPDATE de senales
-- (llegada desde MT5 via ingest-signal) sin recargar.
-- =============================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'ventanas_senales'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ventanas_senales;
  END IF;
END $$;

-- El evento UPDATE transporta la fila nueva completa; el REPLICA IDENTITY
-- por defecto (PK) es suficiente para lo que consume la app.
ALTER TABLE public.ventanas_senales REPLICA IDENTITY DEFAULT;
