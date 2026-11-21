# Era feel: sound

Owner wish: Chimora should feel like starting on the very first handheld monster-taming game
and growing more modern, one hardware generation at a time, up to the fifth. The art already
follows those steps (EraManager). This page is the sound slice: what each hardware step sounded
like (described generically, no product names), what Chimora had, and what this pass added.

Era regions: I = story acts 1-4, II = Vellmarch, III = Quillmarch, IV = Halcyra, V = Quivermoor.

## The five hardware steps

| Era | Sound hardware (generic) | What it means for the ear |
|---|---|---|
| I | 4-channel chip: two pulse waves (duty 12.5/25/50 %), one 4-bit wave channel, one noise channel. Mono speaker. | Dry, short, beepy. Cries are pure pulse sweeps with a little noise. Every UI action is one or two pulse notes. Low health = a looping two-tone beep. No footsteps, no ambience. |
| II | Same chip, better use of it: vibrato, duty changes inside a note, a second pulse doubling in harmony, echo faked with a delayed quiet copy. | Same palette, richer arrangement. Jingles get harmony, menu notes get a tiny echo. |
| III | Sample playback at low rates (about 11-16 kHz), more channels, a hardware echo. | Soft, slightly muffled "sampled instrument" tones, more voices at once, noise filtered into a rasp. Cries become longer and less buzzy. |
| IV | Higher-quality samples, a proper reverb, stereo output. | Clean tones with bell-like overtones, sounds sit in a room, slight stereo width. Ambience per area appears. |
| V | Streamed and dynamic audio: music layers that change with the battle state, a low-health variation instead of the beeping alarm, footsteps by surface, ambient beds. | Longer, layered sounds in a hall, octave doubling, air noise. Battle music builds up as the fight heats up; low health is a heartbeat plus the pinch music. |

## Feature table per era

"Had" = in the game before this pass. "Added" = this pass (data/era_audio.json, tools/audio/era_sfx.py).

### Era I (story acts 1-4)

| Feature | Had | Added / now |
|---|---|---|
| Music: 4 chip channels, dry | yes (music.py era 1, era_fx "1" dry) | - |
| Menu move / confirm / cancel, text blip | yes (select, confirm, cancel, blip) | listed as the Era I set |
| Bump, door, stairs | yes | listed as the Era I set |
| Heal, level-up, faint | yes | listed as the Era I set |
| Bond (catch) jingle | no (bonding was silent) | bond.wav, played on a successful bond |
| Evolution (unfold) jingle | no (reused level_up) | evolve.wav in UnfurlSequence |
| Low-HP alarm | no (only the pinch music) | low_hp.wav, loops every 0.45 s while Vigor is at 25 % or less (at most 12 beeps) |
| Cries: pure chip | yes (Cry.gd) | unchanged, byte for byte |
| Footsteps | yes (quiet, item 2501) | kept |
| Ambience | 6 named loops for story maps | kept |

### Era II (Vellmarch)

| Feature | Had | Added / now |
|---|---|---|
| Music: same chip, vibrato, echo voice, chorus bus | yes (era 2 voices, era_fx chorus) | - |
| All 15 sfx keys | no (Era I files everywhere) | `<key>_era2.wav`: vibrato, duty change, harmony on jingles, 60 ms echo (16 kHz) |
| Cry | Era I cry | length x1.1, vibrato x1.6, echo 0.3 |
| Low-HP alarm | no | low_hp_era2, 0.45 s loop |

### Era III (Quillmarch)

| Feature | Had | Added / now |
|---|---|---|
| Music: sample-like voices, room | yes (era 3 voices, era_fx reverb) | - |
| All 15 sfx keys | no | `<key>_era3.wav`: band-limited tones, written at 11025 Hz (low-rate sample feel), harmony voice |
| Cry | Era I cry | "soft" wave (4 harmonics), sample-and-hold x2, length x1.25, filtered noise, echo |
| Low-HP alarm | no | low_hp_era3, 0.5 s loop, at most 10 |

### Era IV (Halcyra)

| Feature | Had | Added / now |
|---|---|---|
| Music: bell overtones, wider room | yes | - |
| All 15 sfx keys | no | `<key>_era4.wav`: additive tones plus FM bell overtone, room reverb (16 kHz mono; stereo width comes from the Music bus effects) |
| Cry | Era I cry | "rich" wave (8 harmonics, bell overtone), length x1.4, reverb |
| Low-HP alarm | no | low_hp_era4, softer, 0.6 s loop, at most 8 |
| Ambience per biome | no (Halcyra maps had none) | town_era4, route_era4, marsh_era4 for outdoor maps without their own loop |

### Era V (Quivermoor)

| Feature | Had | Added / now |
|---|---|---|
| Music: octave-doubled lead, hall | yes | - |
| Dynamic battle music | no (one file; pinch was a track switch) | battle_era5 and warden_era5 now have stems; MusicDirector fades them by intensity: 0 before the first blow (bass + chords), 1 after it (+ melody), 2 once either side is at half or below (+ drums). The pinch switch to battle_pinch_era5 keeps the intensity. |
| Low-HP variation | no | low_hp_era5 is a soft double heartbeat, played once; the pinch music carries the rest |
| All 15 sfx keys | no | `<key>_era5.wav`: Era IV voice plus octave layer, air noise, longer hall (16 kHz mono) |
| Footsteps by surface | plain Era I steps | step_<ground>_<take>_era5 for grass, path, wood, sand, stone, shore |
| Ambience per biome | no | town_era5 (chimes, birds), route_era5 (gusts, far calls, crickets), marsh_era5 (insects, reeds) |
| Cry | Era I cry | "rich" wave, octave-down layer 0.35, breath noise, length x1.6, long reverb |

## Rules

- A bonded Spirling keeps the cry of its origin era (Spirling.origin_era, set when it joins).
  Wild Spirlings and rivals' teams call in the era on screen (`Sound.cry_era_for`).
- Later eras never lose a sound: every era defines every key in `sfx_keys`, and each era's table
  holds every key of the era before it (tests/unit/test_era_audio.gd).
- Missing files fall back: `Sound.era_sfx_name` walks down from the active era to the newest era
  whose file exists, then to the plain name. A missing ambience or stem file plays nothing.
- Fast-repeating sounds (cursor, text blip) get no echo and only a small room in Eras IV and V.

## Files and sizes

| Part | Files | Bytes |
|---|---|---|
| Era sfx sets (Era I new keys + Eras II-V) | 63 wav | about 0.85 MB raw; all of audio/sfx is 1.62 MB of the 2 MB budget (test_sound_voices) |
| Era V footsteps | 12 wav | about 40 KB |
| Era IV/V ambience | 6 ogg | about 0.83 MB (all ambience 1.76 MB of the 2.5 MB limit) |
| Era V battle stems | 8 ogg | about 0.35 MB (all stems 4.9 MB of the 5 MB test limit) |

Rebuild: `python3 tools/audio/gen_audio.py --only <name>`; era sets live in tools/audio/era_sfx.py,
the biome loops in tools/audio/ambience.py (`ERA_LOOPS`), the layered songs in music.py
(`LAYERED_SONGS`).
