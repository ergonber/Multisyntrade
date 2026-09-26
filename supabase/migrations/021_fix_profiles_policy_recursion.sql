-- =============================================
-- 021 - Fix: recursion infinita en politicas de profiles
-- =============================================
-- La politica "admin_select_all_profiles" consultaba public.profiles dentro de
-- su propio USING. Eso provoca ERROR 42P17 "infinite recursion detected in
-- policy for relation profiles" al evaluar cualquier policy que referencie
-- profiles (p. ej. admin_select_all_ventanas), lo que rompe:
--   * las lecturas del rol authenticated (profiles, ventanas_senales, ...)
--   * la entrega de eventos Realtime (realtime.apply_rls ejecuta las policies)
-- Se reemplaza por public.is_admin() (SECURITY DEFINER, definida en 004).

DROP POLICY IF EXISTS "admin_select_all_profiles" ON public.profiles;

CREATE POLICY "admin_select_all_profiles"
  ON public.profiles FOR SELECT
  USING (public.is_admin());

GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated, service_role;
