-- Live content (docs/LIVE_CONTENT.md): signed data patches (shop, balance, type chart, events,
-- texts, news) the game fetches at start and on resume. Data only, never code. Rows are only
-- ever added: publishing a new version keeps every older one, so going back means publishing
-- the old body again under a higher version.
create table if not exists public.live_content (
  version int primary key check (version > 0),
  body text not null,
  signature text not null,
  published_at timestamptz not null default now()
);
alter table public.live_content enable row level security;
revoke all on public.live_content from public, anon, authenticated;

-- The newest patch. With p_have the game says which version it already has; then only
-- {"version", "unchanged": true} comes back, so most starts transfer a few bytes.
create or replace function public.live_content_get(p_have int default 0) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r jsonb;
begin
  -- Signed in only, like every player function (test_security.sql).
  perform public._uid();
  select case when c.version <= coalesce(p_have, 0)
      then jsonb_build_object('version', c.version, 'unchanged', true)
      else jsonb_build_object('version', c.version, 'body', c.body, 'signature', c.signature) end
    into r
    from public.live_content c order by c.version desc limit 1;
  return coalesce(r, jsonb_build_object('version', 0));
end $$;
revoke all on function public.live_content_get(int) from public, anon;
grant execute on function public.live_content_get(int) to authenticated;

-- Publishing (tools/live/publish.py through .github/workflows/live-content.yml). Only the
-- database owner may call it. The version must be newer than every stored one and match the
-- version inside the body. The server does not check the signature: the game does.
create or replace function public.live_content_publish(p_version int, p_body text, p_signature text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  newest int := coalesce((select max(version) from public.live_content), 0);
  inner_v int;
begin
  if p_version is null or p_version <= newest then
    raise exception 'live_content: version % is not newer than %', p_version, newest;
  end if;
  begin
    inner_v := (p_body::jsonb ->> 'version')::int;
  exception when others then
    raise exception 'live_content: body is not JSON with a version';
  end;
  if inner_v is distinct from p_version then
    raise exception 'live_content: body version % does not match %', inner_v, p_version;
  end if;
  if coalesce(length(p_signature), 0) < 16 then
    raise exception 'live_content: signature missing';
  end if;
  insert into public.live_content (version, body, signature) values (p_version, p_body, p_signature);
  return jsonb_build_object('ok', true, 'version', p_version);
end $$;
revoke all on function public.live_content_publish(int, text, text) from public, anon, authenticated;
