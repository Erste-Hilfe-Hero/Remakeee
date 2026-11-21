@tool
extends EditorPlugin
## Puts the local notification plugin into Android exports (plan Chimora 100, item 76). The AAR is
## built in CI by tools/build_notify_plugin.sh; without it (local exports) LocalNotify.gd finds no
## plugin, never asks and schedules nothing.

const AAR: String = "res://addons/chimora_notify/bin/chimora_notify-release.aar"
## AndroidX Core (NotificationCompat), the same as plugins/chimora_notify/android/build.gradle.
const CORE: String = "androidx.core:core:1.13.1"

var _export: NotifyExport

func _enter_tree() -> void:
	_export = NotifyExport.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null

class NotifyExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "ChimoraNotify"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid and FileAccess.file_exists(AAR)

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		# Godot looks for Android libraries relative to res://addons/.
		return PackedStringArray([AAR.trim_prefix("res://addons/")])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([CORE])
