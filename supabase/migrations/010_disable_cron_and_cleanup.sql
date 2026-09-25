-- =============================================
-- Migration 010: Disable cron (execution is now triggered immediately from the app)
-- =============================================
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'deriv-bridge') THEN
    PERFORM cron.unschedule('deriv-bridge');
  END IF;
END $$;
