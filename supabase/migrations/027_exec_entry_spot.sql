-- 027_exec_entry_spot.sql
-- Guardar el spot real de entrada de nuestro contrato, para medir slippage vs la senal.
ALTER TABLE public.auto_trade_executions ADD COLUMN IF NOT EXISTS entry_spot NUMERIC;
