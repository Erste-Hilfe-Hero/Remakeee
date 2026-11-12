extends GutTest

const STAGE2: Array[String] = ["Veskara", "Siltarra", "Cindrel", "Nibquill", "Filigrace"]

func _scale(n: String, f: float) -> void:
	var sd: SpirlingData = Database.species(n)
	sd.base_hp = roundi(sd.base_hp * f)
	sd.base_atk = roundi(sd.base_atk * f)
	sd.base_def = roundi(sd.base_def * f)
	sd.base_foc = roundi(sd.base_foc * f)
	sd.base_spd = roundi(sd.base_spd * f)

func _report(label: String, battles: int = 0) -> void:
	if battles == 0:
		battles = maxi(200, Database.spirlings.size() * 6)
	var r: Dictionary = BalanceSim.run_team(36, battles, 7)
	var rows: Array = []
	for n: String in r.species:
		var row: Dictionary = r.species[n]
		rows.append([BalanceSim.win_rate(row), n, int(row.wins), int(row.wins) + int(row.losses) + int(row.draws)])
	rows.sort()
	var top: Array = rows.slice(rows.size() - 4)
	var low: Array = rows.slice(0, 2)
	var mine: Array = rows.filter(func(x: Array) -> bool: return STAGE2.has(x[1]))
	print("PROBE %s draws=%d top=%s low=%s mine=%s" % [label, int(r.draws), str(top), str(low), str(mine)])

func test_probe() -> void:
	Database.reload_data()
	for sd: SpirlingData in Database.spirlings.values():
		if sd.region == "quillmarch":
			sd.rarity = "ancient"
	_report("no-quillmarch", (Database.spirlings.size() - 15) * 6)
	for f: float in [0.97, 0.95, 0.92, 0.9]:
		Database.reload_data()
		_scale("Sluicewarden", f)
		_report("Sluicewarden*%.2f" % f)
	for f: float in [0.95, 0.9]:
		Database.reload_data()
		_scale("Sluicewarden", f)
		_scale("Sluicer", f)
		_scale("Fulgorath", 0.97)
		_report("Sluice+Fulg %.2f" % f)
	assert_true(true)
