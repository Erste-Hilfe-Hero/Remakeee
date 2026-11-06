extends SceneTree
## Battle referee runner (plan area 7, items 2687-2690). Started by server/referee/run.sh:
##   godot --headless --path <game> -s res://server/referee/referee.gd -- check in.json out.json
## in.json is a list of {"id", "replay", "claim"} from battle_queue; out.json gets one
## {"id", "verdict", "detail"} per battle. The work itself is BattleReferee (scripts/battle/).
##   ... -- sample out.json   writes test battles (one honest, one tampered, one broken).

func _initialize() -> void:
	Database.load_all()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var code: int = 2
	if args.size() == 3 and args[0] == "check":
		code = _check(args[1], args[2])
	elif args.size() == 2 and args[0] == "sample":
		code = _sample(args[1])
	else:
		printerr("usage: -- check in.json out.json | -- sample out.json")
	quit(code)

func _check(in_path: String, out_path: String) -> int:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(in_path))
	if not raw is Array:
		printerr("referee: input is not a list")
		return 1
	var out: Array = []
	for row: Variant in raw:
		if not row is Dictionary or not (row as Dictionary).has("id"):
			continue
		var r: Dictionary = BattleReferee.check(row.get("replay"), row.get("claim"))
		out.append({"id": int(row.id), "verdict": r.verdict, "detail": r.detail})
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		return 1
	f.store_string(JSON.stringify(out))
	print("referee: %d battles checked" % out.size())
	return 0

func _sample(out_path: String) -> int:
	var mine: Array[Spirling] = [Spirling.new(Database.species("Kindlop"), 14), Spirling.new(Database.species("Puddlet"), 12)]
	var foes: Array[Spirling] = [Spirling.new(Database.species("Mossling"), 13)]
	var model := BattleModel.new(mine, foes, false, 777, 1)
	var snap: Dictionary = BattleReplay.snapshot(model, "battle", "field")
	var ai := BattleAI.new(1)
	model.start()
	var guard: int = 0
	while not model.is_finished() and guard < 200:
		guard += 1
		if model.needs_player_switch():
			var idx: int = model.swap_candidates(BattleModel.Side.PLAYER)[0]
			snap.inputs.append(BattleReplay.switch_to_dict(idx))
			model.submit_switch(idx)
			continue
		var a: BattleAction = ai.choose(model, BattleModel.Side.PLAYER)
		snap.inputs.append(BattleReplay.action_to_dict(a))
		model.submit_turn(a)
	var honest: Dictionary = BattleReferee.claim_of(model)
	var tampered: Dictionary = honest.duplicate(true)
	tampered.hp[0][0] = int(tampered.hp[0][0]) + 50
	var rows: Array = [{"replay": snap, "claim": honest}, {"replay": snap, "claim": tampered},
		{"replay": {"teams": [[{"species": "Nobody"}], [{"species": "Puddlet"}]]}, "claim": honest}]
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		return 1
	f.store_string(JSON.stringify(rows))
	return 0
