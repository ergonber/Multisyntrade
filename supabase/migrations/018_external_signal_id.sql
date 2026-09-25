-- =============================================
-- Migration 018: external_signal_id en ventanas_senales
-- Permite idempotencia de senales externas (ingest-signal).
-- =============================================

ALTER TABLE public.ventanas_senales
  ADD COLUMN IF NOT EXISTS external_signal_id text UNIQUE;

CREATE INDEX IF NOT EXISTS idx_ventanas_external_signal_id
  ON public.ventanas_senales (external_signal_id);
