extends Node
## Headless sanity battle: Kindlop vs Mossling, prints to output.
func _ready() -> void:
	Database.load_all()
	var a := Spirling.new(Database.spirlings["Kindlop"], 8)
	var b := Spirling.new(Database.spirlings["Mossling"], 8)
	var mv: MoveData = Database.moves["Ember Snap"]
	var r := DamageCalc.compute(a, b, mv)
	print("%s used %s on %s: %d dmg (x%.2f)%s" % [a.data.species_name, mv.move_name, b.data.species_name, r.damage, r.eff, " CRIT" if r.crit else ""])
	print("Bond chance at full HP, perfect timing: %.2f" % BondCalc.chance(b, 1.0))
