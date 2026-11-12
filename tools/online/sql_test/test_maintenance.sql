-- Online 100 point 95: maintenance_info returns the planned maintenance time.
insert into auth.users (id) values ('20000000-0000-0000-0000-0000000000a5') on conflict do nothing;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-0000000000a5', false);
do $$ declare r jsonb; begin
  r := public.maintenance_info();
  assert (r->>'at')::bigint = 0, 'no maintenance by default';
  update public.server_config set value = '1900000000' where key = 'maintenance_at';
  r := public.maintenance_info();
  assert (r->>'at')::bigint = 1900000000, 'planned time returned';
  update public.server_config set value = '0' where key = 'maintenance_at';
end $$;
select set_config('request.jwt.claim.sub', '', false);
