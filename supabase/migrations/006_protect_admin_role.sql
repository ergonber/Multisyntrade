-- =============================================
-- Syntrade — 006: proteger el rol de admin
-- Impide que un usuario autenticado no-admin cambie su propio rol.
-- Permite SQL Editor / service_role (auth.uid() = null) y a admins reales.
-- =============================================

create or replace function public.protect_profile_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.rol is distinct from old.rol
     and auth.uid() is not null
     and not public.is_admin() then
    raise exception 'No autorizado a cambiar el rol';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_profile_fields on public.profiles;
create trigger trg_protect_profile_fields
  before update on public.profiles
  for each row
  execute function public.protect_profile_fields();
