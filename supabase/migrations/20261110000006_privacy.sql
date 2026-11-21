-- Plan area 7, items 2972, 2973, 2991: the player's own data as one JSON file (GDPR Art. 15 and
-- 20), and delete_account leaves no row with the account id behind.
--
-- Both read the system catalog: every table in the public schema with a uuid column is an
-- account table (profiles.id, saves.user_id, friendships.a/b, mail.sender/recipient, …). New
-- tables from later features are covered without touching these functions; the SQL test
-- test_privacy.sql checks it.

insert into public.server_config (key, value) values ('data_export_limit', '5')
on conflict (key) do nothing;

-- (table, uuid columns) of every public account table.
create or replace function public._account_tables() returns table (tbl text, cols text[])
language sql stable security definer set search_path = public as $$
  select c.table_name::text, array_agg(c.column_name::text order by c.ordinal_position)
  from information_schema.columns c
  join information_schema.tables t on t.table_schema = c.table_schema and t.table_name = c.table_name
  where c.table_schema = 'public' and c.data_type = 'uuid' and t.table_type = 'BASE TABLE'
  group by c.table_name
  order by c.table_name
$$;

-- One row for the export: the player's own id reads "you", other players' ids "another player",
-- so the export never names anyone else (for example who reported the account). Secrets the
-- server keeps (hashes) are left out.
create or replace function public._export_row(p_row jsonb, p_cols text[], p_user uuid) returns jsonb
language plpgsql immutable as $$
declare
  c text;
  k text;
  out jsonb := p_row;
begin
  foreach c in array p_cols loop
    if out ? c and jsonb_typeof(out->c) = 'string' then
      out := jsonb_set(out, array[c], to_jsonb(case when out->>c = p_user::text then 'you' else 'another player' end));
    end if;
  end loop;
  for k in select key from jsonb_each(p_row) where key like '%hash%' or key like '%secret%' or key like '%token%' loop
    out := out - k;
  end loop;
  return out;
end $$;

create or replace function public.data_export() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  r record;
  rows jsonb;
  cond text;
  out jsonb := '{}'::jsonb;
begin
  perform public._ensure_profile(u);
  if not public._rate_ok(u, 'data_export', public._config_int('data_export_limit', 5)) then
    return public._fail('slow_down');
  end if;
  for r in select * from public._account_tables() loop
    select string_agg(format('x.%I = $1', c), ' or ') into cond from unnest(r.cols) c;
    execute format('select coalesce(jsonb_agg(public._export_row(to_jsonb(x), $2, $1)), ''[]''::jsonb) from public.%I x where %s',
      r.tbl, cond) into rows using u, r.cols;
    out := out || jsonb_build_object(r.tbl, rows);
  end loop;
  return jsonb_build_object('ok', true, 'exported_at', extract(epoch from now())::bigint, 'format', 1, 'tables', out);
end $$;

-- Deletes the account and then every row anywhere that still carries its id (rows of tables
-- without a cascading key, such as mail it sent or reports it made).
create or replace function public.delete_account() returns jsonb
language plpgsql volatile security definer set search_path = public, auth as $$
declare
  u uuid := public._uid();
  r record;
  c text;
  pass int;
  left_over boolean;
begin
  delete from auth.users where id = u;
  for pass in 1..3 loop
    left_over := false;
    for r in select * from public._account_tables() loop
      foreach c in array r.cols loop
        begin
          execute format('delete from public.%I where %I = $1', r.tbl, c) using u;
        exception when foreign_key_violation then
          left_over := true;
        end;
      end loop;
    end loop;
    exit when not left_over;
  end loop;
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public._account_tables(), public._export_row(jsonb, text[], uuid) from public, anon, authenticated;
revoke all on function public.data_export(), public.delete_account() from public, anon;
grant execute on function public.data_export(), public.delete_account() to authenticated;

-- Retention (privacy policy 3.6): battle recordings and league matches 30 days, refused-save notes
-- 6 months, league standings until the end of the following season. hello runs it now and then,
-- so no extra timer is needed.
create or replace function public._privacy_cleanup() returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  delete from public.league_matches where created_at < now() - interval '30 days';
  begin
    delete from public.battles where created_at < now() - interval '30 days';
  exception when foreign_key_violation then
    null;
  end;
  delete from public.cheat_flags where at < now() - interval '180 days';
  delete from public.league_fair_entries where season in (select id from public.league_seasons
    where ends_at < now() - make_interval(days => public._config_int('league_season_days', 42)));
  delete from public.league_open_entries where season in (select id from public.league_seasons
    where ends_at < now() - make_interval(days => public._config_int('league_season_days', 42)));
end $$;

create or replace function public.hello(p_version int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  p public.profiles;
  min_v int := coalesce((public._config('min_version', '1'))::text::int, 1);
begin
  p := public._ensure_profile(u);
  update public.profiles set last_seen = now() where id = u;
  if random() < 0.01 then
    perform public._privacy_cleanup();
  end if;
  return jsonb_build_object(
    'profile', public._profile_json(p),
    'server_time', extract(epoch from now())::bigint,
    'update_required', p_version < min_v,
    'motd', public._config('motd', '""'),
    'online_now', (select count(*) from public.profiles where last_seen > now() - interval '5 minutes'),
    'flags', coalesce((select jsonb_agg(f.key order by f.key) from public.feature_flags f
      where f.enabled and p_version >= f.min_version), '[]'::jsonb));
end $$;

revoke all on function public._privacy_cleanup() from public, anon, authenticated;
revoke all on function public.hello(int) from public, anon;
grant execute on function public.hello(int) to authenticated;
