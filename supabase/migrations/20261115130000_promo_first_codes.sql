-- First promo code (20261115100000_promo_codes.sql): DISCORD1 for the Discord server, free items only,
-- no use limit, ends 2027-01-31. Re-runnable: an existing code is left as it is.
insert into public.promo_codes (code, reward, max_uses, ends_at, note) values
  ('DISCORD1', '{"strong_tonic": 3, "revival_leaf": 1}', null, timestamptz '2027-02-01 00:00:00+00', 'Discord')
on conflict (code) do nothing;
