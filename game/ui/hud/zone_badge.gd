extends Control
## 점령전 거점 하나(A, B, C)의 표시. 주인 색으로 칠하고, 점령 중이면 아래에서부터 차오른다.

const UiStyle := preload("res://game/ui/ui_style.gd")

var letter := "A"
## 주인 색(없으면 중립)과 점령 중인 쪽 색, 진행도(0~1).
var owner_color := UiStyle.NEUTRAL
var owned := false
var capture_color := UiStyle.NEUTRAL
var progress := 0.0

var _pulse := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(30.0, 30.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 3.0, TAU)
	if progress > 0.0:
		queue_redraw()


func set_state(new_letter: String, color: Color, is_owned: bool, by: Color, amount: float) -> void:
	letter = new_letter
	owner_color = color
	owned = is_owned
	capture_color = by
	progress = clampf(amount, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var back := Color(owner_color, 0.5) if owned else Color(0.0, 0.0, 0.0, 0.55)
	draw_rect(rect, back)
	if progress > 0.0:
		var height := size.y * progress
		draw_rect(Rect2(0.0, size.y - height, size.x, height), Color(capture_color, 0.75))
	var edge := owner_color if owned else Color(1.0, 1.0, 1.0, 0.45)
	if progress > 0.0:
		edge = Color(capture_color, 0.6 + 0.4 * sin(_pulse))
	draw_rect(rect, edge, false, 2.0)
	var font := UiStyle.FONT_BOLD
	var font_size := int(size.y * 0.6)
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at := Vector2((size.x - text_size.x) * 0.5, (size.y + font_size * 0.72) * 0.5)
	draw_string(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
