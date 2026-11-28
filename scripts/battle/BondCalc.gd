class_name BondCalc
extends RefCounted
## Bond chance = bond_rate * max(1 - HP%, 0.1) * timing_score * (1.5 if statused) + charm bonus, capped at 0.95.
## The chance is never shown to the player (LEGAL.md: no live capture-odds meter).
## A legendary Spirling multiplies the chance by LegendQuests.bond_factor (0 above half HP).

const MIN_HP_FACTOR: float = 0.1
const STATUS_BONUS: float = 1.5
const MAX_CHANCE: float = 0.95

static func chance(target: Spirling, timing_score: float, charm_bonus: float = 0.0) -> float:
	var hp_factor: float = maxf(1.0 - target.hp_fraction(), MIN_HP_FACTOR)
	var status_bonus: float = STATUS_BONUS if not target.status.is_empty() else 1.0
	var c: float = target.data.bond_rate * hp_factor * clampf(timing_score, 0.0, 1.0) * status_bonus
	var legend: float = LegendQuests.bond_factor(target, GameState.flags)
	if legend <= 0.0:
		return 0.0
	return clampf(c * legend + charm_bonus, 0.0, MAX_CHANCE)

# --- Bond charms (1.3.2, owner 28 Nov 2026) --------------------------------------------------
# A charm is held out before the Mine! bar, never thrown. Its "bond_bonus" always counts, its
# "bond_if" bonus only in its situation, and "mine_taps_off" shortens the Mine! bar. The chance
# keeps the 0.95 cap above; only the Bond Seal ("bond_sure") makes a bond certain.

## The fewest taps a Mine! bar ever needs, whatever charm is held out.
const MIN_MINE_TAPS: int = 8
## In the Echo call styles, each tap a charm takes off counts as this much head start on the score.
const ECHO_PER_TAP: float = 0.03
const SHY_RARITIES: Array[String] = ["shy", "ancient"]
const WEATHER_KINDS: Array[String] = ["rain", "fog", "wind", "storm"]
## Below this Vigor share (or with a status) a wild Spirling counts as worn down.
const WORN_DOWN: float = 0.5

## Bonus of charm [param item] (an items.json entry) on [param target]. [param lead] is the
## player's Spirling in front, [param ctx] holds "night" (bool) and "weather" (String).
static func charm_bonus(item: Dictionary, target: Spirling, lead: Spirling = null, ctx: Dictionary = {}) -> float:
	var b: float = float(item.get("bond_bonus", 0.0))
	var cond: Variant = item.get("bond_if")
	if cond is Dictionary and charm_applies(str((cond as Dictionary).get("when", "")), target, lead, ctx):
		b += float((cond as Dictionary).get("bonus", 0.0))
	return b

## True when the situation [param when] of a charm holds for this bond.
static func charm_applies(when: String, target: Spirling, lead: Spirling, ctx: Dictionary) -> bool:
	if target == null:
		return false
	match when:
		"kindred":
			if lead == null:
				return false
			for e: int in target.data.elements:
				if e in lead.data.elements:
					return true
			return false
		"night":
			return bool(ctx.get("night", false))
		"weather":
			return str(ctx.get("weather", "")) in WEATHER_KINDS
		"wounded":
			return target.hp_fraction() <= WORN_DOWN or not target.status.is_empty()
		"shy":
			return target.data.rarity in SHY_RARITIES
	return false

## Taps charm [param item] takes off the Mine! bar.
static func taps_off(item: Dictionary) -> int:
	return maxi(0, int(item.get("mine_taps_off", 0)))

## Head start of charm [param item] on the Echo call score (styles without the Mine! bar).
static func echo_head_start(item: Dictionary) -> float:
	return taps_off(item) * ECHO_PER_TAP
