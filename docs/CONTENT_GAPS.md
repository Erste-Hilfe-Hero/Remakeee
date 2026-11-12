# Content gaps: arts, learnsets, items, gifts

Owner question (2026-11-12): "guck nach was uns noch fehlt ob mehr attacken und alles andere".
This page counts what the battle content holds, sets a target per category and records what the
art-set PR filled and what is still open. Numbers come from `python3 tools/balance/content_gaps.py`
(observations only); rerun it after any data change.

Reference point: a comparable genre game at its fifth generation has several hundred moves, well
over a hundred passive abilities and a few hundred items.

## Before and after

| Category | Before | After | Target |
| --- | --- | --- | --- |
| Arts (moves) | 190 | 402 | 400 now, 500 when Era II/IV/V kinds land |
| Physical / focus / status | 80 / 58 / 52 | 143 / 140 / 119 | roughly a third each |
| Elements with a full ladder (weak, mid, strong in both physical and focus, 4+ status arts) | 2 of 16 | 16 of 16 | 16 of 16 |
| Thinnest element | Ink, Echo, Rust, Mask: 3 arts each | Rust, Mask: 16 each (+11 each from the open Vellmarch PR) | 25 each |
| Arts with an era tag | 0 | 402 (I 244, II 30, III 62, IV 48, V 18) | all |
| Arts nobody can learn | 41 | 0 | 0 |
| Arts with English and German name and line | names EN only | 402 (`tools/i18n/de_moves.py`) | all |
| Spirlings with fewer than 4 arts by Ring 30 | 9 | 0 | 0 |
| Spirlings with fewer than 4 good arts at Ring 20 / 30 / 40 / 60 | 47 / 10 / 2 / 0 | 14 / 2 / 0 / 0 | the 14 are final forms met above Ring 20 |
| Spirlings that learn nothing new after Ring 44 | 344 of 357 | 1 of 357 | 0 |
| Items | 114 | 199 | 250 |
| Single-status cures | 3 of 6 (Root, Jolt, Daze missing) | 6 of 6 | 6 of 6 |
| Element keepsakes | 8 elements, shop (Riftglass) only | 16 elements for coins (1.1x) plus the 8 shop prisms (1.2x) | 16 |
| Teaching items (Echo Crystals, Scripts) | 26 | 92 | one per teach-only art |
| Passive abilities (gifts) | 8 traits + 9 hidden gifts | unchanged | 100+ (see Not done) |

"Good art": a damage art of power 40+ and accuracy 0.8+, or a status art (at most two count).

## Art roles

| Role | Before | After | Target |
| --- | --- | --- | --- |
| Priority +1 | 7 | 11 | 12 |
| Priority -1 | 1 | 1 | 3 |
| Multi-hit | 0 | 0 | 10 (needs an engine change, see Not done) |
| Recoil / Vigor cost | 2 | 7 | 8 |
| Drain (Vigor or Energy) | 4 | 10 | 10 |
| Setup (own stages up, status art) | 16 | 32 | 30 |
| Stage up on hit | 7 | 19 | 15 |
| Foe stages down | 15 | 40 | 30 |
| Field calls | 7 | 7 | one per field; new fields belong to the weather rules work |
| Snares (hazards) | 7 | 14 | 12 |
| Snare / stage clear | 1 | 8 | 6 |
| Switching (hit and swap out, force a swap) | 0 | 0 | 6 (needs an engine change) |
| Healing and cures | 5 | 15 | 15 |
| Inflicts a status | 29 | 55 | 50 |
| Hits all foes | 12 | 27 | 25 |
| Cooldown big hits | 11 | 17 | one per element |
| Bonus vs status | 8 | 21 | 16 |
| Energy play (burn, drain, tax, gain) | 5 | 18 | 15 |

Status arts per condition after: Scorch 8, Soak 7, Root 7, Jolt 6, Daze 24, Drowse 3.
Drowse stays rare on purpose (it skips turns).

## Arts per element after

