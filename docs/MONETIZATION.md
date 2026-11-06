# Business model (changed 2026-11-06)

Ali decided on 6 Nov 2026: **Chimora is free.** An in-app shop comes later and is planned in the
5000-point plan. The earlier decision (premium, pay once, 1 Nov 2026) is replaced. Change it here
first if the plan changes again.

## Decision: free to play, fair shop later

- **Free download on the App Store and Google Play.** The launch build has no shop, no IAP or
  billing SDK and no ads, so the privacy forms stay "Data not collected".
- **No pay-to-win**, ever. Nothing that affects battles, bonding or progress is sold.
- **No loot boxes or gacha**, no paid random rewards (legally risky in BE/NL, and unfair).
- **No ads.**
- **The shop** (planned in the 5000-point plan) needs a billing plugin on both platforms. When it
  ships: update this file, the store texts in `store/`, the "in-app purchases" answers in
  `docs/legal/STORE_COMPLIANCE.md`, the privacy texts (purchase data) and the support FAQ.
- **Later Eras (Era II-IV)** come as free updates.

## Items 80–86 at a glance

| # | Item | Status |
| --- | --- | --- |
| 80 | Fair model | Decided 2026-11-06: free, shop later, no pay-to-win |
| 81 | No loot boxes / gacha | Rule: never (also legally risky in BE/NL) |
| 82 | Cosmetic shop | Planned in the 5000-point plan (in-app shop) |
| 83 | Paid Era expansions | Not planned. Eras come as free updates |
| 84 | Supporter pack | Possible with the shop |
| 85 | No ads | Rule: no ads |
| 86 | Local prices, family sharing | Store settings; shop prices will use the store's local price tiers |

## What only Ali can do
- Set the app to free in App Store Connect and the Play Console.
- For the shop later: Paid Apps agreement (Apple) and payments profile (Google), tax and bank data.
- Fill the privacy labels as "Data not collected" (true while this file holds).
