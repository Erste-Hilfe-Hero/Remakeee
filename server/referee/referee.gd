extends SceneTree
## Battle referee runner (plan area 7, items 2687-2690). Started by server/referee/run.sh:
##   godot --headless --path <game> -s res://server/referee/referee.gd -- check in.json out.json
## in.json is a list of {"id", "replay", "claim"} from battle_queue; out.json gets one
## {"id", "verdict", "detail"} per battle. The work itself is BattleReferee (scripts/battle/).
##   ... -- sample out.json   writes test battles (one honest, one tampered, one broken).
##   ... -- fair out.json     writes the fair league row of every species, so a test can compare
##                            it with the database's _league_fair_row (plan item 2748).
## The work is done by referee_runner.gd, loaded once the autoloads exist.

func _initialize() -> void:
	root.add_child.call_deferred((load("res://server/referee/referee_runner.gd") as GDScript).new())
