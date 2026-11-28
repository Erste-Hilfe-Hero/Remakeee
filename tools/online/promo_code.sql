-- Makes a promo code (20261115100000_promo_codes.sql). Run as the database owner, for example:
--   psql -v code=DISCORD1 -v reward='{"strong_tonic": 3}' -v max_uses=500 -v days=30 -v note='Discord launch' -f tools/online/promo_code.sql
-- code: exactly 8 letters/digits (upper case). reward: bag items {"item_id": count}, free items only,
-- never paid store products (App Store 3.1.1;
-- promo_redeem refuses rg_* ids and items a shop offer grants, 20261121120000_promo_free_only.sql). max_uses: 0 = no limit. days: 0 = no end.
insert into public.promo_codes (code, reward, max_uses, ends_at, note)
values (upper(:'code'), :'reward'::jsonb, nullif(:max_uses, 0), case when :days > 0 then now() + make_interval(days => :days) end, :'note')
on conflict (code) do update set reward = excluded.reward, max_uses = excluded.max_uses, ends_at = excluded.ends_at,
  note = excluded.note, active = true
returning code, reward, max_uses, uses, ends_at;
-- Switch a code off: update public.promo_codes set active = false where code = 'DISCORD1';
-- Who redeemed how often: select code, uses, max_uses, ends_at, note from public.promo_codes order by created_at desc;
