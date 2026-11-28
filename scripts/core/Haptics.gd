extends Node
## Autoload "Haptics": short vibrations on phones and rumble on gamepads (items 2587 to 2591).
##   Haptics.play("hit")
## Strength follows the Vibration setting (Off / Weak 50 % / Full) and reduced motion turns it off.

## Fixed patterns: pulses of [milliseconds, strength 0..1], and the pause between pulses.
const PATTERNS: Dictionary = {
	"tap": {"pulses": [[10, 0.3]], "gap_ms": 0},
	"confirm": {"pulses": [[15, 0.5]], "gap_ms": 0},
	"hit": {"pulses": [[25, 0.7]], "gap_ms": 0},
	"heavy": {"pulses": [[45, 1.0]], "gap_ms": 0},
	"error": {"pulses": [[15, 0.6], [15, 0.6]], "gap_ms": 40},
}

## Pulses actually sent, newest last (for tests; holds the last few only).
var sent: Array = []
const LOG_KEEP: int = 8

## Vibration strength from the settings (0, 0.5 or 1), 0 under reduced motion.
func strength() -> float:
	if GameState.reduce_motion:
		return 0.0
	return Juice.LEVEL_SCALES[clampi(GameState.vibration, 0, Juice.LEVEL_SCALES.size() - 1)]

## Plays a named pattern. Unknown names and "Off" do nothing.
func play(pattern: String) -> void:
	var p: Variant = PATTERNS.get(pattern)
	var k: float = strength()
	if p == null or k <= 0.0:
		return
	var pulses: Array = (p as Dictionary).pulses
	for i: int in pulses.size():
		if i > 0 and is_inside_tree():
			await get_tree().create_timer(float((p as Dictionary).gap_ms) / 1000.0, true, false, true).timeout
		_pulse(int(pulses[i][0]), float(pulses[i][1]) * k)

func _pulse(ms: int, amount: float) -> void:
	sent.append([ms, amount])
	if sent.size() > LOG_KEEP:
		sent.pop_front()
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, clampf(amount, 0.0, 1.0))
	for d: int in Input.get_connected_joypads():
		Input.start_joy_vibration(d, amount * 0.5, amount, ms / 1000.0)
