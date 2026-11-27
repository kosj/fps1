extends Control
## 터치 화면 조작. 휴대폰과 태블릿에서 키보드와 마우스를 대신한다.
##
## - 화면 왼쪽을 누른 자리에 가상 스틱이 생긴다. 끝까지 앞으로 밀면 달린다.
## - 화면 오른쪽을 끌면 시선이 돈다. 발사 버튼을 누른 채 끌어도 시선이 돈다.
## - 버튼: 발사, 정조준(누를 때마다 켜고 끔), 점프, 앉기(누르는 동안), 재장전, 무기 교체, 일시 정지.
##
## 입력 해석은 handle_touch와 handle_drag에 모아 화면 없이도 테스트할 수 있게 했다.

signal look(relative: Vector2)
signal pause_pressed

const InputCmd := preload("res://game/player/input_cmd.gd")
const STICK_RADIUS := 80.0
const STICK_ZONE := 0.45
const SPRINT_THRESHOLD := 0.92
const TAP_HOLD_TIME := 0.12

## 가상 스틱의 값. x: 좌우, y: 전후(전진이 -1).
var move := Vector2.ZERO
## 화면에 붙기 전(테스트)에 쓰는 화면 크기.
var layout_size := Vector2(1280.0, 720.0)

var _stick_index := -1
var _stick_origin := Vector2.ZERO
## 터치 번호 -> 역할("stick", "look", 또는 버튼 이름).
var _roles := {}
var _held := {}
var _aim_on := false
var _tap_left := {}
var _weapon_steps := 0


func _ready() -> void:
	# 트리에 들어온 뒤에는 set_anchors_preset이 현재 크기(0)를 유지하도록 오프셋을 잡아,
	# 버튼 위치의 기준인 size가 (0, 0)이 되고 버튼이 모두 화면 밖에 그려졌다. 오프셋까지 함께 맞춘다.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		handle_touch(touch.index, touch.position, touch.pressed)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		handle_drag(drag.index, drag.position, drag.relative)


func _process(delta: float) -> void:
	for key: String in _tap_left.keys():
		_tap_left[key] = float(_tap_left[key]) - delta
		if float(_tap_left[key]) <= 0.0:
			_tap_left.erase(key)
	queue_redraw()


## 지금 눌린 버튼을 InputCmd 비트로 돌려준다.
func buttons() -> int:
	var bits := 0
	if _held.has("fire"):
		bits |= InputCmd.FIRE
	if _aim_on:
		bits |= InputCmd.AIM
	if _held.has("crouch") or _tap_left.has("crouch"):
		bits |= InputCmd.CROUCH
	if _held.has("jump") or _tap_left.has("jump"):
		bits |= InputCmd.JUMP
	if _tap_left.has("reload"):
		bits |= InputCmd.RELOAD
	if move.y < -SPRINT_THRESHOLD:
		bits |= InputCmd.SPRINT
	return bits


## 무기 교체 버튼이 눌린 횟수를 돌려주고 0으로 되돌린다.
func take_weapon_steps() -> int:
	var steps := _weapon_steps
	_weapon_steps = 0
	return steps


## 모든 터치를 놓은 상태로 되돌린다(일시 정지, 사망).
func release_all() -> void:
	_roles.clear()
	_held.clear()
	_stick_index = -1
	move = Vector2.ZERO


func handle_touch(index: int, at: Vector2, pressed: bool) -> void:
	if not pressed:
		var role: String = _roles.get(index, "")
		_roles.erase(index)
		_held.erase(role)
		if index == _stick_index:
			_stick_index = -1
			move = Vector2.ZERO
		return
	var button := _button_at(at)
	if button != "":
		_roles[index] = button
		_press(button)
	elif at.x < _area().x * STICK_ZONE and _stick_index < 0:
		_roles[index] = "stick"
		_stick_index = index
		_stick_origin = at
		move = Vector2.ZERO
	else:
		_roles[index] = "look"


func handle_drag(index: int, at: Vector2, relative: Vector2) -> void:
	var role: String = _roles.get(index, "")
	if role == "stick":
		move = ((at - _stick_origin) / STICK_RADIUS).limit_length(1.0)
	elif role == "look" or role == "fire":
		look.emit(relative)


func _press(button: String) -> void:
	match button:
		"aim":
			_aim_on = not _aim_on
		"weapon":
			_weapon_steps += 1
		"pause":
			pause_pressed.emit()
		"reload":
			_tap_left[button] = TAP_HOLD_TIME
		"jump", "crouch":
			# 짧게 눌러도 한 틱 이상 입력으로 잡히게 잠시 유지한다.
			_tap_left[button] = TAP_HOLD_TIME
			_held[button] = true
		_:
			_held[button] = true


func _area() -> Vector2:
	return size if is_inside_tree() and size.x > 0.0 else layout_size


## 버튼 배치. 이름 -> [중심, 반지름, 글자].
func _layout() -> Dictionary:
	var area := _area()
	return {
		"fire": [Vector2(area.x - 120.0, area.y - 130.0), 66.0, "FIRE"],
		"aim": [Vector2(area.x - 250.0, area.y - 75.0), 44.0, "AIM"],
		"jump": [Vector2(area.x - 75.0, area.y - 265.0), 44.0, "JUMP"],
		"crouch": [Vector2(area.x - 225.0, area.y - 205.0), 42.0, "DUCK"],
		"reload": [Vector2(area.x - 355.0, area.y - 65.0), 38.0, "R"],
		"weapon": [Vector2(area.x - 190.0, area.y - 300.0), 38.0, "GUN"],
		"pause": [Vector2(60.0, 60.0), 34.0, "II"],
	}


func _button_at(at: Vector2) -> String:
	var layout := _layout()
	for button: String in layout:
		var spec: Array = layout[button]
		var center: Vector2 = spec[0]
		if at.distance_to(center) <= float(spec[1]) * 1.15:
			return button
	return ""


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var layout := _layout()
	for button: String in layout:
		var spec: Array = layout[button]
		var center: Vector2 = spec[0]
		var radius: float = spec[1]
		var active := _held.has(button) or (button == "aim" and _aim_on)
		var fill := Color(1.0, 1.0, 1.0, 0.38 if active else 0.16)
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.55), 2.0)
		var text: String = spec[2]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 20)
		var text_at := center + Vector2(-text_size.x / 2.0, text_size.y / 4.0)
		draw_string(font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20)
	if _stick_index >= 0:
		draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.5), 2.0)
		draw_circle(_stick_origin + move * STICK_RADIUS, 34.0, Color(1.0, 1.0, 1.0, 0.35))
