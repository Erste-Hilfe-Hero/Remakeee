-- Plan area 9, item 3765: browser test accounts are marked and deleted after 30 days unused.
insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000e1'), ('00000000-0000-0000-0000-0000000000e2'),
  ('00000000-0000-0000-0000-0000000000e3')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false)
$$;
insert into public.profiles (id, code, last_seen) values
  ('00000000-0000-0000-0000-0000000000e1', 'EEEEAAAA', now()),
  ('00000000-0000-0000-0000-0000000000e2', 'EEEEBBBB', now()),
  ('00000000-0000-0000-0000-0000000000e3', 'EEEECCCC', now())
on conflict (id) do update set last_seen = excluded.last_seen;
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000e1');
do $$ begin
  assert (public.platform_set('web')->>'ok')::boolean, 'web is accepted';
  assert public.platform_set('moon')->>'error' = 'bad_platform', 'unknown platform refused';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000e2');
select public.platform_set('web');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000e3');
select public.platform_set('web');
select public.platform_set('app');
reset role;
do $$
declare n int;
begin
  update public.profiles set last_seen = now() - interval '31 days'
    where id in ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000e3');
  insert into public.mail (sender, recipient, kind) values
    ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000e2', 'wave');
  n := public._web_cleanup();
  assert n = 1, 'one old web account removed, got ' || n;
  assert not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000e1'), 'old web account gone';
  assert not exists (select 1 from public.mail where sender = '00000000-0000-0000-0000-0000000000e1'), 'its mail gone too';
  assert exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-0000000000e2'), 'recent web account stays';
  assert exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-0000000000e3'), 'moved to a phone: stays';
end $$;
