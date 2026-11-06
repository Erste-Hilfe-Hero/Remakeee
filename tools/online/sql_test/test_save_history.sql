-- Plan area 7, item 3009: the last 5 versions of a slot, and bringing one back.
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000a9') on conflict do nothing;
insert into public.saves (user_id, slot, rev, data, summary) values
  ('20000000-0000-0000-0000-0000000000a9', 1, 1, '{"play_time": 60, "n": 1}', 'Ashdown  0:01')
on conflict (user_id, slot) do update set rev = 1, data = excluded.data;
do $$
begin
  for i in 2..8 loop
    update public.saves set data = jsonb_build_object('play_time', 60 * i, 'n', i), rev = i, summary = 'Ashdown  0:0' || i
    where user_id = '20000000-0000-0000-0000-0000000000a9' and slot = 1;
  end loop;
  -- The same data again is no new version.
  update public.saves set saved_at = now() where user_id = '20000000-0000-0000-0000-0000000000a9' and slot = 1;
end $$;
create temp table sh (k text primary key, v jsonb);
grant all on sh to authenticated;
set role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000a9', false);
insert into sh values ('list', public.save_history_list(1));
insert into sh values ('restore', public.save_restore(1, (select (v->'saves'->2->>'id')::bigint from sh where k = 'list')));
insert into sh values ('list2', public.save_history_list(1));
insert into sh values ('other', public.save_restore(2, (select (v->'saves'->0->>'id')::bigint from sh where k = 'list')));
reset role;
do $$
declare l jsonb := (select v->'saves' from sh where k = 'list');
begin
  assert jsonb_array_length(l) = 5, 'the last 5 versions: ' || jsonb_array_length(l);
  assert (l->0->>'rev')::int = 7 and (l->4->>'rev')::int = 3, 'newest first';
  assert (l->0->>'play_time')::float8 = 420, 'play time shown';
  assert ((select v from sh where k = 'restore')->>'rev')::int = 9, 'restore makes a new revision';
  assert (select data->>'n' from public.saves where user_id = '20000000-0000-0000-0000-0000000000a9' and slot = 1) = '5',
    'version 5 is back';
  assert ((select v from sh where k = 'list2')->'saves'->0->>'rev')::int = 8, 'the replaced version can come back too';
  assert (select v->>'error' from sh where k = 'other') = 'no_such_save', 'only the same slot';
end $$;
