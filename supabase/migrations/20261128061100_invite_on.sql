-- Friend codes with a reward for both (Chimora 1.3.2, Ali): the invite of 20261112230020_friends_more.sql
-- goes live. Its rules stay: one redeem per new account (first invite_days days), the request goes
-- through friend_request (social switch, blocks, rate limit), both take invite_reward once they are
-- friends, the inviter at most invite_max times. A code opened offline waits in the save and is
-- redeemed on the next start online (FriendsMoreMenu.redeem_pending).
update public.feature_flags set enabled = true where key = 'invite';
