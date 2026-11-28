extends Node
## UI 화면 캡처: 실제 게임 장면을 띄워 메뉴와 경기 화면의 여러 상태를 PNG로 저장한다(디자인 확인용).
##
##   xvfb-run -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 \
##     --resolution 1280x720 res://tests/shots/ui_shots.tscn -- --shot=menu --out=/tmp/ui
##   ... --resolution 1688x780 ... -- --shot=hud --phone --bots=5 --mode=dom --out=/tmp/ui
##
## --phone: 휴대폰처럼(터치 조작, UI 150%) 보이게 한다. 1688x780 창은 가로 휴대폰(844x390)의 두 배다.
## 메뉴: menu, menu_online, menu_settings, loadout / 경기: hud, scoreboard, pause, result.
## 바꾼 설정은 끝날 때 되돌린다.

const MAIN_SCENE := preload("res://game/main.tscn")
const Settings := preload("res://game/core/settings.gd")
const LaunchArgs := preload("res://game/core/launch_args.gd")

var _args := {}
var _game: Node
var _out := "/tmp/ui"
var _prefix := ""
var _saved := {}
var _steps: Array = []
var _wait := 0.0


func _ready() -> void:
	_args = LaunchArgs.parse()
	_out = str(_args.get("out", _out))
	DirAccess.make_dir_recursive_absolute(_out)
	var phone := _args.has("phone")
	_prefix = "phone_" if phone else "desktop_"
	for key: String in [Settings.TOUCH_MODE, Settings.UI_SCALE]:
		_saved[key] = Settings.read(key, "")
	Settings.write(Settings.TOUCH_MODE, "on" if phone else "off")
	Settings.write(Settings.UI_SCALE, 1.5 if phone else 1.0)
	Settings._mobile = 1 if phone else 0
	_game = MAIN_SCENE.instantiate()
	add_child(_game)
	if str(_args.get("shot", "menu")) == "menu":
		_steps = [
			[1.5, _snap.bind("menu")],
			[0.1, _menu_section.bind("online")],
			[0.6, _snap.bind("menu_online")],
			[0.1, _menu_section.bind("settings")],
			[0.6, _snap.bind("menu_settings")],
			[0.1, _menu_section.bind("play")],
			[0.1, _open_loadout],
			[0.8, _snap.bind("loadout")],
			[0.1, _finish],
		]
	else:
		_steps = [
			[0.5, _no_mouse_lock],
			[7.0, _fill_hud],
			[0.6, _snap.bind("hud")],
			[0.1, Input.action_press.bind("scoreboard")],
			[0.5, _snap.bind("scoreboard")],
			[0.1, Input.action_release.bind("scoreboard")],
			[0.1, _pause.bind(true)],
			[0.6, _snap.bind("pause")],
			[0.1, _pause.bind(false)],
			[0.3, _show_result],
			[0.8, _snap.bind("result")],
			[0.1, _finish],
		]


func _process(delta: float) -> void:
	if _steps.is_empty():
		return
	_wait += delta
	var step: Array = _steps[0]
	if _wait < float(step[0]):
		return
	_wait = 0.0
	_steps.pop_front()
	(step[1] as Callable).call()


func _snap(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s%s.png" % [_out, _prefix, shot_name]
	image.save_png(path)
	print("UI SHOT ", path, " ", image.get_size())


func _menu_section(section: String) -> void:
	var menu: Node = _game.call("menu")
	if menu != null and menu.has_method("show_section"):
		menu.call("show_section", section)


func _open_loadout() -> void:
	var menu: Node = _game.call("menu")
	if menu != null:
		menu.call("open_loadout")


func _no_mouse_lock() -> void:
	var player: Node = _game.call("local_player")
	if player != null:
		player.set("require_mouse_capture", false)


## 킬 로그, 경험치 알림, 피격 표시처럼 잠깐 뜨는 것들을 한꺼번에 띄운다.
func _fill_hud() -> void:
	var player: Node = _game.call("local_player")
	if player == null:
		return
	var view: Object = _game.get("_view")
	var hud: Node = player.get("hud")
	view.call("show_kill", hud, 1, 1001, 0, true, 1)
	view.call("show_kill", hud, 1003, 1002, 1, false, 1)
	view.call("show_kill", hud, 1004, 1, 1, false, 1)
	hud.call("show_hit", true, false)
	hud.call("flash_damage")
	hud.call("set_damage_marks", [[0.8, 1.0]])


func _pause(paused: bool) -> void:
	var player: Node = _game.call("local_player")
	if player == null:
		return
	if _game.call("pause_menu") == null:
		_game.call("_add_pause_menu")
	if player.get("touch") != null:
		player.call("set_paused", paused)
	else:
		player.set("require_mouse_capture", paused)


## 판이 끝난 화면: 세션을 멈추고 결과와 점수판을 직접 그린다.
func _show_result() -> void:
	var player: Node = _game.call("local_player")
	if player == null:
		return
	_game.process_mode = Node.PROCESS_MODE_DISABLED
	var view: Object = _game.get("_view")
	var hud: Node = player.get("hud")
	# 경기는 멈춰도 HUD는 실제처럼 돌아야 한다(결과가 뜨면 터치 버튼이 흐려진다).
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	view.call("show_match", hud, [0, 30, 24, 0.0, true, 14, 6, true])
	var rows: Array = _game.call("score_rows") if _game.has_method("score_rows") else []
	if rows.is_empty():
		rows = [
			[1, 0, 14, 6, false, "Soldier3777"], [1001, 0, 9, 7, true, "Viper"],
			[1002, 1, 8, 9, true, "Rook"], [1003, 1, 11, 8, true, "Ghost"],
		]
	view.call("show_scores", hud, rows, 1, true)


func _finish() -> void:
	for key: String in _saved:
		if str(_saved[key]) == "":
			Settings.forget(key)
		else:
			Settings.write(key, _saved[key])
	get_tree().quit()
