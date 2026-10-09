-- 030_auto_signal_cron.sql
-- Genera nuestras propias senales cada minuto.
DO $$ BEGIN PERFORM cron.unschedule('auto_signal'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
SELECT cron.schedule('auto_signal', '* * * * *', $cmd$
  SELECT net.http_post(
    url := 'https://fpmtysxmxvzkuplnvduu.supabase.co/functions/v1/auto-signal',
    headers := jsonb_build_object('Content-Type','application/json','x-reconcile-key',(SELECT value FROM public.private_config WHERE key='reconcile_key')),
    body := '{}'::jsonb);
$cmd$);
