-- 013_reconcile_cron.sql
-- Reconciliación automática de ejecuciones en estado 'pendiente' cada 5 minutos.
-- Usa el secreto de Vault 'service_role_key' para no exponer la clave en el repo.

do $$
begin
  perform cron.unschedule('deriv-reconcile');
exception when others then null;
end $$;

select cron.schedule(
  'deriv-reconcile',
  '*/5 * * * *',
  $job$
  select net.http_post(
    url := 'https://qyackdsmicnsvpnqcmww.supabase.co/functions/v1/deriv-reconcile',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $job$
);
