@tool
extends EditorPlugin
## Puts the Google Play in-app update plugin into Android exports (docs/LIVE_CONTENT.md). The AAR
## is built in CI by tools/build_appupdate_plugin.sh; without it (local exports) the game falls
## back to the store-link dialog.

const AAR: String = "res://addons/chimora_appupdate/bin/chimora_appupdate-release.aar"
## Play In-App Updates library, the same as plugins/chimora_appupdate/android/build.gradle.
const APP_UPDATE: String = "com.google.android.play:app-update:2.1.0"

var _export: AppUpdateExport

func _enter_tree() -> void:
	_export = AppUpdateExport.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null

class AppUpdateExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "ChimoraAppUpdate"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid and FileAccess.file_exists(AAR)

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		# Godot looks for Android libraries relative to res://addons/.
		return PackedStringArray([AAR.trim_prefix("res://addons/")])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([APP_UPDATE])
