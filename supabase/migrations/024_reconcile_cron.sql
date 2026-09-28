-- 024_reconcile_cron.sql
-- Reconciliacion periodica: vende posiciones huerfanas (en_curso con ventana cerrada)
-- y reconcilia contratos que Deriv cerro por su cuenta (stop-out).
-- La clave del endpoint vive en private_config (NO versionada) y en el secret RECONCILE_KEY.

CREATE TABLE IF NOT EXISTS public.private_config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
ALTER TABLE public.private_config ENABLE ROW LEVEL SECURITY;  -- sin politicas: solo service_role/postgres

DO $$
BEGIN
  PERFORM cron.unschedule('reconcile_orphans');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule('reconcile_orphans', '*/3 * * * *', $cmd$
  SELECT net.http_post(
    url := 'https://fpmtysxmxvzkuplnvduu.supabase.co/functions/v1/deriv-reconcile',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-reconcile-key', (SELECT value FROM public.private_config WHERE key = 'reconcile_key')
    ),
    body := '{}'::jsonb
  );
$cmd$);
