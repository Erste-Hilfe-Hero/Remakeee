-- Promo codes (Werbecodes): the team hands out a code (Discord, social posts, events), a player
-- enters it under Settings, Account, "Redeem a promo code..." and gets its items in the bag of the
-- current journey. Each account redeems a code once; a code can have a use limit and a time window.
-- Rewards are free bag items only, never paid store products (App Store guideline 3.1.1).
-- Codes are made with tools/online/promo_code.sql. LocalBackend does the same
-- (scripts/online/LocalPromo.gd), tests: tools/online/sql_test/test_promo_codes.sql and
-- tests/unit/test_promo_codes.gd. Re-runnable.

insert into public.feature_flags (key, enabled, min_version, note) values
  ('promo', true, 1, 'Werbecodes einlösen')
on conflict (key) do nothing;

create table if not exists public.promo_codes (
  code text primary key check (code ~ '^[A-Z0-9]{8}$'),
  -- {"item_id": count, ...}, each count 1-999
  reward jsonb not null check (jsonb_typeof(reward) = 'object' and reward <> '{}'::jsonb),
  max_uses int check (max_uses is null or max_uses > 0),
  uses int not null default 0,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  active boolean not null default true,
  note text not null default '',
  created_at timestamptz not null default now()
);
create table if not exists public.promo_redemptions (
  code text not null references public.promo_codes (code) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  at timestamptz not null default now(),
  primary key (code, user_id)
);
create index if not exists promo_redemptions_user on public.promo_redemptions (user_id);
alter table public.promo_codes enable row level security;
alter table public.promo_redemptions enable row level security;

-- Letters and digits only, upper case ("disc-ord1" = "DISCORD1").
create or replace function public._promo_norm(p_code text) returns text
language sql immutable as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'))
$$;

create or replace function public.promo_redeem(p_code text, p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  c text := public._promo_norm(p_code);
  p public.promo_codes;
  k text;
  v jsonb;
  r jsonb;
begin
  if not public._flag_on('promo', 2147483647) then return public._fail('feature_off'); end if;
  -- Against guessing: 10 tries an hour.
  if not public._rate_ok(u, 'promo', 10) then return public._fail('slow_down'); end if;
  select * into p from public.promo_codes where code = c for update;
  if not found or not p.active then return public._fail('no_such_code'); end if;
  if now() < p.starts_at then return public._fail('no_such_code'); end if;
  if p.ends_at is not null and now() >= p.ends_at then return public._fail('code_expired'); end if;
  if exists (select 1 from public.promo_redemptions where code = c and user_id = u) then
    return public._fail('code_used');
  end if;
  if p.max_uses is not null and p.uses >= p.max_uses then return public._fail('code_used_up'); end if;
  for k, v in select * from jsonb_each(p.reward) loop
    if jsonb_typeof(v) <> 'number' or (v #>> '{}')::numeric not between 1 and 999 then
      return public._fail('no_such_code');
    end if;
  end loop;
  r := public._trade_save(u, p_slot, p_rev, p.reward, '{}'::text[], '[]'::jsonb);
  if not (r->>'ok')::boolean then return r; end if;
  insert into public.promo_redemptions (code, user_id) values (c, u);
  update public.promo_codes set uses = uses + 1 where code = c;
  return jsonb_build_object('ok', true, 'rev', (r->>'rev')::int, 'bag', p.reward);
end $$;

revoke all on function public._promo_norm(text) from public, anon, authenticated, chimora_referee;
revoke all on function public.promo_redeem(text, int, int) from public, anon, chimora_referee;
grant execute on function public.promo_redeem(text, int, int) to authenticated;
