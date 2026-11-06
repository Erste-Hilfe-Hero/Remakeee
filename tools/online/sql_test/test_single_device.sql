-- Plan area 7, item 3010: one device at a time. Phone A claims, phone B claims later, phone A's
-- saves are refused and its heartbeat says so; requests without the header are not checked.
\o /dev/null
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000aa') on conflict do nothing;
create temp table sd (k text primary key, v jsonb);
grant all on sd to authenticated;
set role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000aa', false);
insert into sd values ('a', public.session_claim(null));
select set_config('request.headers', json_build_object('x-chimora-session', (select v->>'token' from sd where k = 'a'))::text, false);
insert into sd values ('a_again', public.session_claim((select v->>'token' from sd where k = 'a')));
insert into sd values ('a_put', public.save_put(1, '{"schema": 1, "play_time": 10, "money": 3000}', 'A', 0, false, null));
-- Phone B signs in (a fresh start sends no token).
select set_config('request.headers', '{}', false);
insert into sd values ('b', public.session_claim(''));
-- Phone A again.
select set_config('request.headers', json_build_object('x-chimora-session', (select v->>'token' from sd where k = 'a'))::text, false);
insert into sd values ('a_beat', public.presence('Ashdown'));
insert into sd values ('a_claim', public.session_claim((select v->>'token' from sd where k = 'a')));
do $$
begin
  perform public.save_put(1, '{"schema": 1, "play_time": 20, "money": 3000}', 'A2', 1, false, null);
  insert into sd values ('a_put2', '"stored"');
exception when others then
  insert into sd values ('a_put2', to_jsonb(sqlerrm));
end $$;
-- Phone B saves fine.
select set_config('request.headers', json_build_object('x-chimora-session', (select v->>'token' from sd where k = 'b'))::text, false);
insert into sd values ('b_beat', public.presence('Ashdown'));
insert into sd values ('b_put', public.save_put(1, '{"schema": 1, "play_time": 20, "money": 3000}', 'B', 1, false, null));
-- An old build without the header.
select set_config('request.headers', '', false);
insert into sd values ('old_put', public.save_put(1, '{"schema": 1, "play_time": 30, "money": 3000}', 'old', 2, false, null));
reset role;
select set_config('request.headers', '', false);
\o
do $$
declare a text := (select v->>'token' from sd where k = 'a');
begin
  assert length(a) = 32, 'a token: ' || coalesce(a, 'null');
  assert (select v->>'token' from sd where k = 'a_again') = a, 'the same device keeps its token';
  assert (select (v->>'ok')::boolean from sd where k = 'a_put'), 'the newest device saves';
  assert (select v->>'token' from sd where k = 'b') <> a, 'a new device gets a new token';
  assert (select (v->>'other_device')::boolean from sd where k = 'a_beat'), 'the old device hears it';
  assert (select v->>'error' from sd where k = 'a_claim') = 'other_device', 'the old device cannot take it back by itself';
  assert (select v #>> '{}' from sd where k = 'a_put2') = 'other_device', 'the old device cannot save';
  assert not (select (v->>'other_device')::boolean from sd where k = 'b_beat'), 'the new device is fine';
  assert (select (v->>'ok')::boolean from sd where k = 'b_put'), 'the new device saves';
  assert (select (v->>'ok')::boolean from sd where k = 'old_put'), 'no header: not checked';
  assert (select session_token from public.profiles where id = '20000000-0000-0000-0000-0000000000aa')
    = (select v->>'token' from sd where k = 'b'), 'the newest token is stored';
end $$;
