-- Bond unfurling (1.3.2): Spirlings of a finished trade carry the server's bond stamp, the own ones
-- back from an ended trade do not, a stamp never travels, and only a bond path's Keepsake may stay on.
insert into auth.users (id) values
  ('20000000-0000-0000-0000-0000000001b1'), ('20000000-0000-0000-0000-0000000001b2')
on conflict do nothing;
create or replace function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000001' || u, false)
$$;
create temp table bc (who text primary key, code text);
create temp table br (k text primary key, v jsonb);
grant all on bc, br to authenticated;
create temp table bf as select key, enabled from public.feature_flags where key in ('trade', 'trade_spirling');
update public.feature_flags set enabled = true where key in ('trade', 'trade_spirling');

set role authenticated;
select pg_temp.as_user('b1');
insert into bc values ('b1', public.hello(1)->'profile'->>'code');
select pg_temp.as_user('b2');
insert into bc values ('b2', public.hello(1)->'profile'->>'code');
select public.friend_request((select code from bc where who = 'b1'));
select pg_temp.as_user('b1');
select public.friend_respond((select code from bc where who = 'b2'), true);
reset role;
update public.friendships set points = 30, accepted_at = now() - interval '8 days'
where a = least('20000000-0000-0000-0000-0000000001b1'::uuid, '20000000-0000-0000-0000-0000000001b2'::uuid);
insert into public.saves (user_id, slot, rev, data) values
  ('20000000-0000-0000-0000-0000000001b1', 1, 1, '{"inventory": {},
    "party": [{"uid": "p1", "species": "Paddlewisp", "level": 10, "gleam": true, "gleam_kind": "rime", "gleam_boost": false},
              {"uid": "p0", "species": "Kindlop", "level": 9}],
    "storage": [{"uid": "p2", "species": "Vanecrow", "level": 20, "held": "swift_feather"},
                {"uid": "p3", "species": "Vanecrow", "level": 20, "held": "keen_lens"},
                {"uid": "p4", "species": "Snagwhisk", "level": 30, "bond_form": "Snagwhisk", "bond_item": "iron_burr"},
                {"uid": "p5", "species": "Talusgard", "level": 30}]}'),
  ('20000000-0000-0000-0000-0000000001b2', 1, 1, '{"inventory": {},
    "party": [{"uid": "q1", "species": "Zippit", "level": 20}],
    "storage": [{"uid": "q2", "species": "Quenchcoil", "level": 30, "held": "keen_lens"}]}')
on conflict (user_id, slot) do update set rev = excluded.rev, data = excluded.data;

set role authenticated;
select pg_temp.as_user('b1');
insert into br values ('open', public.trade_open((select code from bc where who = 'b2')));
insert into br values ('wrong_key', public.trade_put_spirlings(((select v from br where k = 'open')->>'trade')::bigint, 1, 1, array['p3']));
insert into br values ('put1', public.trade_put_spirlings(((select v from br where k = 'open')->>'trade')::bigint, 1, 1, array['p1', 'p2', 'p4']));
select pg_temp.as_user('b2');
insert into br values ('put2', public.trade_put_spirlings(((select v from br where k = 'open')->>'trade')::bigint, 1, 1, array['q2']));
insert into br values ('list2', public.trade_list());
insert into br values ('ok2', public.trade_confirm(((select v from br where k = 'open')->>'trade')::bigint, '{}'::jsonb, array['p1', 'p2', 'p4']));
select pg_temp.as_user('b1');
insert into br values ('ok1', public.trade_confirm(((select v from br where k = 'open')->>'trade')::bigint, '{}'::jsonb, array['q2']));
insert into br values ('get1', public.trade_collect(((select v from br where k = 'open')->>'trade')::bigint, 1, 2));
select pg_temp.as_user('b2');
insert into br values ('get2', public.trade_collect(((select v from br where k = 'open')->>'trade')::bigint, 1, 2));
-- An ended trade gives the own Spirling back without a bond.
select pg_temp.as_user('b1');
insert into br values ('open2', public.trade_open((select code from bc where who = 'b2')));
insert into br values ('put3', public.trade_put_spirlings(((select v from br where k = 'open2')->>'trade')::bigint, 1, 3, array['p5']));
insert into br values ('cancel', public.trade_cancel(((select v from br where k = 'open2')->>'trade')::bigint));
insert into br values ('back', public.trade_collect(((select v from br where k = 'open2')->>'trade')::bigint, 1, 4));
reset role;

do $$
declare b1 jsonb; b2 jsonb; m jsonb;
begin
  select data into b1 from public.saves where user_id = '20000000-0000-0000-0000-0000000001b1' and slot = 1;
  select data into b2 from public.saves where user_id = '20000000-0000-0000-0000-0000000001b2' and slot = 1;
  assert (select v->>'error' from br where k = 'wrong_key') = 'holds_item', 'only the bond path''s Keepsake may stay on';
  assert (select v from br where k = 'put1')->'took' = '["p1", "p2", "p4"]', 'put1: ' || (select v::text from br where k = 'put1');
  assert (select v->>'ok' from br where k = 'put2') = 'true', 'put2: ' || (select v::text from br where k = 'put2');
  assert not exists (select 1 from jsonb_array_elements((select v from br where k = 'list2')->'trades'->0->'theirs_mons') x
    where x ? 'bond_form' or x ? 'bond_item'), 'an earlier bond does not travel';
  assert ((select v from br where k = 'ok1')->>'done')::boolean, 'both confirmed';
  assert (select v from br where k = 'get2')->'mons'->0->>'bond_form' is not null, 'the answer carries the stamp';
  select x into m from jsonb_array_elements(b2->'storage') x where x->>'uid' = 'p1';
  assert m->>'bond_form' = 'Paddlewisp' and not m ? 'bond_item', 'bonded without a Keepsake: ' || m::text;
  assert m->>'gleam' = 'true' and m->>'gleam_kind' = 'rime', 'Gleam and kind kept';
  select x into m from jsonb_array_elements(b2->'storage') x where x->>'uid' = 'p2';
  assert m->>'bond_form' = 'Vanecrow' and m->>'bond_item' = 'swift_feather' and m->>'held' = 'swift_feather', 'bonded holding its Keepsake: ' || m::text;
  select x into m from jsonb_array_elements(b2->'storage') x where x->>'uid' = 'p4';
  assert m->>'bond_form' = 'Snagwhisk' and not m ? 'bond_item', 'the server stamp replaces a forged one: ' || m::text;
  select x into m from jsonb_array_elements(b1->'storage') x where x->>'uid' = 'q2';
  assert m->>'bond_form' = 'Quenchcoil' and m->>'bond_item' = 'keen_lens', 'the other side bonded too: ' || m::text;
  assert (select v from br where k = 'back')->'mons'->0->>'uid' = 'p5', 'own Spirling back';
  select x into m from jsonb_array_elements(b1->'storage') x where x->>'uid' = 'p5';
  assert not m ? 'bond_form', 'no bond from an ended trade: ' || m::text;
  assert public._trade_mon_why('{"uid": "x", "species": "Wickit", "held": "keen_lens"}'::jsonb) = 'holds_item', 'other Keepsakes stay';
  assert public._trade_mon_why('{"uid": "x", "species": "Brassjack", "held": "spark_coil"}'::jsonb) is null, 'the bond Keepsake travels';
end $$;

update public.feature_flags f set enabled = bf.enabled from bf where f.key = bf.key;
