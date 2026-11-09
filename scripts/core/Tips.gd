class_name Tips
extends RefCounted
## First-time tips, shown once each in context instead of an up-front tutorial.
## Seen tips are world flags ("tip_<id>"), so they are saved with the game.
## Players can switch tips off in Settings. Seen tips can be read again under Goals -> Guide
## (plan item 1985). A line can be {"touch": ..., "buttons": ...}: the words follow the
## input in use, "Tap" on a touch screen, "Press A" with a gamepad or keyboard (item 1987).

const LINES: Dictionary[String, Array] = {
	"battle": ["Tip: Each art costs Energy (E). Your Spirling starts with 10 and gains 1 every turn.",
		"If it runs dry, it rests a turn to recover."],
	"bond": ["Tip: To bond with a wild Spirling, wear it down first, then pick Bond.",
		"A worn-out or statused Spirling trusts you more easily.",
		"Bonding step 1: Hit it with a few arts until its Vigor bar is low. Don't knock it out.",
		"Bonding step 2: Pick Bond. A big Mine! button appears.",
		{"touch": "Bonding step 3: Tap Mine! as fast as you can. The fuller the bar, the better the bond.",
			"buttons": "Bonding step 3: Press A as fast as you can. The fuller the bar, the better the bond."},
		"Bonding step 4: Hold out a Kin Charm when asked. It steadies the link. You start with 20 of them.",
		"While you are new, a failed bond does not give the wild Spirling a free hit."],
	"wild_area": ["Tip: Wild Spirlings hide in ferns, reeds and loose scree. Walk through them to meet one."],
	"goals": ["Tip: Open the menu (=) and pick Goals to see where to go next."],
	"gear": [{"touch": "Tip: Wayfarer Gear works where you can't walk. Face the spot and tap it.",
		"buttons": "Tip: Wayfarer Gear works where you can't walk. Face the spot and press A."}],
	"walk": [{"touch": "Walk: D-pad or tap a tile", "buttons": "Walk: D-pad or left stick"}],
	"menu": [{"touch": "Tip: Tap = to open the menu: team, satchel, goals and saving.",
		"buttons": "Tip: Press Start to open the menu: team, satchel, goals and saving."}],
	"save": ["Tip: The game saved itself. It saves when you change places, and you can save any time under Save in the menu."],
	"team_order": ["Tip: The first Spirling in Team goes out first.",
		"Pick one and choose Lead the team or Move to slot."],
	"rest_spot": ["Tip: Rest spots heal your whole team for free.",
		"After a hard fight, you wake at the last one you used."],
	"travel": ["Tip: Travel in the menu takes you to rest spots you have already visited."],
	"satchel": [{"touch": "Tip: The satchel sorts items by tab. Tap a tab or slide left and right.",
		"buttons": "Tip: The satchel sorts items by tab. Press left or right to switch tabs."}],
	"keepsake": ["Tip: A keepsake helps the Spirling who holds it.",
		"Give it under Team: pick a Spirling, then Keepsake."],
	"unfurl": ["Tip: This Spirling can unfurl into a new form.",
		"You can furl it back later, nothing is lost."],
	"friends": ["Tip: Share your friend code so friends can send gifts and meet your echo."],
	"storage": ["Tip: Spirlings who aren't travelling with you rest in storage. Swap them any time here."],
	"map_page": ["Tip: You found a page of Mirela's map book. Goals shows how many are still out there."],
}

## Headings for the Guide, in the order shown.
const TOPICS: Dictionary[String, String] = {
	"walk": "Walking", "menu": "The menu", "save": "Saving", "goals": "Goals", "wild_area": "Wild Spirlings",
	"battle": "Energy in battle", "bond": "Bonding", "team_order": "Team order",
	"rest_spot": "Rest spots", "travel": "Travel", "satchel": "The satchel", "keepsake": "Keepsakes",
	"unfurl": "Unfurling", "gear": "Wayfarer Gear", "friends": "Friends", "storage": "Storage",
	"map_page": "Map pages",
}

## True when the player uses the touch screen (no gamepad connected).
static func touch_mode() -> bool:
	return (DisplayServer.is_touchscreen_available() or VirtualPad.force_visible) and Input.get_connected_joypads().is_empty()

## The lines of [param id] in the words for the input in use, without marking them seen.
static func lines_of(id: String, touch: bool = touch_mode()) -> Array[String]:
	var out: Array[String] = []
	for l: Variant in LINES.get(id, []):
		if l is Dictionary:
			out.append(str((l as Dictionary).get("touch" if touch else "buttons", "")))
		else:
			out.append(str(l))
	return out

## Tips already shown, in Guide order.
static func seen() -> Array[String]:
	var out: Array[String] = []
	for id: String in TOPICS:
		if GameState.has_flag(flag(id)):
			out.append(id)
	return out

static func flag(id: String) -> String:
	return "tip_" + id

## The lines for [param id] if it should show now (and marks it seen), else [].
static func take(id: String) -> Array[String]:
	var out: Array[String] = []
	if not GameState.tips_enabled or not LINES.has(id) or GameState.has_flag(flag(id)):
		return out
	GameState.set_flag(flag(id))
	return lines_of(id)
