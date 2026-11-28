extends Control
## 터치 화면 조작. 휴대폰과 태블릿에서 키보드와 마우스를 대신한다.
##
## - 화면 왼쪽을 누른 자리에 가상 스틱이 생긴다. 끝까지 앞으로 밀면 달린다.
## - 화면 오른쪽을 끌면 시선이 돈다. 발사 버튼을 누른 채 끌어도 시선이 돈다.
## - 버튼: 발사, 정조준(누를 때마다 켜고 끔), 점프, 앉기(누르는 동안), 재장전, 무기 교체, 수류탄, 일시 정지,
##   섬광탄, 근접 공격, 점수판(누르는 동안 보인다. 키보드의 Tab과 같은 "scoreboard" 동작을 누른다).
##
## 입력 해석은 handle_touch와 handle_drag에 모아 화면 없이도 테스트할 수 있게 했다.

signal look(relative: Vector2)
signal pause_pressed

const InputCmd := preload("res://game/player/input_cmd.gd")
const UiStyle := preload("res://game/ui/ui_style.gd")
## 버튼마다 그리는 아이콘(Font Awesome 이름). 발사 버튼은 총알을 직접 그린다.
const ICONS := {
	"fire": "", "aim": "location-crosshairs", "jump": "angles-up", "crouch": "angles-down",
	"reload": "rotate", "weapon": "right-left", "grenade": "bomb", "tactical": "bolt",
	"melee": "hand-fist", "pause": "pause", "score": "table-list",
}
const STICK_RADIUS := 80.0
const STICK_ZONE := 0.45
const SPRINT_THRESHOLD := 0.92
const TAP_HOLD_TIME := 0.12

## 가상 스틱의 값. x: 좌우, y: 전후(전진이 -1).
var move := Vector2.ZERO
## 화면에 붙기 전(테스트)에 쓰는 화면 크기.
var layout_size := Vector2(1280.0, 720.0)
## 버튼 귀퉁이에 보이는 남은 수(수류탄, 섬광탄). HUD가 넣어 준다.
var badges := {}

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
	if _tap_left.has("grenade"):
		bits |= InputCmd.GRENADE
	if _tap_left.has("tactical"):
		bits |= InputCmd.TACTICAL
	if _tap_left.has("melee"):
		bits |= InputCmd.MELEE
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
	if _held.has("score"):
		Input.action_release("scoreboard")
	_roles.clear()
	_held.clear()
	_stick_index = -1
	move = Vector2.ZERO


func handle_touch(index: int, at: Vector2, pressed: bool) -> void:
	if not pressed:
		var role: String = _roles.get(index, "")
		_roles.erase(index)
		_held.erase(role)
		if role == "score":
			Input.action_release("scoreboard")
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
		"score":
			_held[button] = true
			Input.action_press("scoreboard")
		"reload", "grenade", "tactical", "melee":
			_tap_left[button] = TAP_HOLD_TIME
		"jump", "crouch":
			# 짧게 눌러도 한 틱 이상 입력으로 잡히게 잠시 유지한다.
			_tap_left[button] = TAP_HOLD_TIME
			_held[button] = true
		_:
			_held[button] = true


func _area() -> Vector2:
	return size if is_inside_tree() and size.x > 0.0 else layout_size


