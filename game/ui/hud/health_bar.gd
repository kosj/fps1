extends Control
## 체력: 숫자와 가로 막대. 맞으면 줄어든 부분이 흰 꼬리로 잠깐 남았다가 따라 줄고,
## 35% 아래에서는 빨갛게 깜빡인다.

const UiStyle := preload("res://game/ui/ui_style.gd")
const TRAIL_DELAY := 0.35
const TRAIL_SPEED := 0.7
const LOW := 0.35

var _fraction := 1.0
var _trail := 1.0
var _trail_wait := 0.0
var _value := 100
var _blink := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(230.0, 40.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_health(health: float, max_health: float) -> void:
	var fraction := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	if fraction < _fraction:
		_trail_wait = TRAIL_DELAY
	else:
		_trail = maxf(_trail, fraction)
	_fraction = fraction
	_value = int(ceilf(health))
	queue_redraw()


func _process(delta: float) -> void:
	_blink = fmod(_blink + delta * 6.0, TAU)
	if _trail_wait > 0.0:
		_trail_wait -= delta
	elif _trail > _fraction:
		_trail = maxf(_trail - TRAIL_SPEED * delta, _fraction)
	if _trail > _fraction or _fraction <= LOW:
		queue_redraw()


func _draw() -> void:
	var low := _fraction <= LOW
	var color := UiStyle.TEXT
	if low:
		color = UiStyle.ENEMY.lerp(Color.WHITE, 0.25 + 0.25 * sin(_blink))
	var font := UiStyle.FONT_DISPLAY
	var number := str(_value)
	draw_string_outline(font, Vector2(0.0, 26.0), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 4,
		Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(0.0, 26.0), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, color)
	var number_width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var caps := UiStyle.caps_font()
	draw_string_outline(caps, Vector2(number_width + 6.0, 25.0), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1,
		13, 3, Color(0, 0, 0, 0.6))
	draw_string(caps, Vector2(number_width + 6.0, 25.0), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(UiStyle.TEXT, 0.85))
	var bar := Rect2(0.0, size.y - 8.0, size.x, 6.0)
	draw_rect(bar.grow(1.0), Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _trail, bar.size.y)), Color(1, 1, 1, 0.45))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _fraction, bar.size.y)), color)
	# 네 칸 눈금.
	for step in range(1, 4):
		var x := bar.position.x + bar.size.x * step / 4.0
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.6), 2.0)
