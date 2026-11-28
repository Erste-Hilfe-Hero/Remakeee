-- 1.3.2 security review finding 1: moving to a new phone (transfer_claim) deleted the old user and
-- with it every table _move_account did not move, so once-per-account claims (rg_daily,
-- pass_progress, promo codes, awards, invites) reset on every move, and moderation rows
-- (cheat_flags, notices) were lost. Now every table with a foreign key to auth.users follows the
-- account; tools/online/sql_test/test_move_account.sql fails when a new table is not handled here
-- (or in a profiles follow trigger such as _shop_follow_profile).
--
-- The fresh account on the new phone keeps only what was bought: its free Riftglass claims and
-- the free reward deliveries go before the shop rows merge, so a claim taken on a fresh account
-- cannot be carried into the moved one either. Its claim rows are replaced by the old account's.

create or replace function public._move_account(p_old uuid, p_new uuid) returns void
language plpgsql volatile as $$
begin
  delete from public.ledger where user_id = p_new and reason in ('daily', 'pass_track');
  delete from public.deliveries where user_id = p_new and purchase_id is null;
  -- The profiles follow triggers move the shop rows (_shop_follow_profile, _shop_cards_follow).
  update public.profiles set id = p_new where id = p_old;
  update public.saves set user_id = p_new where user_id = p_old;
  delete from public.friendships where a = p_new or b = p_new;
  update public.friendships set a = least(p_new, b), b = greatest(p_new, b), requested_by = case when requested_by = p_old then p_new else requested_by end
    where a = p_old;
  update public.friendships set a = least(a, p_new), b = greatest(a, p_new), requested_by = case when requested_by = p_old then p_new else requested_by end
    where b = p_old;
  delete from public.blocks where blocker = p_new or blocked = p_new;
  update public.blocks set blocker = p_new where blocker = p_old;
  update public.blocks set blocked = p_new where blocked = p_old;
  delete from public.mail where sender = p_new or recipient = p_new;
  update public.mail set sender = p_new where sender = p_old;
  update public.mail set recipient = p_new where recipient = p_old;
  delete from public.community_contrib where user_id = p_new;
  update public.community_contrib set user_id = p_new where user_id = p_old;
  delete from public.weekly_scores where user_id = p_new;
  update public.weekly_scores set user_id = p_new where user_id = p_old;
  update public.reports set reporter = p_new where reporter = p_old;

  -- Once-per-account claims and limits.
  delete from public.rg_daily where user_id = p_new;
  update public.rg_daily set user_id = p_new where user_id = p_old;
  update public.rg_spends set user_id = p_new where user_id = p_old;
  delete from public.pass_progress where user_id = p_new;
  update public.pass_progress set user_id = p_new where user_id = p_old;
  delete from public.daily_gifts where user_id = p_new;
  update public.daily_gifts set user_id = p_new where user_id = p_old;
  delete from public.promo_redemptions where user_id = p_new;
  update public.promo_redemptions set user_id = p_new where user_id = p_old;
  delete from public.action_done where user_id = p_new;
  update public.action_done set user_id = p_new where user_id = p_old;
  delete from public.league_awards where user_id = p_new;
  update public.league_awards set user_id = p_new where user_id = p_old;
  delete from public.event_awards where user_id = p_new;
  update public.event_awards set user_id = p_new where user_id = p_old;
  delete from public.event_scores where user_id = p_new;
  update public.event_scores set user_id = p_new where user_id = p_old;
  delete from public.bund_donations where user_id = p_new;
  update public.bund_donations set user_id = p_new where user_id = p_old;
  delete from public.bund_goal_claims where user_id = p_new;
  update public.bund_goal_claims set user_id = p_new where user_id = p_old;
  -- An invite stays redeemed: the fresh account's own invite goes only if the old one has one.
  delete from public.invites where invitee = p_new and exists (select 1 from public.invites where invitee = p_old);
  update public.invites set invitee = p_new where invitee = p_old;
  update public.invites set inviter = p_new where inviter = p_old;

  -- Friends' extras (pairs).
  delete from public.friend_favorites where user_id = p_new or friend = p_new;
  update public.friend_favorites set user_id = p_new where user_id = p_old;
  update public.friend_favorites set friend = p_new where friend = p_old;
  delete from public.friend_level_claims where user_id = p_new or friend = p_new;
  update public.friend_level_claims set user_id = p_new where user_id = p_old;
  update public.friend_level_claims set friend = p_new where friend = p_old;
  delete from public.pair_task_claims where user_id = p_new or friend = p_new;
  update public.pair_task_claims set user_id = p_new where user_id = p_old;
  update public.pair_task_claims set friend = p_new where friend = p_old;

  -- Moderation follows the account.
  update public.cheat_flags set user_id = p_new where user_id = p_old;
  update public.notices set user_id = p_new where user_id = p_old;
  update public.appeals set user_id = p_new where user_id = p_old;

  -- Battles, league, raids, bunds, tourneys, trades, scores.
  delete from public.transfer_codes where user_id = p_new;
  update public.transfer_codes set user_id = p_new where user_id = p_old;
  update public.battles set user_id = p_new where user_id = p_old;
  update public.rift_runs set user_id = p_new where user_id = p_old;
  update public.save_history set user_id = p_new where user_id = p_old;
  delete from public.league_fair_entries where user_id = p_new;
  update public.league_fair_entries set user_id = p_new where user_id = p_old;
  delete from public.league_open_entries where user_id = p_new;
  update public.league_open_entries set user_id = p_new where user_id = p_old;
  update public.league_matches set user_id = p_new where user_id = p_old;
  update public.league_matches set opponent = p_new where opponent = p_old;
  delete from public.bund_members where user_id = p_new;
  update public.bund_members set user_id = p_new where user_id = p_old;
  delete from public.bund_invites where user_id = p_new;
  update public.bund_invites set user_id = p_new where user_id = p_old;
  update public.bund_invites set by_user = p_new where by_user = p_old;
  delete from public.bund_war_fighters where user_id = p_new;
  update public.bund_war_fighters set user_id = p_new where user_id = p_old;
  update public.bund_war_fights set user_id = p_new where user_id = p_old;
  delete from public.raid_members where user_id = p_new;
  update public.raid_members set user_id = p_new where user_id = p_old;
  update public.raid_attempts set user_id = p_new where user_id = p_old;
  delete from public.raid_queue where user_id = p_new;
  update public.raid_queue set user_id = p_new where user_id = p_old;
  delete from public.live_duels where a = p_new or b = p_new;
  update public.live_duels set a = p_new where a = p_old;
  update public.live_duels set b = p_new where b = p_old;
  update public.tourneys set winner = p_new where winner = p_old;
  delete from public.tourney_players where user_id = p_new;
  update public.tourney_players set user_id = p_new where user_id = p_old;
  delete from public.tourney_fights where user_id = p_new;
  update public.tourney_fights set user_id = p_new where user_id = p_old;
  delete from public.climb_scores where user_id = p_new;
  update public.climb_scores set user_id = p_new where user_id = p_old;
  delete from public.boss_scores where user_id = p_new;
  update public.boss_scores set user_id = p_new where user_id = p_old;
  delete from public.trade_sides where user_id = p_new;
  update public.trade_sides set user_id = p_new where user_id = p_old;
  update public.trade_log set user_id = p_new where user_id = p_old;
  update public.trade_log set partner = p_new where partner = p_old;
  delete from public.spirling_loans where lender = p_new or borrower = p_new;
  update public.spirling_loans set lender = p_new where lender = p_old;
  update public.spirling_loans set borrower = p_new where borrower = p_old;
end $$;

revoke all on function public._move_account(uuid, uuid) from public, anon, authenticated;