## 버튼 배치. 이름 -> [중심, 반지름]. 오른쪽 아래에 엄지로 누르는 전투 버튼, 오른쪽 위 모서리에
## 일시 정지와 점수판(Call of Duty Mobile 기본 배치를 참고했다).
func _layout() -> Dictionary:
	var area := _area()
	return {
		"fire": [Vector2(area.x - 120.0, area.y - 130.0), 66.0],
		"aim": [Vector2(area.x - 250.0, area.y - 75.0), 44.0],
		"jump": [Vector2(area.x - 75.0, area.y - 265.0), 44.0],
		"crouch": [Vector2(area.x - 225.0, area.y - 205.0), 42.0],
		"reload": [Vector2(area.x - 355.0, area.y - 65.0), 38.0],
		"weapon": [Vector2(area.x - 190.0, area.y - 300.0), 38.0],
		"grenade": [Vector2(area.x - 315.0, area.y - 170.0), 38.0],
		"tactical": [Vector2(area.x - 430.0, area.y - 160.0), 34.0],
		"melee": [Vector2(area.x - 305.0, area.y - 285.0), 36.0],
		"pause": [Vector2(area.x - 38.0, 36.0), 24.0],
		"score": [Vector2(area.x - 98.0, 36.0), 24.0],
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
	var layout := _layout()
	for button: String in layout:
		var spec: Array = layout[button]
		var active := _held.has(button) or (button == "aim" and _aim_on)
		_draw_button(button, spec[0], spec[1], active)
	if _stick_index >= 0:
		_draw_stick(_stick_origin, move, 1.0)
	else:
		# 처음 하는 사람도 왼쪽 아래를 밀면 움직인다는 것을 알 수 있게, 기본 자리에 흐린 스틱을 그린다.
		var area := _area()
		_draw_stick(Vector2(area.x * 0.15, area.y * 0.68), Vector2.ZERO, 0.4)


func _draw_button(button: String, center: Vector2, radius: float, active: bool) -> void:
	var fill := Color(UiStyle.ACCENT, 0.88) if active else Color(0.02, 0.025, 0.03, 0.4)
	var ring := UiStyle.ACCENT if active else Color(1.0, 1.0, 1.0, 0.45)
	var ink := UiStyle.ACCENT_DARK if active else Color(1.0, 1.0, 1.0, 0.94)
	if button == "pause" or button == "score":
		var rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		draw_style_box(UiStyle.box(fill, ring, 2, 6), rect)
	else:
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, 48, ring, 2.0, true)
	if button == "fire":
		draw_arc(center, radius - 9.0, 0.0, TAU, 48, Color(ring, ring.a * 0.5), 1.5, true)
		_draw_bullet(center, radius * 0.5, ink)
	else:
		_draw_icon(str(ICONS[button]), center, int(radius * 0.78), ink)
	if badges.has(button):
		var count := int(badges[button])
		var at := center + Vector2(radius * 0.72, -radius * 0.72)
		draw_circle(at, 10.0, UiStyle.ACCENT if count > 0 else Color(0.3, 0.32, 0.35))
		var text := str(count)
		var font := UiStyle.FONT_BOLD
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var baseline := at + Vector2(-text_size.x * 0.5, 4.5)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.ACCENT_DARK)


func _draw_icon(icon_name: String, center: Vector2, font_size: int, color: Color) -> void:
	var font := UiStyle.FONT_ICONS
	var glyph := UiStyle.glyph(icon_name)
	var glyph_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent := font.get_ascent(font_size)
	var baseline := center + Vector2(-glyph_size.x * 0.5, ascent - glyph_size.y * 0.5)
	draw_string(font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## 발사 버튼의 총알 그림: 탄두(둥근 끝)와 탄피.
func _draw_bullet(center: Vector2, height: float, color: Color) -> void:
	var half := height * 0.2
	var shoulder := center.y - height * 0.15
	var points := PackedVector2Array()
	for step in 9:
		var angle := PI + PI * step / 8.0
		points.append(Vector2(center.x + cos(angle) * half, shoulder + sin(angle) * height * 0.42))
	points.append(Vector2(center.x + half, center.y + height * 0.55))
	points.append(Vector2(center.x - half, center.y + height * 0.55))
	draw_colored_polygon(points, color)
	var rim := Rect2(center.x - half * 1.25, center.y + height * 0.55, half * 2.5, height * 0.12)
	draw_rect(rim, color)
	draw_line(Vector2(center.x - half, shoulder + 2.0), Vector2(center.x + half, shoulder + 2.0),
		Color(0, 0, 0, 0.35), 2.0)


func _draw_stick(origin: Vector2, offset: Vector2, strength: float) -> void:
	draw_circle(origin, STICK_RADIUS, Color(0.0, 0.0, 0.0, 0.22 * strength))
	draw_arc(origin, STICK_RADIUS, 0.0, TAU, 56, Color(1.0, 1.0, 1.0, 0.45 * strength), 2.0, true)
	var sprinting := offset.y < -SPRINT_THRESHOLD
	var knob := origin + offset * STICK_RADIUS
	var knob_color := Color(UiStyle.ACCENT, 0.9) if sprinting else Color(1, 1, 1, 0.38 * strength)
	draw_circle(knob, 32.0, knob_color)
	if sprinting:
		_draw_icon("person-running", knob, 26, UiStyle.ACCENT_DARK)
