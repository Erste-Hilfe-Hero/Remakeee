# Flow: how screens arrive and leave

Owner wish (update 1.3.2): the game should feel more fluid. The battle scene, the text box and
the pause menu already moved; the menus between them still cut. This page lists what was
abrupt, what it does now, and the rules every transition follows. The helpers live in
`scripts/core/Juice.gd` (see `docs/JUICE.md`).

## Rules

- **Nobody waits.** A transition never delays the answer to a press. A list is hidden and its
  result returned in the same frame as before; what fades afterwards is a frame that takes no
  input. Something that arrives takes input from its first frame.
- **A press finishes it.** A press on a list that still arrives ends the arrival at once
  (`Juice.finish`).
- **Reduced motion:** no transition at all. Things are there, or gone, in one frame
  (`Juice.enter` and `Juice.leave` return null and set the end state).
- **Era look.** Eras I and II (`Juice.stepped()`) fade in four hard levels (0, 1/3, 2/3, full)
  and slide in 2 px steps, the way their screens could. Eras III to V ease smoothly. This also
  holds for every alpha fade made with `Juice.tween` (screen fades, the pause menu, the text box).
- **Whole pixels.** Slides are rounded; a Control is moved through its four offsets, so its
  size and anchors stay as the layout set them.
- **Short.** 0.08 to 0.18 s; the curves are the ones in `docs/JUICE.md`.

## Places

Frame strips before and after: `tools/flow_shots.gd` (one tile per frame at 60 fps).

| # | Place | Before | Now |
| --- | --- | --- | --- |
| 1 | A list opens (`ListPicker.fade_in`) | smooth alpha blend in every era, off the look of Eras I and II | four hard levels in Eras I and II, smooth from Era III |
| 2 | List to sub-list and back | the old list cut away, the world showed through for a frame, the new one faded in the same way in both directions | the new list slides the last 8 px in (4 px in two steps in Eras I and II): from the right going deeper, from the left coming back, over the old list's fading frame |
| 3 | A value changes in a list (settings, sliders) | the whole list flashed (hidden, then faded in again) and stood scrolled to the wrong row for two frames | the list stays solid; the old rows no longer count in the layout of the new ones |
| 4 | A list closes | hard cut | the empty frame stays for 0.12 s and fades; it takes no input |
| 5 | Info box (`MenuHost.info`, summaries, questions) | popped in and out | rises 4 px while it fades in, fades out behind what comes next; a following page keeps the box and fades only the text |
| 6 | Tabs of a list (satchel pockets, shop tabs) | whole list faded from nothing on each tab | frame and tabs stay, the rows fade in; old and new tabs no longer share the row for a frame |
| 7 | Menu toast ("Saved.") | popped in and out | drops 4 px in, fades out |
| 8 | Notes at the top (`Toast`: badges, daily tasks) | popped in, linear fade out | slides 8 px down from the edge, leaves upward |
| 9 | Buttons | 1 px sink while held, pop on release; Back and tabs had neither | held buttons squash to 97 x 90 % in 0.05 s from Era III (Eras I and II keep the sink), pop on release as before; Back and tabs join in |
| 10 | Battle orders (`CommandMenu.set_enabled`) | popped in (Era V staggered already) | fade in for Eras I to IV, taking presses from the first frame |
| 11 | Screen fades: battle start and end, warps, pause menu close | smooth alpha in every era | four hard levels in Eras I and II (the "stepped 4-shade fade" that `docs/ERA_FEEL_UI.md` listed as missing), unchanged from Era III |
| 12 | Place banner in Era I (`TownPopup` "plain") | popped in and out | fades in and out in the era's steps |

## Looked at and left alone

- Text box open, close and page turn; pause menu slide; battle intro, Vigor bars, faint, level
  panel; list pointer slide and overscroll bounce: these already move.
- List scrolling with the pad still jumps row by row: `ListPicker` relies on the scroll value
  right after a move (whole-row snapping), and touch scrolling is the engine's own.
- Vigor bars in the team list after an item: the list is rebuilt, the bar has no state to
  animate from. The list no longer flashes when that happens (place 3).
- Boot, splash and title belong to another change.
