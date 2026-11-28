-- Plan area 7, item 2899: reports of illegal content also without an account (DSA Art. 16), from
-- the web form https://<address>/melden. Only Ali reads them; nothing from here reaches a player.
-- No account id is stored, the friend code stays text. Rows go after 6 months.
-- Nothing on the server is callable without signing in (test_security.sql), so the form signs in
-- anonymously like the game does; report_web removes that throwaway sign-in again afterwards
-- (an account without a game profile).

insert into public.server_config (key, value) values ('web_report_limit', '30')
on conflict (key) do nothing;

create table if not exists public.web_reports (
  id bigserial primary key,
  code text not null,
  reason int not null,
  details text not null,
  contact text,
  good_faith boolean not null,
  created_at timestamptz not null default now(),
  status text not null default 'open' check (status in ('open', 'upheld', 'rejected')),
  decided_at timestamptz
);
alter table public.web_reports enable row level security;
revoke all on public.web_reports from public, anon, authenticated;
revoke all on sequence public.web_reports_id_seq from public, anon, authenticated;

-- p_reason: 0 name, 1 greetings, 2 cheating, 3 other illegal content.
create or replace function public.report_web(p_code text, p_reason int, p_details text, p_contact text,
  p_good_faith boolean) returns jsonb
language plpgsql volatile security definer set search_path = public, auth as $$
declare
  u uuid := public._uid();
  c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  d text := btrim(coalesce(p_details, ''));
  n bigint;
begin
  if coalesce(p_good_faith, false) is not true then return public._fail('good_faith'); end if;
  if length(c) < 4 or length(c) > 16 then return public._fail('no_such_code'); end if;
  if length(d) < 10 then return public._fail('details'); end if;
  -- Everyone shares one limit per hour, the form has no account to count by.
  if (select count(*) from public.web_reports where created_at > now() - interval '1 hour')
      >= public._config_int('web_report_limit', 30) then
    return public._fail('slow_down');
  end if;
  delete from public.web_reports where created_at < now() - interval '6 months';
  insert into public.web_reports (code, reason, details, contact, good_faith)
  values (c, least(greatest(coalesce(p_reason, 3), 0), 3), left(d, 2000), left(nullif(btrim(coalesce(p_contact, '')), ''), 200), true)
  returning id into n;
  if not exists (select 1 from public.profiles where id = u) then
    delete from auth.users where id = u;
  end if;
  return jsonb_build_object('ok', true, 'report_id', n);
end $$;

revoke all on function public.report_web(text, int, text, text, boolean) from public, anon;
grant execute on function public.report_web(text, int, text, text, boolean) to authenticated;

