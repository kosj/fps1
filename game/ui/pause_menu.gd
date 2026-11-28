extends CanvasLayer
## 일시 정지 화면. Esc로 마우스 잠금이 풀리면 나타난다.
## 네트워크 대전은 멈추지 않으므로 화면만 가리고 조작을 쉰다.
## 계속하기, 감도, 터치 조작 전환은 여기서 직접 내 플레이어에 적용한다.

signal menu_requested

const MenuKit := preload("res://game/ui/menu_kit.gd")
const Settings := preload("res://game/core/settings.gd")
const Armory := preload("res://game/weapons/armory.gd")
const LoadoutPanel := preload("res://game/ui/loadout_panel.gd")
## 계속하기를 누른 뒤 포인터 잠금이 됐는지 확인하기까지의 시간(초).
const CAPTURE_CHECK_TIME := 0.4

## 지금의 내 플레이어를 돌려주는 함수(없으면 null). 세션이 넣어 준다.
var local_player := Callable()
## 주무기를 고르는 함수(번호 -> 바로 바뀌었는지). 세션이 넣어 준다.
var choose_primary := Callable()
var resume_button: Button
var loadout_button: Button
var menu_button: Button

var _capture_check_left := 0.0


func _ready() -> void:
	layer = 10
	var column := MenuKit.centered_column(self, Color(0.0, 0.0, 0.0, 0.55))
	column.add_child(MenuKit.label("PAUSED", 40))
	resume_button = MenuKit.button("RESUME")
	resume_button.pressed.connect(resume)
	column.add_child(resume_button)
	loadout_button = MenuKit.button("LOADOUT")
	loadout_button.pressed.connect(open_loadout)
	column.add_child(loadout_button)
	column.add_child(MenuKit.sensitivity_row(_on_sensitivity_changed))
	column.add_child(MenuKit.ui_scale_row(get_tree()))
	column.add_child(MenuKit.touch_toggle(_on_touch_toggled))
	if Settings.is_mobile():
		column.add_child(MenuKit.label("Left side: move (push fully forward to sprint)", 18))
		column.add_child(MenuKit.label("Right side or FIRE: drag to look", 18))
		column.add_child(MenuKit.label("DUCK while sprinting: slide    JUMP at a ledge: climb", 18))
	else:
		column.add_child(MenuKit.label("WASD move    Shift sprint    Ctrl crouch / slide", 18))
		column.add_child(MenuKit.label("Space jump / mantle    R reload    G grenade", 18))
		column.add_child(MenuKit.label("LMB fire    RMB aim    1 primary / 2 pistol (or wheel)", 18))
	menu_button = MenuKit.button("MAIN MENU")
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	column.add_child(menu_button)


## 로드아웃 화면을 연다. 막 태어났으면 바로, 아니면 다음 리스폰 때 바뀐다.
func open_loadout() -> LoadoutPanel:
	var panel := LoadoutPanel.new()
	var player = _player()
	panel.selected = player.primary if player != null else Armory.DEFAULT_PRIMARY
	panel.chosen.connect(_on_primary_chosen)
	add_child(panel)
	return panel


func _on_primary_chosen(id: int) -> void:
	var now: bool = choose_primary.call(id) if choose_primary.is_valid() else false
	var player = _player()
	if player != null and player.hud != null:
		var when := "" if now else "  (next spawn)"
		player.hud.show_notice("LOADOUT: %s%s" % [Armory.title(id), when])


func _process(delta: float) -> void:
	_check_capture_fallback(delta)


func resume() -> void:
	var player = _player()
	if player != null and player.touch != null:
		player.set_paused(false)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_capture_check_left = CAPTURE_CHECK_TIME


func _player():
	return local_player.call() if local_player.is_valid() else null


func _on_sensitivity_changed(value: float) -> void:
	var player = _player()
	if player != null:
		player.set_sensitivity(value)


func _on_touch_toggled(enabled: bool) -> void:
	var player = _player()
	if player == null:
		return
	player.set_touch(enabled)
	if enabled:
		player.set_paused(true)


## 계속하기를 눌렀는데도 포인터 잠금이 되지 않고 터치 화면이 있으면, 휴대폰으로 보고 터치 조작을 켠다.
## 기기 판단이 틀렸을 때 일시 정지 화면에 갇히지 않게 하는 안전장치다.
func _check_capture_fallback(delta: float) -> void:
	if _capture_check_left <= 0.0:
		return
	_capture_check_left -= delta
	var player = _player()
	if _capture_check_left > 0.0 or player == null or player.touch != null:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not captured and DisplayServer.is_touchscreen_available():
		player.set_touch(true)
		player.set_paused(false)
