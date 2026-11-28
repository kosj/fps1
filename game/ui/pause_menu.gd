extends CanvasLayer
## 일시 정지 화면. Esc로 마우스 잠금이 풀리면 나타난다.
## 네트워크 대전은 멈추지 않으므로 화면만 가리고 조작을 쉰다.
## 계속하기, 감도, 터치 조작 전환은 여기서 직접 내 플레이어에 적용한다.

signal menu_requested

const MenuKit := preload("res://game/ui/menu_kit.gd")
const Settings := preload("res://game/core/settings.gd")
const Armory := preload("res://game/weapons/armory.gd")
const LoadoutPanel := preload("res://game/ui/loadout_panel.gd")
const UiStyle := preload("res://game/ui/ui_style.gd")
## 화면 높이가 이보다 낮으면 두 칸으로 나눈다.
const SHORT_HEIGHT := 600.0
const KEY_HELP := [
	["WASD", "Move"], ["SHIFT", "Sprint"], ["CTRL", "Crouch / slide while sprinting"],
	["SPACE", "Jump / climb a ledge"], ["LMB / RMB", "Fire / aim"], ["R", "Reload"],
	["1  2  WHEEL", "Primary / pistol"], ["G   F   V", "Frag / flash / melee"], ["TAB", "Scoreboard"],
]
const TOUCH_HELP := [
	["LEFT SIDE", "Move (push fully forward to sprint)"], ["RIGHT SIDE", "Drag to look"],
	["FIRE", "Hold to shoot, drag to aim while firing"], ["DUCK", "Slide while sprinting"],
	["JUMP", "Climb a ledge"], ["NUMBER BADGE", "Grenades left"],
]
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
	var short := get_viewport().get_visible_rect().size.y < SHORT_HEIGHT
	var panel := MenuKit.centered_panel(self, Color(0.01, 0.015, 0.02, 0.62), 0.0)
	var title := UiStyle.row(12)
	panel.add_child(title)
	title.add_child(UiStyle.icon("pause", UiStyle.SIZE_XL, UiStyle.ACCENT))
	title.add_child(UiStyle.label("PAUSED", UiStyle.SIZE_XXL if not short else UiStyle.SIZE_XL,
		Color.WHITE, UiStyle.display_font()))
	# 가로 휴대폰처럼 낮은 화면에서는 왼쪽(버튼)과 오른쪽(설정, 조작법) 두 칸으로 나눈다.
	var body: BoxContainer = UiStyle.row(28) if short else UiStyle.column(14)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(body)
	var actions := UiStyle.column(8)
	actions.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(actions)
	resume_button = MenuKit.icon_button("RESUME", "play", "PrimaryButton")
	resume_button.pressed.connect(resume)
	actions.add_child(resume_button)
	loadout_button = MenuKit.icon_button("LOADOUT", "gun")
	loadout_button.pressed.connect(open_loadout)
	actions.add_child(loadout_button)
	menu_button = MenuKit.icon_button("LEAVE MATCH", "right-from-bracket")
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	actions.add_child(menu_button)
	var options := UiStyle.column(6)
	options.mouse_filter = Control.MOUSE_FILTER_PASS
	options.custom_minimum_size = Vector2(380.0, 0.0)
	body.add_child(options)
	options.add_child(UiStyle.caption("Settings", UiStyle.ACCENT))
	options.add_child(MenuKit.sensitivity_row(_on_sensitivity_changed))
	options.add_child(MenuKit.ui_scale_row(get_tree()))
	options.add_child(MenuKit.touch_toggle(_on_touch_toggled))
	options.add_child(UiStyle.caption("Controls", UiStyle.ACCENT))
	options.add_child(_controls_help())


## 조작법 표: 왼쪽 열은 키(또는 터치 동작), 오른쪽 열은 하는 일.
func _controls_help() -> GridContainer:
	var rows := TOUCH_HELP if Settings.is_mobile() else KEY_HELP
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	for pair: Array in rows:
		grid.add_child(UiStyle.label(pair[0], UiStyle.SIZE_S, UiStyle.TEXT, UiStyle.FONT_BOLD))
		grid.add_child(UiStyle.label(pair[1], UiStyle.SIZE_S, UiStyle.TEXT_DIM))
	return grid


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
