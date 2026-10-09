-- 031_tp_sl_usd.sql
-- TP/SL en dolares fijos (independiente del multiplicador/activo).
ALTER TABLE public.ventanas_senales ADD COLUMN IF NOT EXISTS tp_usd NUMERIC;
ALTER TABLE public.ventanas_senales ADD COLUMN IF NOT EXISTS sl_usd NUMERIC;
