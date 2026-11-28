-- Plan area 7, item 2899: the web report form works without an account.
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000a7') on conflict do nothing;
create temp table wres (k text primary key, v jsonb);
grant all on wres to authenticated;
set role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000a7', false);
insert into wres values ('ok', public.report_web('abcd-2345', 0, 'The name is an insult.', 'me@example.org', true));
insert into wres values ('faith', public.report_web('ABCD2345', 0, 'The name is an insult.', null, false));
insert into wres values ('short', public.report_web('ABCD2345', 0, 'bad', null, true));
insert into wres values ('code', public.report_web('', 0, 'The name is an insult.', null, true));
do $$ begin
  begin
    perform count(*) from public.web_reports;
    assert false, 'a player could read web reports';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
do $$
declare
  ok jsonb := (select v from wres where k = 'ok');
begin
  assert (ok->>'ok')::boolean and (ok->>'report_id')::bigint > 0, ok::text;
  assert (select code from public.web_reports where id = (ok->>'report_id')::bigint) = 'ABCD2345', 'code normalised';
  assert (select v->>'error' from wres where k = 'faith') = 'good_faith', 'good faith needed';
  assert (select v->>'error' from wres where k = 'short') = 'details', 'explanation needed';
  assert (select v->>'error' from wres where k = 'code') = 'no_such_code', 'code needed';
  assert not exists (select 1 from auth.users where id = '20000000-0000-0000-0000-0000000000a7'), 'throwaway sign-in removed';
end $$;
-- The shared limit per hour.
update public.server_config set value = '1' where key = 'web_report_limit';
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000a8', false);
do $$ begin
  assert public.report_web('ABCD2345', 1, 'Unkind greetings every day.', null, true)->>'error' = 'slow_down', 'limit';
end $$;
update public.server_config set value = '30' where key = 'web_report_limit';
delete from public.web_reports;
