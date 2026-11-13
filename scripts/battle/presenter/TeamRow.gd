class_name TeamRow
extends Control
## The team row of the battle HUD: one small mark per team member (squares in Era I and II,
## lozenges from Era III; never a round shape, LEGAL.md). The shape tells the state, so it
## reads in four inks and for colour-blind players: full = fit, lower half = half Vigor or
## less, full with a paper dot = has a status, hollow = down. Colour comes on top from Era II
## (fit, hurt) and Era III (the status colour). See EraBattleHud.team_state / team_colour.

## One entry per team member: {"state": fit|hurt|status|down, "status": String}.
var marks: Array[Dictionary] = []
var era: int = 1
## Formation battles: marks one pixel smaller.
var compact: bool = false
## What a screen reader says in front of the count ("Your team" / "Foe's team").
var title: String = "Your team"

## Reads the states of [param party] (partner Spirlings left out by the caller).
func set_party(party: Array) -> void:
	var next: Array[Dictionary] = []
	for s: Variant in party:
		var sp: Spirling = s as Spirling
		next.append({"state": EraBattleHud.team_state(sp), "status": sp.status if sp != null else ""})
	if next == marks:
		return
	var changed: bool = not marks.is_empty()
	marks = next
	queue_redraw()
	if changed and EraBattleHud.flag(era, "team_pop") and is_inside_tree():
		Juice.pop(self)

func mark_size() -> int:
	return int(EraBattleHud.num(era, "team_mark", 5)) - (1 if compact else 0)

## How many marks stand for a Spirling that can still fight.
func standing() -> int:
	var n: int = 0
	for m: Dictionary in marks:
		n += 1 if str(m.state) != "down" else 0
	return n

func screen_reader_text() -> String:
	return Loc.t("%s: %d of %d can fight") % [Loc.t(title), standing(), marks.size()]

func _draw() -> void:
	accessibility_name = screen_reader_text()
	var m: int = mark_size()
	var lozenge: bool = EraBattleHud.text(era, "team_shape", "square") == "diamond"
	# A strip of paper behind the marks keeps them readable on any backdrop.
	draw_rect(Rect2(-2, -2, size.x + 4, size.y + 4), UITheme.BG)
	for i: int in marks.size():
		var state: String = str(marks[i].state)
		var col: Color = EraBattleHud.team_colour(era, state, str(marks[i].status))
		var x0: int = i * (m + 2)
		for y: int in m:
			var inset: int = absi(y - m / 2) if lozenge else 0
			var x: int = x0 + inset
			var wpx: int = m - inset * 2
			var edge: bool = y == 0 or y == m - 1
			var filled: bool = state == "fit" or state == "status" or (state == "hurt" and y >= m / 2)
			if lozenge or edge:
				# Outline: the two end pixels of a lozenge row, the whole row of a square's edge.
				draw_rect(Rect2(x, y, wpx, 1), UITheme.INK)
				if lozenge and wpx > 2:
					draw_rect(Rect2(x + 1, y, wpx - 2, 1), col if filled else UITheme.BG)
			else:
				draw_rect(Rect2(x, y, wpx, 1), UITheme.INK)
				draw_rect(Rect2(x + 1, y, wpx - 2, 1), col if filled else UITheme.BG)
		if state == "status":
			draw_rect(Rect2(x0 + m / 2, m / 2, 1, 1), UITheme.BG)
