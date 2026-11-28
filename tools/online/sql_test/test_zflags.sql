-- Plan area 7, item 2675: hello lists the features that are on for the game's version.
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000f1') on conflict do nothing;
reset role;
update public.feature_flags set enabled = true, min_version = 3 where key = 'trade';
set role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000f1', false);
do $$
declare f jsonb;
begin
  f := public.hello(1)->'flags';
  assert f ? 'league_fair' and f ? 'league_open', 'leagues are on';
  assert not f ? 'trade', 'trade needs version 3';
  assert not f ? 'raid', 'raids are off';
  assert public.hello(3)->'flags' ? 'trade', 'trade on for version 3';
end $$;
reset role;
update public.feature_flags set enabled = false, min_version = 1 where key = 'trade';
delete from auth.users where id = '20000000-0000-0000-0000-0000000000f1';
