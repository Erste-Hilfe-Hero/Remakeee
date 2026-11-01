# Business model (decided 2026-11-01)

Ali asked for every decision to be taken without check-ins, so this is the fair default from the
"100 improvements" list (items 80–86). Change it here first if the plan changes.

## Decision: pay once, own it all

- **Chimora is a premium app: one up-front price on the App Store and Google Play.** Everything in
  the game is included. No in-app purchases, no ads, no loot boxes, no gacha, no energy timers.
- **No pay-to-win**, ever. Nothing that affects battles, bonding or progress is sold.
- **No IAP / billing SDK and no ad SDK in the build.** That keeps AGENTS.md rule 4 intact (no
  network SDKs without Ali's OK), the privacy forms short ("Data not collected") and the
  16 KB page-size check simple.
- **Later Eras (Era II–IV)** ship as free updates to buyers. If they ever become paid, they
  must be a full expansion with clear content, never randomised, and this file gets updated
  first.

## Why not demo + unlock?

The list suggested a free demo up to Rift 2 plus a one-time unlock. That needs a store billing
plugin on both platforms (network SDK, receipts, restore purchases, family sharing edge cases)
and Ali's OK under rule 4. A premium price gets the same fairness with no extra code. If a demo
is wanted later, the cleanest route is a separate free "Chimora Demo" app that ends after the
second Rift, not an in-app unlock.

## Items 80–86 at a glance

| # | Item | Status |
| --- | --- | --- |
| 80 | Fair model | Decided: premium, pay once |
| 81 | No loot boxes / gacha | Rule: never (also legally risky in BE/NL) |
| 82 | Cosmetic shop | Not planned. Outfits are unlocked by playing (jacket colours already exist) |
| 83 | Paid Era expansions | Not planned. Eras come as free updates |
| 84 | Supporter pack | Not planned (would need IAP) |
| 85 | No ads | Rule: no ads |
| 86 | Local prices, family sharing | Store settings: turn on Family Sharing (Apple) and Play Family Library when the app is set up; prices use the store's local price tiers |

## What only Ali can do
- Pick the price tier in App Store Connect and the Play Console.
- Tick Family Sharing / Family Library there.
- Fill the privacy labels as "Data not collected" (true while this file holds).
