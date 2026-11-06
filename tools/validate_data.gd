extends SceneTree
## Headless data check for CI:
##   godot --headless --path . -s res://tools/validate_data.gd
## Exits with code 1 if any JSON reference is broken.

func _init() -> void:
	var errors: PackedStringArray = DataValidator.validate()
	errors.append_array(WorldValidator.validate())
	errors.append_array(ShopCatalog.validate())
	for e: String in errors:
		printerr("DATA ERROR: " + e)
	if errors.is_empty():
		print("Data OK")
	quit(1 if not errors.is_empty() else 0)
