extends GutTest
## Set phrases per context and safer names (plan area 7, items 2876-2878). The same rules as
## supabase/migrations/20261110000013_phrases_names.sql and tools/online/sql_test/test_phrases_names.sql.

func test_every_context_uses_known_phrases_and_the_server_has_the_same_lists() -> void:
	for ctx: String in ["post", "duel", "bund", "raid"]:
		assert_false(Phrases.allowed(ctx).is_empty(), ctx)
		for n: Variant in Phrases.allowed(ctx):
			assert_true(int(n) >= 0 and int(n) < Phrases.LIST.size(), "%s: phrase %s exists" % [ctx, n])
	assert_eq(Phrases.allowed("post").size(), Phrases.LIST.size(), "the post can use every phrase")
	assert_false(Phrases.allowed("duel").has(8), "no gift phrase in a duel")
	var sql: String = FileAccess.get_file_as_string("res://supabase/migrations/20261110000013_phrases_names.sql")
	var at: int = sql.find("('phrases_allowed', '") + 21
	var lists: Variant = JSON.parse_string(sql.substr(at, sql.find("')", at) - at))
	for ctx: String in Phrases.CONTEXTS:
		assert_eq((lists[ctx] as Array).map(func(x: Variant) -> int: return int(x)), Phrases.CONTEXTS[ctx], ctx)

func test_the_server_checks_the_post_list() -> void:
	var s := LocalBackend.new()
	var codes: Dictionary = {}
	for who: String in ["ann", "ben"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.call_fn("friend_request", {"p_code": codes.ann})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": codes.ben, "p_accept": true})
	assert_true(bool(s.call_fn("mail_send", {"p_code": codes.ben, "p_kind": "phrase", "p_phrase": 3}).data.ok))
	assert_eq(s.call_fn("mail_send", {"p_code": codes.ben, "p_kind": "phrase", "p_phrase": 20}).data.error, "bad_phrase")
	assert_true(s.phrase_ok("duel", 12))
	assert_false(s.phrase_ok("duel", 8))
	assert_false(s.phrase_ok("nowhere", 0))

func test_names_never_carry_phone_numbers_or_addresses() -> void:
	assert_eq(LocalBackend.clean_name("Mara 123", "ABCDEFGH"), "Mara 123")
	assert_eq(LocalBackend.clean_name("Mara 1234", "ABCDEFGH"), "Wanderer EFGH", "4 digits")
	assert_eq(LocalBackend.clean_name("0 1 7 2 9", "ABCDEFGH"), "Wanderer EFGH", "digits with spaces count too")
	assert_eq(LocalBackend.clean_name("wwwmara", "ABCDEFGH"), "Wanderer EFGH")
	assert_eq(LocalBackend.clean_name("Http Ann", "ABCDEFGH"), "Wanderer EFGH")
	assert_eq(LocalBackend.clean_name("mara@x", "ABCDEFGH"), "Wanderer EFGH")
	assert_eq(LocalBackend.clean_name("Wendy", "ABCDEFGH"), "Wendy")
