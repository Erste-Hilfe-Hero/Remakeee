class_name SettingsReset
extends RefCounted
## "Reset to default" per settings section (200 list item 126). Each section drops its own keys
## from the settings and loads the rest again, so the defaults of GameState.settings_from_dict
## apply and the other sections stay as they are. The language is kept on purpose (a player who
## picked one should not have to find it again in a foreign one); journey choices such as the
## challenge, the Iron Oath and phone notifications are no settings and are not touched.

const GROUP_KEYS: Dictionary[String, Array] = {
	"game": ["text_speed", "battle_speed", "auto_battle", "auto_mode", "bench_xp", "wild_ward", "damage_preview",
		"damage_numbers", "big_buttons", "easy_battle_text", "auto_aim", "bonus_goals", "auto_text", "tips",
		"play_reminder", "goal_line"],
	"sound": ["volume", "music_volume", "sfx_volume", "voice_volume", "ambience_volume", "mono_audio",
		"text_voice", "sound_captions"],
	"controls": ["pad_size", "pad_opacity", "left_handed", "tap_to_move", "always_run", "bond_style", "input_delay",
		"no_rush", "swap_ab_touch", "swap_ab_pad", "tap_vibration", "one_hand", "vibration"],
	"display": ["battery_saver", "reduce_motion", "high_contrast", "color_blind", "large_text", "day_night",
		"weather", "minimap", "screen_shake"],
}

const ROW_TEXT: String = "Reset to default"
const QUESTION: String = "Set every setting on this page back to how it was at the start?"

## Sets the settings of [param group] back to their defaults. False for an unknown group.
static func reset(group: String) -> bool:
	if not GROUP_KEYS.has(group):
		return false
	var d: Dictionary = GameState.settings_to_dict()
	for k: Variant in GROUP_KEYS[group]:
		d.erase(k)
	GameState.settings_from_dict(d)
	if group == "display":
		EraManager.set_retro_filter(0)
	return true
