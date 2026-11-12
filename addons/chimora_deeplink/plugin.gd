@tool
extends EditorPlugin
## Android exports open chimora:// links (scripts/core/DeepLink.gd). Godot copies the filter onto
## the exported launcher alias of the game activity. iOS gets its URL type from
## application/additional_plist_content in export_presets.cfg.

const INTENT_FILTER: String = """
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="chimora" />
            </intent-filter>
"""

var _export: DeepLinkExport

func _enter_tree() -> void:
	_export = DeepLinkExport.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null

class DeepLinkExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "ChimoraDeepLink"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_manifest_activity_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return INTENT_FILTER
