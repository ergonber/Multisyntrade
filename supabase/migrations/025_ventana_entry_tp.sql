-- 025_ventana_entry_tp.sql
-- Guardar los niveles de la senal (entrada, TP1, TP2) para respetar los TP del proveedor.
ALTER TABLE public.ventanas_senales ADD COLUMN IF NOT EXISTS entry_ref NUMERIC;
ALTER TABLE public.ventanas_senales ADD COLUMN IF NOT EXISTS tp1 NUMERIC;
ALTER TABLE public.ventanas_senales ADD COLUMN IF NOT EXISTS tp2 NUMERIC;
