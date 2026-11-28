class_name TvRemote
extends RefCounted
## Samsung TV (Tizen web app) support. The TV page sets window.CHIMORA_TV and calls
## window.chimoraTvBack() on the remote's Back key; that works exactly like the Android back
## button (BackButton.gd): B in menus, pause menu in the world, "Quit Chimora?" on the title.
## Arrows and OK are plain arrow and Enter key presses, which the game already understands.

static var _back_cb: JavaScriptObject = null
static var _tv: int = -1

## True inside the Samsung TV app (never on phones or in the browser test version).
static func is_tv() -> bool:
	if _tv < 0:
		_tv = 1 if OS.has_feature("web") and bool(JavaScriptBridge.eval("!!window.CHIMORA_TV", true)) else 0
	return _tv == 1

## Hooks the remote's Back key up to the back-button handling. Called once by GameState.
static func install(tree: SceneTree) -> void:
	if not is_tv() or _back_cb != null:
		return
	_back_cb = JavaScriptBridge.create_callback(func(_args: Array) -> void:
		tree.root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST))
	JavaScriptBridge.get_interface("window").chimoraTvBack = _back_cb

## Leaves the game; on the TV the app is closed through Tizen (get_tree().quit() does nothing
## in a web page).
static func quit(tree: SceneTree) -> void:
	if is_tv():
		JavaScriptBridge.eval("try{tizen.application.getCurrentApplication().exit()}catch(e){window.close()}", true)
		return
	tree.quit()

## Opens a web page. On the TV it goes to the TV's own browser through a Tizen app control,
## so the game stays open behind it.
static func open_url(url: String) -> void:
	if not is_tv():
		OS.shell_open(url)
		return
	JavaScriptBridge.eval("try{tizen.application.launchAppControl(new tizen.ApplicationControl('http://tizen.org/appcontrol/operation/view'," + JSON.stringify(url) + "),null,function(){},function(){})}catch(e){}", true)
