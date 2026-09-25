-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Store service_role key in Vault (run once)
-- INSERT INTO vault.decrypted_secrets (name, secret)
-- VALUES ('service_role_key', 'YOUR_SERVICE_ROLE_KEY_HERE')
-- ON CONFLICT (name) DO UPDATE SET secret = EXCLUDED.secret;

-- Schedule deriv-bridge every minute
SELECT cron.schedule(
  'deriv-bridge',
  '* * * * *',
  $$
    SELECT net.http_post(
      url := 'https://qyackdsmicnsvpnqcmww.supabase.co/functions/v1/deriv-bridge',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (
          SELECT decrypted_secret
          FROM vault.decrypted_secrets
          WHERE name = 'service_role_key'
        )
      ),
      body := '{}'::jsonb
    );
  $$
);
