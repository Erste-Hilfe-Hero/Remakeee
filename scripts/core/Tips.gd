class_name Tips
extends RefCounted
## First-time tips, shown once each in context instead of an up-front tutorial.
## Seen tips are world flags ("tip_<id>"), so they are saved with the game.
## Players can switch tips off in Settings.

const LINES: Dictionary[String, Array] = {
	"battle": ["Tip: Each art costs Energy (E). Your Spirling starts with 10 and gains 1 every turn.",
		"If it runs dry, it rests a turn to recover."],
	"bond": ["Tip: To bond with a wild Spirling, wear it down first, then pick Bond.",
		"A worn-out or statused Spirling trusts you more easily."],
	"wild_area": ["Tip: Wild Spirlings hide in ferns, reeds and loose scree. Walk through them to meet one."],
	"goals": ["Tip: Open the menu (=) and pick Goals to see where to go next."],
	"gear": ["Tip: Wayfarer Gear works where you can't walk. Face the spot and press A, or tap it."],
}

static func flag(id: String) -> String:
	return "tip_" + id

## The lines for [param id] if it should show now (and marks it seen), else [].
static func take(id: String) -> Array[String]:
	var out: Array[String] = []
	if not GameState.tips_enabled or not LINES.has(id) or GameState.has_flag(flag(id)):
		return out
	GameState.set_flag(flag(id))
	for l: Variant in LINES[id]:
		out.append(str(l))
	return out
