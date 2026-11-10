extends GutTest
## Settings > Legal offers "Join our Discord" and opens the community invite.

var _open: Callable
var _opened: Array[String] = []

func before_each() -> void:
	_open = MenuHost.open_url
	_opened.clear()
	MenuHost.open_url = func(url: String) -> void: _opened.append(url)

func after_each() -> void:
	MenuHost.open_url = _open

func test_url_is_the_invite() -> void:
	assert_eq(MenuHost.DISCORD_URL, "https://discord.gg/e69SM39rKK")

func test_legal_row_opens_discord() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var done: Array[bool] = [false]
	var runner := func() -> void:
		await host.run_legal()
		done[0] = true
	runner.call()
	await wait_process_frames(1)
	assert_true(host.last_rows.has("Join our Discord"))
	host.picker.picked.emit(host.last_rows.find("Join our Discord"))
	await wait_process_frames(2)
	assert_eq(_opened, [MenuHost.DISCORD_URL] as Array[String])
	host.picker.picked.emit(-1)
	await wait_process_frames(2)
	assert_true(done[0])

func test_label_has_german() -> void:
	assert_eq(str(Loc.load_table("de").strings.get("Join our Discord", "")), "Tritt unserem Discord bei")
