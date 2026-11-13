class_name BattleShow
extends Node
## Battle presentation that is the same in every era (docs/KAMPF_PLAN_1000.md, "Tempo, Animation
## und Praesentation" and "Audio im Kampf"), from data/battle_show.json. BattleScene keeps the
## flow and calls on_event() for every event it plays; this node adds on top:
## - banners for the field at the start, the boss's phase, the partner and the end (675-679);
## - status motes, the stage aura and the lantern light on send-out (SpirlingAura, 647-650);
## - a hard whole-number zoom on the boss when its phase turns in Eras I-III (645);
## - the winners' pose (654);
## - the battle sounds of BattleAudio: statuses, stages, Overcharge, fields, keen hits,
##   matchup tones, boss entrance and phase, rule seal, partner, calm rule, defeat (683-720).
## Static helpers (night tint of the backdrop, short intro on a rematch) serve BattleScene.

const PATH: String = "res://data/battle_show.json"
## Rematch memory in GameState.records: trainer name -> 1 once its intro played.
const SEEN_KEY: String = "intro_seen"

static var _cfg: Dictionary = {}

var scene: BattleScene
var banner: RuleBanner
## A Resonance field is in play (the next one is a shift, not a rise).
var field_on: bool = false
## Stat stages per "side:slot", from the STAT_CHANGED events as they play.
var stages: Dictionary = {}
## Banners shown so far (tests).
var banners: Array[String] = []
var _banner_id: int = 0

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_cfg = raw if raw is Dictionary else {"_missing": true}
	return _cfg

## Hooks onto [param p_scene] once its controls exist (end of BattleScene._build).
func attach(p_scene: BattleScene) -> void:
	scene = p_scene
	scene.add_child(self)
	banner = RuleBanner.new()
	banner.name = "show_banner"
	scene._field.add_child(banner)

func _exit_tree() -> void:
	Sound.music_pitch(1.0)

# --- Pure helpers ---------------------------------------------------------------------------

## Freeze in seconds for a keen hit (644).
static func crit_hitstop() -> float:
	return float(cfg().get("crit_hitstop", 0.09))

## Whole-number zoom on the boss when its phase turns in [param era], 0 for none (645).
static func phase_zoom(era: int) -> float:
	var z: float = float((cfg().get("phase_zoom", {}) as Dictionary).get(str(era), 0.0))
	return roundf(z) if z > 1.0 else 0.0

## Banner title for [param e], "" for none (675, 676, 678, 679; a Warden rule keeps RuleBanner).
static func banner_title(e: BattleEvent) -> String:
	match e.type:
		BattleEvent.Type.FIELD:
			var label: String = str(e.data.get("label", ""))
			if label.is_empty():
				label = str(BattleRules.FIELDS.get(str(e.data.get("field", "")), {}).get("label", ""))
			return label
		BattleEvent.Type.BOSS_PHASE:
			return "%s awakens" % str(e.data.get("name", ""))
		BattleEvent.Type.PARTNER:
			return "Side by side: %s" % str(e.data.get("partner", ""))
		BattleEvent.Type.BATTLE_END:
			match int(e.data.get("outcome", 0)):
				BattleModel.Outcome.WIN: return "Victory"
				BattleModel.Outcome.BONDED: return "Bonded"
				BattleModel.Outcome.FLED: return "Slipped away"
				BattleModel.Outcome.LOSS: return "Worn out"
	return ""

## Tint of the backdrop at [param phase] (659): part of the day/night tint outdoors when the
## option is on, white indoors, for backdrops that never get it and by day.
static func night_tint(phase: int, enabled: bool, outdoor: bool, backdrop: String) -> Color:
	var n: Dictionary = cfg().get("night", {})
	if not outdoor or not enabled or backdrop in (n.get("skip_backdrops", []) as Array):
		return Color.WHITE
	return Color.WHITE.lerp(DayCycle.TINTS.get(phase, Color.WHITE), clampf(float(n.get("mix", 0.6)), 0.0, 1.0))

## Key of the rematch memory for [param m]: the trainer's name, "" for wild battles.
static func intro_key(m: BattleModel) -> String:
	return "" if m == null or m.is_wild else m.trainer_name

## Share of the intro a battle keeps (660): quick_intro for a trainer whose intro already
## played ([param seen] is GameState.records[SEEN_KEY]), else all of it.
static func intro_share(seen: Dictionary, key: String) -> float:
	if key.is_empty() or not seen.has(key):
		return 1.0
	return clampf(float(cfg().get("quick_intro", 0.4)), 0.05, 1.0)

## Remembers that the intro of [param m]'s trainer played.
static func note_intro(m: BattleModel) -> void:
	var key: String = intro_key(m)
	if key.is_empty():
		return
	var seen: Dictionary = (GameState.records.get(SEEN_KEY, {}) as Dictionary).duplicate()
	seen[key] = 1
	GameState.records[SEEN_KEY] = seen

## Intro share for [param m] from the saved memory.
static func intro_share_for(m: BattleModel) -> float:
	return intro_share(GameState.records.get(SEEN_KEY, {}) as Dictionary, intro_key(m))

## Glints of the winners' pose in [param era].
static func victory_glints(era: int) -> int:
	return int((cfg().get("victory_glints", {}) as Dictionary).get(str(era), 0))

# --- Events ---------------------------------------------------------------------------------

