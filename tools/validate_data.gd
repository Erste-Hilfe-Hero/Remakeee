extends SceneTree
## Headless data check for CI:
##   godot --headless --path . -s res://tools/validate_data.gd
## Exits with code 1 if any JSON reference is broken.
## The validators are loaded at run time: compiling them together with this script would
## fail, because the autoloads they use (Online, ...) only exist once the tree is running.

func _initialize() -> void:
	var errors: PackedStringArray = load("res://scripts/core/DataValidator.gd").call("validate")
	errors.append_array(load("res://scripts/core/WorldValidator.gd").call("validate"))
	errors.append_array(PackedStringArray(load("res://scripts/shop/ShopCatalog.gd").call("validate")))
	for e: String in errors:
		printerr("DATA ERROR: " + e)
	if errors.is_empty():
		print("Data OK")
		print(load("res://scripts/core/WorldValidator.gd").call("region_summary"))
	quit(1 if not errors.is_empty() else 0)
