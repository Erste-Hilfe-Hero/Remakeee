# Roadmap: items from the 100-point list that are not built yet

Everything else on the list is built (PRs #9 to #26), apart from the Bond and Online items, which other threads own.

| Item | Status | Why it waits | What unblocks it |
| --- | --- | --- | --- |
| 8. 2v2 battles | Planned for after Act II | The battle model, the AI, the effects and the presenter all assume one active Spirling per side. At 144x256 portrait, four battlers, two Energy bars and targeting do not fit without a new battle layout. Doing it properly means a separate battle mode with its own screen, not a patch on 1v1. | A battle-screen layout for 4 battlers at Era II resolution (Corvane), then a `DoubleBattleModel` that reuses DamageCalc, StatusRules and the effects. |
| 29. Regional variants | Waiting on designs | Each variant is a new Spirling design. | Ali checks the designs against the official dex (AGENTS.md rule). |
| 35. Legendary Spirlings | Waiting on designs | New designs plus story placement in later acts. | Same check by Ali, then Act II/III story. |
| 36. Breeding | Waiting on designs and legal | Needs egg/child forms (new art) and a check that the mechanic is described in our own terms. | Ali's design check; legal thread reviews the mechanic text. |
