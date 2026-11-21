-- Live content (20261111000001_live_content.sql): insert-only publishing, newest first.
reset role;
delete from public.live_content where version >= 900000;
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000c7') on conflict do nothing;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000c7', false);
do $$
declare r jsonb; ok boolean;
begin
  perform public.live_content_publish(900001, '{"version": 900001}', 'c2lnbmF0dXJlLWZvci10ZXN0cw==');
  r := public.live_content_get(0);
  assert (r->>'version')::int = 900001, 'newest version';
  assert r->>'body' = '{"version": 900001}', 'body as published';
  assert public.live_content_get(900001) ? 'unchanged', 'up to date: no body';
  ok := false;
  begin
    perform public.live_content_publish(900001, '{"version": 900001}', 'c2lnbmF0dXJlLWZvci10ZXN0cw==');
  exception when others then ok := true;
  end;
  assert ok, 'same version twice is refused';
  ok := false;
  begin
    perform public.live_content_publish(900002, '{"version": 5}', 'c2lnbmF0dXJlLWZvci10ZXN0cw==');
  exception when others then ok := true;
  end;
  assert ok, 'body version must match';
end $$;
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000c7') on conflict do nothing;
set role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000c7', false);
do $$
declare ok boolean := false;
begin
  assert (public.live_content_get(0)->>'version')::int = 900001, 'players can read';
  begin
    perform public.live_content_publish(900003, '{"version": 900003}', 'c2lnbmF0dXJlLWZvci10ZXN0cw==');
  exception when insufficient_privilege then ok := true;
  end;
  assert ok, 'players cannot publish';
end $$;
reset role;
delete from public.live_content where version >= 900000;
delete from auth.users where id = '20000000-0000-0000-0000-0000000000c7';
