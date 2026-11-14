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
##   matchup tones, boss entrance and phase, rule seal, partner, calm rule, defeat (683-720);
## - the ambience loop of a Resonance field under the battle (684);
## - optional damage numbers in white with an ink rim (671, 672);
## - the end-of-battle report card (661).
## Static helpers (night tint of the backdrop, short intro on a rematch, the lone boss's size,
## the effect budget) serve BattleScene and ElementFx.

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
## Ambience that played before the first field took over the loop ("" = none taken).
var _ambience_before: String = ""
var _field_ambience: bool = false
## Damage numbers shown so far (tests).
var numbers: Array[String] = []
## The report card at the end, while it shows.
var outro_panel: PanelContainer
signal _outro_closed

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
	Sound.duck_music(false)

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
			# Item 900: the weak point and the rage get their own words, not a second "awakens".
			if bool(e.data.get("rage", false)):
				return "%s rages" % str(e.data.get("name", ""))
			if bool(e.data.get("weak", false)):
				return "%s lies open" % str(e.data.get("name", ""))
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

## Intro share for [param m] from the saved memory; a Rift boss at full speed keeps only the
## short opening too (item 424).
static func intro_share_for(m: BattleModel) -> float:
	var share: float = intro_share(GameState.records.get(SEEN_KEY, {}) as Dictionary, intro_key(m))
	if m != null and short_boss_intro(BattleRules.BOSSES.has(m.foe_boss), GameState.battle_speed_scale()):
		share = minf(share, clampf(float(cfg().get("quick_intro", 0.4)), 0.05, 1.0))
	return share

## True when a Rift boss's entrance runs short (item 424): at boss_short_speed (4x) and up.
static func short_boss_intro(boss: bool, speed: float) -> bool:
	return boss and speed >= float(cfg().get("boss_short_speed", 4.0))

## The one short line of a boss entrance at full speed (item 424); the boss's name goes on the
## name tag, so only how often it acts is left to read.
static func boss_short_line(e: BattleEvent) -> String:
	var acts: int = int(e.data.get("actions", 1))
	return "It acts %d times each turn." % acts if acts > 1 else "It acts once each turn."

## How much bigger a lone Rift boss's wind-up, lunge and knockback reach (item 423), at least 1.
static func boss_motion() -> float:
	return maxf(1.0, float(cfg().get("boss_motion", 1.0)))

## A lone Rift boss in the formation stands bigger (655): its slot [param r] grows from the top
## right corner to boss_size pixels of [param era], never below [param bottom_max] and never
## smaller than the slot. Era IV/V (0) keep their stage.
static func boss_rect(r: Rect2, era: int, bottom_max: float) -> Rect2:
	var want: float = float((cfg().get("boss_size", {}) as Dictionary).get(str(era), 0))
	var s: float = floorf(minf(minf(want, bottom_max - r.position.y), r.end.x))
	if s <= r.size.x:
		return r
	return Rect2(Vector2(r.end.x - s, r.position.y), Vector2(s, s))

## Redraws a second for element effects (664): fx_budget fps on a phone or in battery saver,
## 0 (every frame) elsewhere.
static func fx_fps(mobile: bool, battery: bool) -> int:
	if not mobile and not battery:
		return 0
	return maxi(int((cfg().get("fx_budget", {}) as Dictionary).get("fps", 30)), 0)

## Particles one effect draws of a kind: [param n], at most fx_budget max_particles (664).
static func fx_particles(n: int) -> int:
	return clampi(n, 1, maxi(int((cfg().get("fx_budget", {}) as Dictionary).get("max_particles", 16)), 1))

## True when an effect at [param elapsed] seconds needs a redraw after the one at [param last]
## with [param fps] redraws a second (0 = always).
static func fx_redraw(elapsed: float, last: float, fps: int) -> bool:
	return fps <= 0 or last < 0.0 or floorf(elapsed * fps) != floorf(last * fps)

## Text of the damage number for [param e] (671): the amount of a hit when the option is on.
static func damage_number(e: BattleEvent, enabled: bool) -> String:
	if not enabled or e.type != BattleEvent.Type.DAMAGE:
		return ""
	var amount: int = int(e.data.get("amount", 0))
	return str(amount) if amount > 0 else ""

## Ambience loop under [param field] (684), "" for none.
static func field_ambience(field: String) -> String:
	return str((BattleAudio.cfg().get("field_ambience", {}) as Dictionary).get(field, ""))

## Lines of the report card (661): the battle report of BattleInfo.
static func outro_lines(report: Dictionary, turns: int) -> Array[String]:
	return BattleInfo.report_lines(report, turns)

## Seconds the report card stays at battle speed [param speed].
static func outro_time(speed: float) -> float:
	return float((cfg().get("outro", {}) as Dictionary).get("time", 2.4)) / maxf(speed, 1.0)