func on_event(e: BattleEvent) -> void:
	var side: int = int(e.data.get("side", 0))
	var slot: int = int(e.data.get("slot", 0))
	var title: String = banner_title(e)
	if not title.is_empty():
		show_banner(title)
	match e.type:
		BattleEvent.Type.SEND_OUT, BattleEvent.Type.SWAP_IN:
			stages.erase(_key(side, slot))
			var party: Array = scene.model.party(side)
			var i: int = int(e.data.get("index", 0))
			var st: String = (party[i] as Spirling).status if i >= 0 and i < party.size() else ""
			var aura: SpirlingAura = aura_at(side, slot)
			if aura != null:
				aura.set_state(st, {})
				aura.glow_lantern()
		BattleEvent.Type.STATUS_APPLIED:
			_refresh(side, slot, str(e.data.get("status", "")))
		BattleEvent.Type.STATUS_CURED:
			_refresh(side, slot, "")
		BattleEvent.Type.STAT_CHANGED:
			var d: Dictionary = stages.get(_key(side, slot), {})
			d[str(e.data.get("stat", ""))] = int(e.data.get("stage", 0))
			stages[_key(side, slot)] = d
			var a: SpirlingAura = aura_at(side, slot)
			if a != null:
				a.set_state(a.status, d)
		BattleEvent.Type.FAINTED:
			stages.erase(_key(side, slot))
			var fa: SpirlingAura = aura_at(side, slot)
			if fa != null:
				fa.set_state("", {})
		BattleEvent.Type.DAMAGE:
			if not bool(e.data.get("status_tick", false)):
				if bool(e.data.get("crit", false)):
					BattleAudio.play("crit_accent", float(BattleAudio.cfg().get("accent_db", -4.0)))
				if e.data.has("eff"):
					BattleAudio.accent(BattleAudio.eff_tone(float(e.data.eff)))
		BattleEvent.Type.MOVE_USED:
			var extra: int = int(e.data.get("overcharge", 0))
			if extra > 0:
				BattleAudio.play("overcharge", 0.0, BattleAudio.overcharge_pitch(extra))
		BattleEvent.Type.FIELD:
			BattleAudio.play(BattleAudio.field_sound(false, field_on))
			field_on = true
		BattleEvent.Type.FIELD_END:
			BattleAudio.play(BattleAudio.field_sound(true, field_on))
			field_on = false
		BattleEvent.Type.BOSS:
			BattleAudio.play("boss_intro")
		BattleEvent.Type.BOSS_PHASE:
			BattleAudio.play("boss_phase")
			Sound.music_pitch(float(BattleAudio.cfg().get("phase_music_pitch", 1.06)))
			_phase_zoom(side, slot)
		BattleEvent.Type.RULE:
			if not bool(e.data.get("turning", false)):
				BattleAudio.play("rule_seal")
		BattleEvent.Type.PARTNER:
			BattleAudio.play("partner_call")
		BattleEvent.Type.STATUS_FAILED:
			if bool(e.data.get("clause", false)):
				BattleAudio.play("calm_fail")
		BattleEvent.Type.BATTLE_END:
			var outcome: int = int(e.data.get("outcome", 0))
			Sound.music_pitch(1.0)
			var cue: Dictionary = BattleAudio.end_cue(outcome)
			if bool(cue.fade):
				Sound.stop_music()
			BattleAudio.play(str(cue.sfx))
			if outcome == BattleModel.Outcome.WIN:
				_victory_pose()

static func _key(side: int, slot: int) -> String:
	return "%d:%d" % [side, slot]

func _refresh(side: int, slot: int, status: String) -> void:
	var a: SpirlingAura = aura_at(side, slot)
	if a != null:
		a.set_state(status, stages.get(_key(side, slot), {}))

## The aura on the sprite at [param side]/[param slot], made on first use.
func aura_at(side: int, slot: int) -> SpirlingAura:
	var sp: SpirlingSprite = scene._sprite(side, slot)
	if sp == null:
		return null
	for c: Node in sp.get_children():
		if c is SpirlingAura:
			return c
	var a := SpirlingAura.new()
	a.name = "aura"
	a.era = EraManager.active_era()
	sp.add_child(a)
	return a

## Shows [param title] on the show banner for banner_time (scaled by the battle speed).
func show_banner(title: String) -> void:
	banners.append(title)
	if banner == null or scene._field == null:
		return
	banner.show_rule(Loc.t(title), false, scene._field.size.x, roundf(scene._field.size.y * 0.42))
	_banner_id += 1
	var id: int = _banner_id
	if not is_inside_tree():
		return
	await get_tree().create_timer(float(cfg().get("banner_time", 1.1)) / Juice.speed()).timeout
	if id == _banner_id and is_instance_valid(banner):
		banner.visible = false

## Eras I-III: the field cuts to a whole-number zoom on the boss and back (645).
func _phase_zoom(side: int, slot: int) -> void:
	var z: float = phase_zoom(EraManager.active_era())
	var root: Control = scene._shake_root
	var sp: SpirlingSprite = scene._sprite(side, slot)
	if z <= 1.0 or Juice.reduced() or root == null or sp == null or not is_inside_tree():
		return
	var c: Vector2 = (sp.position + sp.size / 2.0).round()
	root.pivot_offset = Vector2(clampf(c.x, 0.0, root.size.x), clampf(c.y, 0.0, root.size.y)).round()
	root.scale = Vector2(z, z)
	await get_tree().create_timer(float(cfg().get("phase_zoom_hold", 0.4)) / Juice.speed()).timeout
	if is_instance_valid(root):
		root.scale = Vector2.ONE

## The winners step forward with a hop (and glints from Era III), never waited for (654).
func _victory_pose() -> void:
	if Juice.reduced():
		return
	var n: int = victory_glints(EraManager.active_era())
	for slot: int in maxi(scene.model.slot_count(BattleModel.Side.PLAYER), 1):
		var sp: SpirlingSprite = scene._sprite(BattleModel.Side.PLAYER, slot)
		if sp != null and sp.is_inside_tree() and sp.visible and sp.spirling != null and not sp.spirling.is_fainted():
			sp.greet_hop()
			sp.glints(n)
