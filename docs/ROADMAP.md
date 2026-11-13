# Roadmap: items from the 100-point list that are not built yet

Everything else on the list is built (PRs #9 to #26), apart from the Bond and Online items, which other threads own.

Item 8 (battles with several Spirlings per side) is built as story set pieces: N vs M up to 4 vs 4
with targeting and sweeps, tag battles with Kestra, Rift bosses and a wild horde. They use their own
formation layout (half-size sprites in two ranks), so the 144x256 screen still fits. Random wild
encounters and ordinary Wayfarers stay 1v1.

| Item | Status | Why it waits | What unblocks it |
| --- | --- | --- | --- |
| 29. Regional variants | Waiting on designs | Each variant is a new Spirling design. | Ali checks the designs against the official dex (AGENTS.md rule). |
| 35. Legendary Spirlings | Waiting on designs | New designs plus story placement in later acts. | Same check by Ali, then Act II/III story. |
| 36. Breeding | Waiting on designs and legal | Needs egg/child forms (new art) and a check that the mechanic is described in our own terms. | Ali's design check; legal thread reviews the mechanic text. |

## Kampfsystem (battle plan)

The battle backlog has its own 1000-point plan: `docs/KAMPF_PLAN_1000.md`, written by
`tools/plan/plan_1000.py` (ticks are set there; CI checks the md). How the battle code is built,
its accessibility and its legal guardrails: `docs/KAMPF_TECHNIK.md`. Still open from the technique
section: community data packs (data only, signed like live content), a battle editor for
developers, and measured memory and speed budgets on older phones.
