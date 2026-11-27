# Memory on 2 GB devices (200 list item 182)

Measured 2026-11-25 with `tools/c200_tech_shots.gd` (Godot 4.7.2 debug engine, xvfb, OpenGL 3,
GL Compatibility renderer), fresh user folder, a save on disk. Path per cycle: title (with the
save card) -> overworld -> pause menu -> bag -> wild battle, once in Era I (Brindlewick, 144x256)
and once in Era V (Driftwick, 270x480 with the depth layer). Three cycles, pictures only in the
first.

    XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 1000x1000x24" godot --path . \
      --rendering-driver opengl3 --resolution 440x956 -s res://tools/c200_tech_shots.gd -- out phone 3

Monitors: `Performance.MEMORY_STATIC` (CPU heap), `MEMORY_STATIC_MAX` (its peak),
`RENDER_TEXTURE_MEM_USED`, `RENDER_VIDEO_MEM_USED`, object/node counts.

## Result

| What | Value |
|---|---|
| Static memory while playing (all stages, all cycles) | 147 - 164 MB |
| Static memory peak (whole run) | 370 MB, reached during startup, before the title |
| Texture memory, highest (Era V battle) | 6.7 MB phone, 9.1 MB on a 2560x1600 tablet |
| Video memory, highest | 19 MB phone, 31 MB on a 2732x2048 tablet |
| Orphan nodes after every stage | 0 |
| Growth from cycle 2 to cycle 3 (same stage) | +0.2 MB static, objects equal (4063 / 4062 after freeing Era I) |

Target "well under ~600 MB": met. The 370 MB peak is the highest point; play itself stays near
160 MB plus about 20-30 MB of video memory.

## Where the startup peak comes from

Bisected by switching autoloads off one by one: the empty engine peaks at 25 MB; the peak grows
when the autoloads Juice, Haptics, Ticker, Online and Billing load (46 -> 202 -> 239 -> 254 ->
289 -> 363 MB) while the static memory that stays is only 126 MB. These autoloads pull in the
class graph of the whole game (typed references to GameState, Database, the battle model, the
online code), so the peak is the GDScript compiler's working memory while about 1000 scripts are
parsed and checked. It is released right after (static falls to ~125 MB). In an exported build
the scripts ship pre-tokenized, so the parse part is smaller; the debug engine also counts its
own debug data. Not a leak and not a cache; making it smaller would mean breaking up the autoload
dependency graph, which is out of scope for this item.

## Leaks and caches checked

- Three full cycles: object, resource and node counts return to the same numbers after each
  cycle; the small rise from cycle 1 to 2 is the one-time caches filling (first Era V textures,
  cries, menu art), then flat.
- Static caches read through: ElementIcons, SpirlogMarks, EraMenuArt, KeepsakeIcons, Badges,
  MiniSprite, SpirlingSprite silhouettes, BattleAnim, Lexicon, BattleGoals, Transit, Cry,
  Dialogue, MusicDirector, Sound. All are keyed by a fixed set (species, element, item, era,
  track, file) and so bounded by the game's content. PatternTranslation keeps translated
  composed lines (e.g. "Kindlop grew ring 9!") and is emptied when a language loads; it only
  holds short strings, a few hundred KB even after hours. No clear leak or waste was found, so
  no code was changed for this item.

