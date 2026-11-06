@tool
extends EditorPlugin
## Puts the Google Play Billing plugin into Android exports (plan area 10). The AAR is built in
## CI by tools/build_billing_plugin.sh; without it (local exports) the game has no Play store and
## the shop says so.

const AAR: String = "res://addons/chimora_billing/bin/chimora_billing-release.aar"
## Play Billing Library version, the same as plugins/chimora_billing/android/build.gradle.
const BILLING: String = "com.android.billingclient:billing:8.0.0"

var _export: BillingExport

func _enter_tree() -> void:
	_export = BillingExport.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null

class BillingExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "ChimoraBilling"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid and FileAccess.file_exists(AAR)

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		# Godot looks for Android libraries relative to res://addons/.
		return PackedStringArray([AAR.trim_prefix("res://addons/")])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([BILLING])
