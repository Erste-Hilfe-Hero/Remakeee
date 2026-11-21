class_name MapBookMenu
extends RefCounted
## Mirela's map book as its own menu (plan item 1751): a list of the pages found so far,
## each one readable again. Pages read once are marked as read (flag page_<n>_read).

static func page_flag(n: int) -> String:
	return "page_%d" % n

static func read_flag(n: int) -> String:
	return "page_%d_read" % n

## Rows for the page list: found pages by number, "new" until read.
static func rows(flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(1, Overworld.PAGE_COUNT + 1):
		if not bool(flags.get(page_flag(i), false)):
			continue
		var row: Dictionary = {"text": "Page %d" % i, "page": i}
		if not bool(flags.get(read_flag(i), false)):
			row.text = "Page %d (new)" % i
		out.append(row)
	return out

static func title(flags: Dictionary) -> String:
	return "Mirela's map book (%d/%d)" % [Overworld.pages_found(flags), Overworld.page_total(flags)]

static func page_text(n: int) -> String:
	var lines: Array[String] = Dialogue.lines_for(Dialogue.get_entry("story/page_%d" % n), GameState.flags)
	var shown: PackedStringArray = []
	for l: String in lines:
		shown.append(Loc.t(l))
	return "\n".join(shown)

## Runs the menu on [param host] (a MenuHost such as the pause menu).
static func run(host: MenuHost) -> void:
	while true:
		var list: Array[Dictionary] = rows(GameState.flags)
		if list.is_empty():
			await host.info("No pages yet. The storm blew them across the valley.")
			return
		var idx: int = await host.pick(title(GameState.flags), list)
		if idx < 0:
			return
		var n: int = int(list[idx].page)
		GameState.set_flag(read_flag(n))
		await host.info(page_text(n))