## Raw lines (phone, 440x956)

    mem boot: static 143.2 MB, static peak 370.1 MB, texture 0.4 MB, video 6.6 MB, objects 3383, resources 630, nodes 64, orphan nodes 0
    mem c1_era1_title: static 147.6 MB, static peak 370.1 MB, texture 1.4 MB, video 9.5 MB, objects 3651, resources 636, nodes 152, orphan nodes 0
    mem c1_era1_overworld: static 152.0 MB, static peak 370.1 MB, texture 2.1 MB, video 12.3 MB, objects 4229, resources 645, nodes 232, orphan nodes 0
    mem c1_era1_bag: static 153.1 MB, static peak 370.1 MB, texture 2.1 MB, video 12.3 MB, objects 4473, resources 645, nodes 287, orphan nodes 0
    mem c1_era1_battle: static 156.7 MB, static peak 370.1 MB, texture 2.3 MB, video 14.5 MB, objects 4601, resources 653, nodes 345, orphan nodes 0
    mem c1_era1_freed: static 152.9 MB, static peak 370.1 MB, texture 2.3 MB, video 14.5 MB, objects 3965, resources 649, nodes 64, orphan nodes 0
    mem c1_era5_title: static 158.1 MB, static peak 370.1 MB, texture 2.3 MB, video 14.6 MB, objects 3757, resources 653, nodes 152, orphan nodes 0
    mem c1_era5_overworld: static 161.1 MB, static peak 370.1 MB, texture 5.9 MB, video 18.2 MB, objects 4304, resources 658, nodes 211, orphan nodes 0
    mem c1_era5_bag: static 157.7 MB, static peak 370.1 MB, texture 5.9 MB, video 18.2 MB, objects 4453, resources 658, nodes 255, orphan nodes 0
    mem c1_era5_battle: static 163.6 MB, static peak 370.1 MB, texture 6.7 MB, video 19.0 MB, objects 4742, resources 666, nodes 330, orphan nodes 0
    mem c1_era5_freed: static 153.9 MB, static peak 370.1 MB, texture 4.5 MB, video 16.7 MB, objects 3610, resources 659, nodes 65, orphan nodes 0
    mem c2_era1_title: static 155.0 MB, static peak 370.1 MB, texture 3.7 MB, video 16.0 MB, objects 3869, resources 663, nodes 153, orphan nodes 0
    mem c2_era1_overworld: static 155.7 MB, static peak 370.1 MB, texture 4.5 MB, video 16.7 MB, objects 4405, resources 666, nodes 233, orphan nodes 0
    mem c2_era1_bag: static 156.8 MB, static peak 370.1 MB, texture 4.5 MB, video 16.8 MB, objects 4645, resources 666, nodes 288, orphan nodes 0
    mem c2_era1_battle: static 157.2 MB, static peak 370.1 MB, texture 4.6 MB, video 16.8 MB, objects 4735, resources 668, nodes 346, orphan nodes 0
    mem c2_era1_freed: static 154.6 MB, static peak 370.1 MB, texture 4.5 MB, video 16.7 MB, objects 4101, resources 664, nodes 65, orphan nodes 0
    mem c2_era5_title: static 155.5 MB, static peak 370.1 MB, texture 4.5 MB, video 16.8 MB, objects 3868, resources 665, nodes 153, orphan nodes 0
    mem c2_era5_overworld: static 157.9 MB, static peak 370.1 MB, texture 6.6 MB, video 18.8 MB, objects 4403, resources 662, nodes 211, orphan nodes 0
    mem c2_era5_bag: static 158.6 MB, static peak 370.1 MB, texture 6.6 MB, video 18.9 MB, objects 4528, resources 662, nodes 255, orphan nodes 0
    mem c2_era5_battle: static 159.8 MB, static peak 370.1 MB, texture 6.7 MB, video 19.0 MB, objects 4740, resources 666, nodes 330, orphan nodes 0
    mem c2_era5_freed: static 155.1 MB, static peak 370.1 MB, texture 5.9 MB, video 18.1 MB, objects 4096, resources 660, nodes 65, orphan nodes 0
    mem c3_era1_title: static 155.2 MB, static peak 370.1 MB, texture 3.7 MB, video 16.0 MB, objects 3869, resources 663, nodes 153, orphan nodes 0
    mem c3_era1_overworld: static 155.9 MB, static peak 370.1 MB, texture 4.5 MB, video 16.7 MB, objects 4405, resources 666, nodes 233, orphan nodes 0
    mem c3_era1_bag: static 157.1 MB, static peak 370.1 MB, texture 4.5 MB, video 16.8 MB, objects 4645, resources 666, nodes 288, orphan nodes 0
    mem c3_era1_battle: static 157.4 MB, static peak 370.1 MB, texture 4.6 MB, video 16.8 MB, objects 4735, resources 668, nodes 346, orphan nodes 0
    mem c3_era1_freed: static 154.8 MB, static peak 370.1 MB, texture 4.5 MB, video 16.7 MB, objects 4101, resources 664, nodes 65, orphan nodes 0
    mem c3_era5_title: static 155.7 MB, static peak 370.1 MB, texture 4.5 MB, video 16.8 MB, objects 3868, resources 665, nodes 153, orphan nodes 0
    mem c3_era5_overworld: static 158.2 MB, static peak 370.1 MB, texture 6.6 MB, video 18.8 MB, objects 4403, resources 662, nodes 211, orphan nodes 0
    mem c3_era5_bag: static 158.8 MB, static peak 370.1 MB, texture 6.6 MB, video 18.9 MB, objects 4528, resources 662, nodes 255, orphan nodes 0
    mem c3_era5_battle: static 160.0 MB, static peak 370.1 MB, texture 6.7 MB, video 19.0 MB, objects 4740, resources 666, nodes 330, orphan nodes 0
    mem c3_era5_freed: static 155.4 MB, static peak 370.1 MB, texture 5.9 MB, video 18.1 MB, objects 4096, resources 660, nodes 65, orphan nodes 0
    mem end: static 155.3 MB, static peak 370.1 MB, texture 5.9 MB, video 18.1 MB, objects 4086, resources 660, nodes 65, orphan nodes 0
    mem peak static: 370.1 MB
