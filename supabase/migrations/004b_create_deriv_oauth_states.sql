-- =============================================
-- Migration 004b: crear deriv_oauth_states
-- (En el proyecto original esta tabla se creo a mano; faltaba en migraciones.)
-- Guarda el estado/code_verifier del OAuth PKCE de Deriv.
-- =============================================

CREATE TABLE IF NOT EXISTS public.deriv_oauth_states (
  state           TEXT PRIMARY KEY,
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  code_verifier   TEXT NOT NULL,
  redirect_target TEXT,
  expires_at      TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '10 minutes'),
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_deriv_oauth_states_user
  ON public.deriv_oauth_states (user_id);

ALTER TABLE public.deriv_oauth_states ENABLE ROW LEVEL SECURITY;
-- Sin politicas: solo service_role (Edge Functions) accede.
