-- 029_auto_signals.sql
-- Senales propias (no Telegram): guardar origen y TP/SL en % del precio.
ALTER TABLE public.ventanas_senales ADD COLUMN IF NOT EXISTS origen TEXT DEFAULT 'telegram';
ALTER TABLE public.ventanas_senales ADD COLUMN IF NOT EXISTS tp_pct NUMERIC;
ALTER TABLE public.ventanas_senales ADD COLUMN IF NOT EXISTS sl_pct NUMERIC;
