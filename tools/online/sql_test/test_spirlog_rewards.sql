-- Spirlog book rewards (20261128061000_spirlog_rewards.sql): the Riftglass of a step only when the
-- uploaded save reached it, once per account, children refused, not callable without signing in.
-- Same cases as tests/unit/test_spirlog_rewards.gd.
insert into auth.users (id) values
  ('2c000000-0000-0000-0000-000000000001'), ('2c000000-0000-0000-0000-000000000002')
on conflict do nothing;

do $$ begin
  assert not has_function_privilege('anon', 'public.spirlog_reward_claim(int, text)', 'execute'), 'anon cannot claim';
  assert has_function_privilege('authenticated', 'public.spirlog_reward_claim(int, text)', 'execute');
  assert not has_function_privilege('authenticated', 'public._spirlog_have(jsonb, text)', 'execute'), 'helper hidden';
  assert (select count(*) from public.game_species) > 0, 'game data loaded';
end $$;

-- A save with [n] kinds bonded (the first by name) and [g] of them with a Gleam bonded.
create or replace function pg_temp.book(n int, g int) returns jsonb
language sql as $$
  select jsonb_build_object('spirlog', coalesce(jsonb_object_agg(name, jsonb_build_object('seen', true, 'bonded', true,
    'gleam_bonded', rn <= g)), '{}'::jsonb) || '{"Not A Kind": {"bonded": true}, "Broken": 3}'::jsonb)
  from (select name, row_number() over (order by name) rn from public.game_species order by name limit n) k
$$;

do $$ begin perform set_config('request.jwt.claim.sub', '2c000000-0000-0000-0000-000000000001', false); end $$;
do $$
declare
  total int := (select count(*) from public.game_species);
  need int := ceil(total * 25 / 100.0)::int;
  r jsonb;
begin
  assert public.spirlog_reward_claim(1, 'bonded_25')->>'error' = 'no_save', 'needs the save on the server';
  assert public.spirlog_reward_claim(1, 'free_glass')->>'error' = 'unknown_reward';
  insert into public.saves (user_id, slot, data) values ('2c000000-0000-0000-0000-000000000001', 1, pg_temp.book(need - 1, 9));
  assert public._spirlog_have(pg_temp.book(need - 1, 9), 'bonded') = need - 1, 'unknown kinds and broken entries do not count';
  assert public.spirlog_reward_claim(1, 'bonded_25')->>'error' = 'not_reached', 'one kind short';
  assert public.spirlog_reward_claim(1, 'gleam_10')->>'error' = 'not_reached', 'one Gleam short';
  update public.saves set data = pg_temp.book(need, 10) where user_id = '2c000000-0000-0000-0000-000000000001' and slot = 1;
  r := public.spirlog_reward_claim(1, 'bonded_25');
  assert (r->>'ok')::boolean and (r->>'added')::int = 100 and (r->>'balance')::int = 100, r::text;
  assert public.spirlog_reward_claim(1, 'bonded_25')->>'error' = 'already', 'once per account';
  assert public.spirlog_reward_claim(2, 'bonded_25')->>'error' = 'already', 'once per account, not per slot';
  r := public.spirlog_reward_claim(1, 'gleam_10');
  assert (r->>'added')::int = 50 and (r->>'balance')::int = 150, r::text;
  assert public.spirlog_reward_claim(1, 'bonded_50')->>'error' = 'not_reached';
  assert (select count(*) from public.ledger where user_id = '2c000000-0000-0000-0000-000000000001' and reason = 'spirlog') = 2;
  assert (select balance from public.wallets where user_id = '2c000000-0000-0000-0000-000000000001') = 150;
end $$;

-- Children's accounts: no Riftglass, even with the whole book.
do $$ begin perform set_config('request.jwt.claim.sub', '2c000000-0000-0000-0000-000000000002', false); end $$;
do $$ begin
  assert public.shop_set_age(extract(year from now())::int - 9, 1)->>'band' = '0';
  insert into public.saves (user_id, slot, data) values ('2c000000-0000-0000-0000-000000000002', 1, pg_temp.book(100000, 100000));
  assert public.spirlog_reward_claim(1, 'bonded_100')->>'error' = 'age';
  assert not exists (select 1 from public.spirlog_rewards where user_id = '2c000000-0000-0000-0000-000000000002');
end $$;
do $$ begin perform set_config('request.jwt.claim.sub', '', false); end $$;
delete from auth.users where id in ('2c000000-0000-0000-0000-000000000001', '2c000000-0000-0000-0000-000000000002');
