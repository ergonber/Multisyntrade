-- Migration: Add redirect_target to deriv_oauth_states
-- Allows web and mobile to use different redirect URLs after OAuth

ALTER TABLE public.deriv_oauth_states
ADD COLUMN IF NOT EXISTS redirect_target text;
