-- Plan area 7, item 3096: no penalty for taking a break. Being away for months never costs a
-- league tier, a place in a bund or a share of a raid.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-0000000000f7'), ('20000000-0000-0000-0000-0000000000f8')
on conflict do nothing;
create temp table pz (k text primary key, v jsonb);
grant all on pz to authenticated;
update public.feature_flags set enabled = true where key in ('bund', 'raid');
set role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000f7', false);
select public.hello(1);
select public.team_set('[{"species": "Kindlop", "level": 30, "moves": []}]');
select public.league_join('fair', '["Kindlop"]');
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000f8', false);
select public.hello(1);
reset role;

update public.league_fair_entries set rating = 1800 where user_id = '20000000-0000-0000-0000-0000000000f7';
insert into public.bunds (id, name_a, name_b) values (9907, 1, 2) on conflict do nothing;
insert into public.bund_members (user_id, bund_id, role, joined_at) values
  ('20000000-0000-0000-0000-0000000000f8', 9907, 'leader', now() - interval '200 days'),
  ('20000000-0000-0000-0000-0000000000f7', 9907, 'member', now() - interval '200 days')
on conflict do nothing;
insert into public.raids (id, guardian, level, players, hp_total, hp_left, closes_at)
values (9907, 'Cairnhold', 60, 2, 1200, 400, now() - interval '1 day') on conflict do nothing;
insert into public.raid_members (raid_id, user_id, damage) values
  (9907, '20000000-0000-0000-0000-0000000000f7', 500), (9907, '20000000-0000-0000-0000-0000000000f8', 300)
on conflict do nothing;
-- f7 was away for half a year.
update public.profiles set last_seen = now() - interval '180 days' where id = '20000000-0000-0000-0000-0000000000f7';

set role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000f8', false);
insert into pz values ('bund', public.bund_info());
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000f7', false);
insert into pz values ('league', public.league_info('fair'));
insert into pz values ('raid', public.raid_list());
reset role;

do $$
begin
  assert ((select v from pz where k = 'league')->>'tier')::int = public._league_tier(1800), 'the tier stays';
  assert (select rating from public.league_fair_entries where user_id = '20000000-0000-0000-0000-0000000000f7') = 1800,
    'the rating does not fall';
  assert jsonb_array_length((select v from pz where k = 'bund')->'bund'->'members') = 2, 'the bund place stays';
  assert (select damage from public.raid_members where raid_id = 9907 and user_id = '20000000-0000-0000-0000-0000000000f7') = 500,
    'the raid share stays';
end $$;