| Element | All | Physical weak/mid/strong | Focus weak/mid/strong | Status |
| --- | --- | --- | --- | --- |
| Ember | 27 | 3/3/4 | 3/3/4 | 7 |
| Tide | 27 | 2/4/3 | 2/4/4 | 8 |
| Bloom | 27 | 3/5/3 | 2/2/3 | 9 |
| Volt | 27 | 2/4/3 | 3/3/3 | 9 |
| Stone | 28 | 4/5/5 | 2/2/3 | 7 |
| Gale | 28 | 4/2/4 | 2/4/5 | 7 |
| Lumen | 28 | 2/3/4 | 3/2/5 | 9 |
| Umbra | 28 | 4/3/3 | 2/3/3 | 10 |
| Ink | 25 | 2/2/5 | 1/5/3 | 7 |
| Echo | 25 | 1/2/3 | 2/4/5 | 8 |
| Rust | 16 | 2/1/3 | 1/2/2 | 5 |
| Mask | 16 | 1/2/2 | 2/1/3 | 5 |
| Acid | 25 | 2/4/2 | 2/3/5 | 7 |
| Frost | 25 | 2/4/4 | 2/3/3 | 7 |
| Gilt | 25 | 2/3/4 | 2/4/3 | 7 |
| Zenith | 25 | 2/3/3 | 2/4/4 | 7 |

Weak = power 50 or less, mid = 55 to 80, strong = 85 and up. Before, Stone, Umbra and Bloom had
no weak focus art, Lumen and Umbra one mid physical art, Ink/Echo/Rust/Mask no status art at all.
Every legendary (the 7 ancient kinds) now has its own art at Ring 58 (Tide of Dawn, Hallow Peal,
Last Word, Vane of Morning, Zephyr Verdict, Lurking Mass, Lucent Void).

## Rules the set follows

- Every damage art sits on the curve of `tests/unit/test_move_curve.gd` (power x accuracy /
  (energy + 1) x effect factor between 9 and 18); energy costs were worked out from it.
- Eras: `era` on every art. Era I arts sit on Era I kinds, Era III arts (Acid, Frost and some new
  arts of the old elements) on Quillmarch kinds, Era II arts (Rust, Mask) on Quillmarch kinds as
  coverage. Era IV (Gilt, Zenith) and Era V arts have no kinds of their era yet, so they come from
  teachers: one Echo Crystal per art, sold in Halcyra (Brightledge, Gildcrest, Paleshore, Era IV)
  and Quivermoor (Era V). Later-era crystals carry `for_elements` (a Gilt crystal also teaches
  Lumen, Stone and Ember kinds; Zenith: Gale, Lumen, Volt; Rust: Stone, Volt, Acid; Mask: Umbra,
  Ink, Echo), checked in `GameState.can_learn_echo`.
- Learnsets: at most 14 arts per kind, one cooldown art and one snare per kind (existing tests).
  Each line gets the same three late arts at Rings 46, 52 and 58 (a status art, a strong hit of
  its main element in its better stat, a hit of its second element). Opening arts that bring a
  kind to 4 by Ring 30 go first in their list, so the newest four (wild kits, type_sim) stay as
  they were: `type_sim.py --strict` gives the same table as before.
- Effects reuse the existing handlers. Four new ones, with GUT tests in
  `tests/unit/test_move_content.gd`: `energy_gain` (user gains Energy), `stage_reset` (all stages
  on both sides back to 0), `cure_team` (user's whole team loses its status), `self_cost` (user
  pays a share of its Vigor, never the last point). BattleAI scores all four.
- Items: Pruning Shears (Root), Grounding Rod (Jolt), Smelling Salts (Daze) in every general mart;
  coin element Charms: the 8 Era I ones at Edge Camp, Ink/Echo at the Thornridge crystal stall,
  Rust/Mask in Vellmarch, Acid/Frost in Quillmarch (Burin Landing), Gilt/Zenith in
  Gildcrest.

## Not done (owned elsewhere or needs a decision)

- Passive abilities: the game has 8 traits and 9 hidden gifts against 100+ in the reference. Not
  built here; gifts and other new mechanics belong to the erafeel-func work.
- Multi-hit and switching arts: both need a change in BattleModel's damage loop and swap flow
  (new mechanics, erafeel-func). The data keys `hits` and `switch` are counted by the gap script
  once they exist.
- New fields or weather for Stone, Gale and the later elements: weather rules belong to
  erafeel-func. The set has no new field arts.
- Art descriptions are data (`desc`, `MoveData.description`, German in `de_moves.py`) but no
  screen shows them yet; the battle info card (`CommandMenu.move_info`) belongs to the battle
  presentation work (erafeel-battle). German art names show where a screen calls `Loc.t` on the
  art name; several menus still print `move_name` raw.
- Rust and Mask stay at 16 arts here because the open Vellmarch PR adds 11 of each with its 70
  kinds. Era II, IV and V kinds should then get the later-era arts in their learnsets (the Echo
  Crystals stay as teachers).
- 14 final forms still know fewer than 4 good arts at Ring 20; they are met above Ring 20.
- Items: 199 of a 250 target. Open ideas: a team cure item, held items for the status set
  (a keepsake that blocks one status).
