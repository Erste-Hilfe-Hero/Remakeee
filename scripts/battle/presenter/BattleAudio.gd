class_name BattleAudio
extends RefCounted
## Battle sounds that stay the same in every era (docs/KAMPF_PLAN_1000.md, "Audio im Kampf"),
## from data/battle_show.json "audio". The static functions only decide name, pitch and volume,
## so tests need no audio device; play() hands the result to Sound.
##
## - One sound per status (685), stage notes that climb with the stage (686) and an Overcharge
##   swell that climbs with the Energy poured in (687).
## - Resonance field rise, fade and shift (688, 689, 720), the keen-hit accent (719) and the
##   matchup tones (696: up for an overwhelming hit, down for one that barely landed).
## - At 4x and in battery saver the flourish sounds stay out (701, 702); accents keep a gap
##   so a crowded multi-battle turn does not pile them up (704).

## The status sounds of data/battle_show.json "audio.status", named here so the sound check
## (tests/unit/test_sfx_names.gd) finds every file in code.
const STATUS_SOUNDS: Array[String] = ["status_scorch", "status_soak", "status_root", "status_jolt", "status_daze", "status_drowse",
	"status_spent", "status_marked"]

## Last time (seconds) an accent played, for the accent gap.
static var _last_accent: float = -100.0

static func cfg() -> Dictionary:
	var a: Variant = BattleShow.cfg().get("audio", {})
	return a if a is Dictionary else {}

## Sound for [param status] taking hold ("status" for one without its own).
static func status_sound(status: String) -> String:
	return str((cfg().get("status", {}) as Dictionary).get(status, "status"))

## Pitch of a stage note for a stat now at [param stage]: the first step plays as written, each
## further step a little higher, up to stage_max_pitch.
static func stage_pitch(stage: int) -> float:
	var step: float = float(cfg().get("stage_step", 0.06))
	return minf(1.0 + step * maxi(absi(stage) - 1, 0), float(cfg().get("stage_max_pitch", 1.36)))

## Stage note for a change of [param delta]: "stage_up", "stage_down" or "" for no change.
static func stage_sound(delta: int) -> String:
	if delta == 0:
		return ""
	return "stage_up" if delta > 0 else "stage_down"

## Pitch of the Overcharge swell for [param extra] Energy poured in (1.0 for none).
static func overcharge_pitch(extra: int) -> float:
	var step: float = float(cfg().get("overcharge_step", 0.08))
	return minf(1.0 + step * maxi(extra - 1, 0), float(cfg().get("overcharge_max_pitch", 1.5)))

## Sound of a field event: "field_rise" for a field on a calm ground, "field_shift" when it
## replaces one, "field_fade" when it ends.
static func field_sound(ending: bool, had_field: bool) -> String:
	if ending:
		return "field_fade"
	return "field_shift" if had_field else "field_rise"

## Matchup tone for effectiveness [param eff]: "eff_up", "eff_down" or "".
static func eff_tone(eff: float) -> String:
	if eff > 1.0:
		return "eff_up"
	if eff > 0.0 and eff < 1.0:
		return "eff_down"
	return ""

## End of battle: {"fade": the music fades out, "sfx": the jingle sound or ""}. A win keeps the
## victory jingle Sound already plays.
static func end_cue(outcome: int) -> Dictionary:
	match outcome:
		BattleModel.Outcome.LOSS:
			return {"fade": true, "sfx": "defeat"}
		BattleModel.Outcome.FLED:
			return {"fade": true, "sfx": ""}
	return {"fade": false, "sfx": ""}

## False when [param sound] stays out at battle speed [param speed] or in battery saver.
static func keep(sound: String, speed: float, battery: bool) -> bool:
	var lists: Array = []
	if speed >= 4.0:
		lists.append(cfg().get("skip_fast", []))
	if battery:
		lists.append(cfg().get("skip_battery", []))
	for l: Variant in lists:
		for p: Variant in l:
			if sound.begins_with(str(p)):
				return false
	return true

## True when an accent may play at [param now] after one at [param last].
static func accent_ok(now: float, last: float) -> bool:
	return now - last >= float(cfg().get("accent_gap", 0.25))

## Plays [param sound] unless the speed or battery saver keeps it out.
static func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if sound.is_empty() or not keep(sound, GameState.battle_speed_scale(), GameState.battery_saver):
		return
	Sound.sfx(sound, volume_db, pitch)

## Plays an accent (keen hit, matchup tone) at most once per accent gap.
static func accent(sound: String) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if sound.is_empty() or not accent_ok(now, _last_accent):
		return
	_last_accent = now
	play(sound, float(cfg().get("accent_db", -4.0)))
