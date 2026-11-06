-- Plan area 7: the old report call names the caller too, like every player function
-- (test_security.sql from area 9 checks for public._uid()).
create or replace function public.report(p_code text, p_reason int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._uid();
  return public.report_in(p_code, p_reason, 'friends', null);
end $$;
