-- Moving to a new phone (20261128070000_move_account_all.sql, 1.3.2 security review finding 1):
-- every table with a foreign key to auth.users is moved by _move_account or a profiles follow
-- trigger, and once-per-account claims stay claimed after the move.

-- Every user column must be set by an "update public.<table> set <column> = ..." in _move_account
-- or in a trigger function on profiles. A new table: add its move to _move_account, or list it
-- here with the reason it does not need one.
do $$
declare
  src text := pg_get_functiondef('public._move_account(uuid, uuid)'::regprocedure) || ';' ||
    coalesce((select string_agg(pg_get_functiondef(t.tgfoid), ';') from pg_trigger t
      where t.tgrelid = 'public.profiles'::regclass and not t.tgisinternal), '');
  missing text;
begin
  select string_agg(f.tbl || '.' || f.col, ', ' order by f.tbl, f.col) into missing
  from (
    select c.conrelid::regclass::text as tbl, a.attname::text as col
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
    where c.contype = 'f' and c.confrelid = 'auth.users'::regclass
      and c.connamespace = 'public'::regnamespace
  ) f
  where f.tbl || '.' || f.col not in (
      'entitlements.user_id',  -- merged by insert in _shop_follow_profile
      'wallets.user_id')       -- rebuilt from the ledger in _shop_follow_profile
    and not exists (
      select 1 from regexp_split_to_table(src, ';') s
      where s ~* ('update\s+public\.' || f.tbl || '\s+set\s')
        and split_part(lower(s), ' where ', 1) ~ ('[\s,(]' || f.col || '\s*=\s'));
  assert missing is null, 'not moved by _move_account: ' || coalesce(missing, '');
end $$;

insert into auth.users (id) values
  ('2c000000-0000-0000-0000-000000000001'), ('2c000000-0000-0000-0000-000000000002'),
  ('2c000000-0000-0000-0000-000000000003')
on conflict do nothing;

-- A claims the day, a pass tier and has an invite and a moderation flag; B (fresh, the new phone)
-- claims its own day first, then takes A over.
do $$
declare
  a uuid := '2c000000-0000-0000-0000-000000000001';
  b uuid := '2c000000-0000-0000-0000-000000000002';
  code text;
  r jsonb;
  bal int;
begin
  perform set_config('request.jwt.claim.sub', a::text, true);
  perform public.hello(1);
  perform public.shop_set_age(1990, 3);
  assert (public.rg_daily_claim()->>'added')::int > 0, 'A daily';
  perform public.pass_points_add('daily_task', 3);
  assert (public.pass_claim(1, 'free')->>'ok')::boolean, 'A pass tier 1';
  perform public._shop_ledger_add(a, 1000, 'store', 'mv-test');
  assert (public.rg_spend('continue', 'mv-battle', 200)->>'ok')::boolean, 'A sink';
  insert into public.invites (invitee, inviter) values (a, '2c000000-0000-0000-0000-000000000003');
  insert into public.cheat_flags (user_id, reason) values (a, 'mv_test');
  bal := public._shop_balance(a);
  code := public.transfer_create()->>'code';

  perform set_config('request.jwt.claim.sub', b::text, true);
  perform public.hello(1);
  perform public.shop_set_age(1990, 3);
  assert (public.rg_daily_claim()->>'added')::int > 0, 'B daily on the fresh account';
  perform public.pass_points_add('daily_task', 3);
  assert (public.pass_claim(1, 'free')->>'ok')::boolean, 'B pass tier 1 on the fresh account';
  assert (public.transfer_claim(code)->>'ok')::boolean, 'move';

  assert public._shop_balance(b) = bal, 'fresh account free claims dropped: ' || public._shop_balance(b) || ' <> ' || bal;
  assert (select count(*) from public.deliveries where user_id = b and purchase_id is null) = 1,
    'only the old account''s pass reward bag is kept';
  r := public.rg_daily_claim();
  assert (r->>'added')::int = 0, 'daily stays claimed after the move: ' || r::text;
  r := public.pass_claim(1, 'free');
  assert r->>'error' = 'claimed', 'pass tier stays claimed after the move: ' || r::text;
  assert (public.pass_state()->>'points')::int = 120, 'pass points moved';
  assert exists (select 1 from public.rg_spends where user_id = b and ref = 'mv-battle'), 'sink steps moved';
  assert exists (select 1 from public.invites where invitee = b), 'invite stays redeemed';
  assert exists (select 1 from public.cheat_flags where user_id = b and reason = 'mv_test'), 'flags follow';
  assert not exists (select 1 from auth.users where id = a), 'old user gone';
end $$;
