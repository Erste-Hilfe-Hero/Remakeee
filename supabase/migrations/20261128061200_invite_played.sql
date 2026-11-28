-- Friend codes (Chimora 1.3.2, security review finding 5): throwaway accounts could fill an inviter's
-- invite_max payouts by redeeming the code and being accepted right away. An invite now pays (both
-- sides) only once the invited account has really played: a save uploaded at least a day after the
-- account was made. saves.saved_at is set by the server (save_put), not by the client. Rewards stay
-- items only (invite_reward), never Riftglass.

create or replace function public._invite_played(u uuid) returns boolean
language sql stable as $$
  select exists (select 1 from public.saves s join public.profiles p on p.id = s.user_id
    where s.user_id = u and s.saved_at >= p.created_at + interval '1 day')
$$;

create or replace function public._invite_due(u uuid) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'self', exists (select 1 from public.invites i where i.invitee = u and not i.invitee_paid
      and public._friends(u, i.inviter) and public._invite_played(u)),
    'others', least(
      (select count(*)::int from public.invites i where i.inviter = u and not i.inviter_paid
        and public._friends(u, i.invitee) and public._invite_played(i.invitee)),
      greatest(0, (public._fm()->>'invite_max')::int
        - (select count(*)::int from public.invites i where i.inviter = u and i.inviter_paid))))
$$;

-- invite_claim marks the paid rows itself; it must skip invitees that have not played yet.
create or replace function public.invite_claim(p_slot int, p_rev int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  u uuid := public._uid();
  d jsonb;
  n int;
  r jsonb;
begin
  if not public._flag_on('invite', 2147483647) then return public._fail('feature_off'); end if;
  d := public._invite_due(u);
  n := (case when (d->>'self')::boolean then 1 else 0 end) + (d->>'others')::int;
  if n <= 0 then return public._fail('nothing'); end if;
  r := public._fm_pay(u, p_slot, p_rev, public._fm()->'invite_reward', n);
  if not (r->>'ok')::boolean then return r; end if;
  if (d->>'self')::boolean then
    update public.invites set invitee_paid = true where invitee = u;
  end if;
  update public.invites set inviter_paid = true where invitee in (select i.invitee from public.invites i
    where i.inviter = u and not i.inviter_paid and public._friends(u, i.invitee) and public._invite_played(i.invitee)
    order by i.created_at limit (d->>'others')::int);
  return r || jsonb_build_object('times', n);
end $$;

revoke all on function public._invite_played(uuid), public._invite_due(uuid) from public, anon, authenticated, chimora_referee;
revoke all on function public.invite_claim(int, int) from public, anon, chimora_referee;
grant execute on function public.invite_claim(int, int) to authenticated;
