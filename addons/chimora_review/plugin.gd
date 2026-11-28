@tool
extends EditorPlugin
## Puts the Google Play In-App Review plugin into Android exports (plan Chimora 100, item 75). The
## AAR is built in CI by tools/build_review_plugin.sh; without it (local exports) ReviewAsk.gd
## finds no plugin and never asks.

const AAR: String = "res://addons/chimora_review/bin/chimora_review-release.aar"
## Play In-App Review library, the same as plugins/chimora_review/android/build.gradle.
const REVIEW: String = "com.google.android.play:review:2.0.2"

var _export: ReviewExport

func _enter_tree() -> void:
	_export = ReviewExport.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null

class ReviewExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "ChimoraReview"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid and FileAccess.file_exists(AAR)

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		# Godot looks for Android libraries relative to res://addons/.
		return PackedStringArray([AAR.trim_prefix("res://addons/")])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([REVIEW])
