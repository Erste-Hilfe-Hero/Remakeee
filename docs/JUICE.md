# Juice: game feel in one place

`scripts/core/Juice.gd` is an autoload. Every tween, shake, freeze and bounce in the game goes through it, so the feel can be tuned in one file and reduced motion is honoured everywhere. Only `Juice.reduced()` reads the reduce-motion setting.

## Curves

| Name | Transition / easing | Time | Use it for |
|---|---|---|---|
| `open` | BACK / OUT | 0.18 s | Something appears: a menu, a dialog box, a card |
| `close` | QUAD / IN | 0.12 s | Something leaves: closing a menu, darkening before a map change |
| `move` | CUBIC / IN_OUT | 0.22 s | Moving from A to B: pointers, list swaps, sliding pages |
| `impact` | EXPO / OUT | 0.10 s | The first, sharp part of a hit or push |
| `settle` | ELASTIC / OUT | 0.35 s | Springing back to rest after `impact` |
| `fade` | SINE / OUT | 0.11 s | Brightening after a map change, no overshoot |

Rule of thumb: entering is `open`, leaving is `close`, travelling is `move`, a hit is `impact` followed by `settle`. Inside a battle every duration is divided by the battle speed (`Juice.speed()`). Under reduced motion no tween runs longer than 0.15 s.

## Helpers

```gdscript
Juice.tween(node, "position", Vector2(8, 0), "move")    # named curve, positions on whole pixels
await Juice.pop(button)                                  # 1.0 -> 1.15 -> 1.0 confirm bounce
await Juice.nudge(sprite, Vector2.LEFT, 2)               # 1 to 3 px push, back in 0.1 s
await Juice.stagger(list.get_children())                 # entries fade in 0.03 s apart
var tw := Juice.blink_safe(hint)                         # brightness 100 % <-> 60 %, max 3 per second
Juice.stop_blink(hint)
await Juice.wobble(gift_icon, 4.0, 0.5)                  # rocks up to 4 degrees, then rests
await Juice.count_to(coin_label, 120, 170)               # counting number with soft ticks
Juice.press_feedback(button)                             # pop on release
Juice.add_trauma(Juice.TRAUMA_HIT, Elements.E.STONE)     # screen shake, shaped by element
await Juice.hitstop(0.4)                                 # short freeze for a hit taking 40 % HP
```

## Screen shake

Shake is trauma between 0 and 1 that decays by 1.8 per second. The offset is trauma squared times at most 3 x 2 pixels, read from smooth noise at 30 Hz, so it rolls instead of flickering. Values from 0.15 px up to one pixel count as one pixel (larger ones round), so a strong hit (0.4) or a Rift opening (0.35) still shows a 1 px shake while a normal hit alone stays still. The element of the hit shapes it: Stone only shakes up and down, Gale only side to side, Volt twice as fast at half the reach, every other element on both axes. Only the registered shake root moves (the battle field's position, or the world camera's `offset` via `set_shake_root(camera, "offset")`), never the UI. `Juice.calm()` stops a shake at once; photo mode calls it before it takes a picture. The settings level (Off, Weak, Full) scales it, and reduced motion turns it off.

## Rules

- No new `TRANS_LINEAR` tweens, except power bars that must fill evenly.
- No hard on/off blinking: use `blink_safe`. Nothing may flash more than 3 times a second (`tools/fx_flash_check.tscn` checks the battle effects).
- Every helper is a no-op or a short fade under reduced motion; do not read `GameState.reduce_motion` yourself.
- Positions stay on whole pixels.
