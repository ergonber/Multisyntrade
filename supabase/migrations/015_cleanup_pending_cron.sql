-- 015_cleanup_pending_cron.sql
-- Limpieza diaria de usuarios con suscripción pendiente a las 03:00 UTC.
-- Usa el secreto de Vault 'service_role_key' para autenticar la llamada.

do $$
begin
  perform cron.unschedule('cleanup-pending-users');
exception when others then null;
end $$;

select cron.schedule(
  'cleanup-pending-users',
  '0 3 * * *',
  $job$
  select net.http_post(
    url := 'https://qyackdsmicnsvpnqcmww.supabase.co/functions/v1/cleanup-pending-users',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $job$
);
