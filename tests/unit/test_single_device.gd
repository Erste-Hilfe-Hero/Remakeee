extends GutTest
## Plan area 7, item 3010 on the local stand-in of the server: one device at a time. The same
## cases as tools/online/sql_test/test_single_device.sql.

var s: LocalBackend

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})

func _claim(token: String) -> Dictionary:
	s.device_token = token
	return s.call_fn("session_claim", {"p_token": token}).data

func _put(base: int) -> Dictionary:
	return s.call_fn("save_put", {"p_slot": 1, "p_data": {"schema": 1, "play_time": 10 + base, "money": 3000},
		"p_summary": "x", "p_base_rev": base})

func test_the_newest_device_plays() -> void:
	var a: String = str(_claim("").token)
	assert_eq(a.length(), 32)
	assert_eq(str(_claim(a).token), a, "the same device keeps its token")
	assert_true(bool(_put(0).data.ok), "the newest device saves")
	var b: String = str(_claim("").token)
	assert_ne(b, a, "a new device gets a new token")
	# Phone A again.
	s.device_token = a
	assert_true(bool(s.call_fn("presence", {"p_place": "Ashdown"}).data.other_device), "the old device hears it")
	assert_eq(str(_claim(a).error), "other_device", "the old device cannot take it back by itself")
	var r: Dictionary = _put(1)
	assert_false(r.ok)
	assert_eq(r.error, "other_device", "the old device cannot save")
	# Phone B.
	s.device_token = b
	assert_false(bool(s.call_fn("presence", {"p_place": "Ashdown"}).data.other_device))
	assert_true(bool(_put(1).data.ok), "the new device saves")
	# An old build sends no token.
	s.device_token = ""
	assert_true(bool(_put(2).data.ok), "no token: not checked")

func test_online_goes_to_the_title_and_asks() -> void:
	assert_eq(OnlineErrors.kind("other_device"), "other_device")
	assert_eq(OnlineErrors.text("other_device"), OnlineErrors.OTHER_DEVICE)
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/TitleScreen.gd")
	assert_true(src.contains("Online.kicked"), "the title asks before taking the account back")
	assert_true(FileAccess.get_file_as_string("res://scripts/online/SupabaseBackend.gd").contains("x-chimora-session: "),
		"the real backend sends the token")