## Glints of the winners' pose in [param era].
static func victory_glints(era: int) -> int:
	return int((cfg().get("victory_glints", {}) as Dictionary).get(str(era), 0))

# --- Events ---------------------------------------------------------------------------------

func on_event(e: BattleEvent) -> void:
	var side: int = int(e.data.get("side", 0))
	var slot: int = int(e.data.get("slot", 0))
	var title: String = banner_title(e)
	if not title.is_empty():
		show_banner(title, e.type == BattleEvent.Type.BOSS_PHASE)
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
			show_number(side, slot, damage_number(e, GameState.damage_numbers))
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
			_field_layer(field_ambience(str(e.data.get("field", ""))))
		BattleEvent.Type.FIELD_END:
			BattleAudio.play(BattleAudio.field_sound(true, field_on))
			field_on = false
			_field_layer("")
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

## A Resonance field lays its ambience under the battle, kept low like the map's (684); the
## map's loop comes back when the field ends.
func _field_layer(loop: String) -> void:
	if not _field_ambience:
		if loop.is_empty():
			return
		_ambience_before = Sound.current_ambience
		_field_ambience = true
	var next: String = loop if not loop.is_empty() else _ambience_before
	if loop.is_empty():
		_field_ambience = false
	Sound.ambience(next, true)

## A damage number rises off the Spirling at [param side]/[param slot] and fades (671, 672):
## white with an ink rim, on whole pixels, never waited for.
func show_number(side: int, slot: int, text: String) -> void:
	if text.is_empty():
		return
	numbers.append(text)
	var sp: SpirlingSprite = scene._sprite(side, slot) if scene != null else null
	if sp == null or not sp.visible or not is_inside_tree():
		return
	var l := Label.new()
	l.name = "damage_number"
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", UITheme.INK)
	l.add_theme_constant_override("outline_size", 2)
	scene._shake_root.add_child(l)
	l.reset_size()
	l.position = (sp.position + Vector2((sp.size.x - l.size.x) / 2.0, sp.size.y * 0.2)).round()
	var d: Dictionary = cfg().get("damage_numbers", {})
	var time: float = float(d.get("time", 0.7)) / Juice.speed()
	var tw: Tween = l.create_tween().set_parallel(true)
	if not Juice.reduced():
		Juice.shaped(tw.tween_property(l, "position:y", l.position.y - float(d.get("rise", 8)), time), "fade")
	Juice.shaped(tw.tween_property(l, "modulate:a", 0.0, time * 0.4), "fade").set_delay(time * 0.6)
	tw.chain().tween_callback(l.queue_free)

## The report card at the end of the battle (661): the battle report over the field for a
## moment; a tap or A closes it sooner.
func play_outro(lines: Array[String]) -> void:
	if lines.is_empty() or scene == null or scene._field == null or not is_inside_tree():
		return
	outro_panel = PanelContainer.new()
	outro_panel.name = "outro"
	outro_panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	outro_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var l := Label.new()
	l.text = "\n".join(lines)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(scene._field.size.x - 16.0, 0)
	outro_panel.add_child(l)
	scene._field.add_child(outro_panel)
	outro_panel.reset_size()
	outro_panel.position = ((scene._field.size - outro_panel.size) / 2.0).round()
	outro_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if TapInput.is_press(ev):
			_outro_closed.emit())
	get_tree().create_timer(outro_time(GameState.battle_speed_scale())).timeout.connect(func() -> void: _outro_closed.emit())
	await _outro_closed
	if is_instance_valid(outro_panel):
		outro_panel.queue_free()
	outro_panel = null

func _unhandled_input(event: InputEvent) -> void:
	if outro_panel != null and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_outro_closed.emit()

## Seconds a banner with [param text] stays at battle speed [param speed] (items 899, 900):
## banner_time scaled by the speed, but never less than banner_read.min plus banner_read.per_char
## for each letter, so a field or boss phase banner can be read at 4x too.
static func banner_seconds(text: String, speed: float) -> float:
	var read: Dictionary = cfg().get("banner_read", {})
	var least: float = float(read.get("min", 0.9)) + float(read.get("per_char", 0.035)) * text.length()
	return maxf(float(cfg().get("banner_time", 1.1)) / maxf(speed, 0.01), least)

## Shows [param title] on the show banner for banner_seconds. [param phase]: a boss phase, drawn
## with the split seal so it reads apart from a field banner.
func show_banner(title: String, phase: bool = false) -> void:
	banners.append(title)
	if banner == null or scene._field == null:
		return
	var shown: String = Loc.t(title)
	banner.show_rule(shown, phase, scene._field.size.x, roundf(scene._field.size.y * 0.42))
	_banner_id += 1
	var id: int = _banner_id
	if not is_inside_tree():
		return
	await get_tree().create_timer(banner_seconds(shown, Juice.speed())).timeout
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
