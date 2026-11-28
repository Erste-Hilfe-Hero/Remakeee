-- Spirlog book rewards (Chimora 1.3.2, Ali): the book pays a reward at 25, 50 and 100 % of every
-- kind bonded and at 10, 25 and 50 Gleam kinds bonded. The game gives the items and the title from
-- the save (also offline); the server pays the step's Riftglass once per account, and only when the
-- uploaded save of that slot reached the step (bonded kinds counted against public.game_species).
-- Children's accounts (age band under 13) get no Riftglass, like rg_daily_claim.
-- The steps are those of data/spirlog_rewards.json (tests/unit/test_spirlog_rewards.gd compares);
-- LocalBackend does the same in scripts/shop/LocalRiftglass.gd. Re-runnable.

insert into public.server_config (key, value) values
  ('spirlog_rewards', '{"steps": [{"id": "bonded_25", "kind": "bonded", "pct": 25, "riftglass": 100}, {"id": "bonded_50", "kind": "bonded", "pct": 50, "riftglass": 200}, {"id": "bonded_100", "kind": "bonded", "pct": 100, "riftglass": 500}, {"id": "gleam_10", "kind": "gleam", "n": 10, "riftglass": 50}, {"id": "gleam_25", "kind": "gleam", "n": 25, "riftglass": 100}, {"id": "gleam_50", "kind": "gleam", "n": 50, "riftglass": 250}]}')
on conflict (key) do nothing;

create table if not exists public.spirlog_rewards (
  user_id uuid not null references auth.users (id) on delete cascade,
  reward text not null,
  amount int not null,
  at timestamptz not null default now(),
  primary key (user_id, reward)
);
alter table public.spirlog_rewards enable row level security;
revoke all on public.spirlog_rewards from public, anon, authenticated;

-- Kinds of the game in save [p_data] that are bonded ([p_kind] 'bonded') or have a Gleam bonded
-- ('gleam'). Entries that are not objects or name no species of the game do not count.
create or replace function public._spirlog_have(p_data jsonb, p_kind text) returns int
language sql stable as $$
  select count(*)::int
  from jsonb_each(case when jsonb_typeof(p_data->'spirlog') = 'object' then p_data->'spirlog' else '{}'::jsonb end) e
  join public.game_species g on g.name = e.key
  where jsonb_typeof(e.value) = 'object'
    and e.value->>(case when p_kind = 'gleam' then 'gleam_bonded' else 'bonded' end) = 'true'
$$;

-- True when save [p_data] reached step [p_step]: "pct" percent of every kind bonded (rounded up,
-- have * 100 >= pct * total) or "n" Gleam kinds bonded.
create or replace function public._spirlog_reached(p_data jsonb, p_step jsonb) returns boolean
language sql stable as $$
  select case when p_step->>'kind' = 'gleam'
    then public._spirlog_have(p_data, 'gleam') >= (p_step->>'n')::int
    else (select count(*) from public.game_species) > 0
      and public._spirlog_have(p_data, 'bonded') * 100 >= (p_step->>'pct')::int * (select count(*) from public.game_species)
  end
$$;

create or replace function public.spirlog_reward_claim(p_slot int, p_id text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  s jsonb;
  d jsonb;
  band int;
  n int;
  bal int;
begin
  select x into s from jsonb_array_elements(public._config('spirlog_rewards', '{}'::jsonb)->'steps') x
    where x->>'id' = p_id limit 1;
  if s is null then return public._fail('unknown_reward'); end if;
  band := public._shop_band_of(u);
  if band is not null and band < 13 then return public._fail('age'); end if;
  if exists (select 1 from public.spirlog_rewards where user_id = u and reward = p_id) then
    return public._fail('already');
  end if;
  select data into d from public.saves where user_id = u and slot = p_slot;
  if d is null then return public._fail('no_save'); end if;
  if not public._spirlog_reached(d, s) then return public._fail('not_reached'); end if;
  n := greatest(0, coalesce((s->>'riftglass')::int, 0));
  insert into public.spirlog_rewards (user_id, reward, amount) values (u, p_id, n) on conflict do nothing;
  if not found then return public._fail('already'); end if;
  bal := public._shop_ledger_add(u, n, 'spirlog', p_id);
  return jsonb_build_object('ok', true, 'added', n, 'balance', bal);
end $$;

revoke all on function public._spirlog_have(jsonb, text), public._spirlog_reached(jsonb, jsonb)
  from public, anon, authenticated;
revoke all on function public.spirlog_reward_claim(int, text) from public, anon;
grant execute on function public.spirlog_reward_claim(int, text) to authenticated;
