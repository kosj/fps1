extends Control
## 조준선과 히트마커. 퍼짐이 커지면 벌어지고, 정조준하면 사라진다.

const LINE_LENGTH := 9.0
const LINE_WIDTH := 2.0
const HIT_TIME := 0.18
const HIT_COLOR := Color(1.0, 1.0, 1.0)
const HEADSHOT_COLOR := Color(1.0, 0.85, 0.3)
const KILL_COLOR := Color(1.0, 0.25, 0.2)

var spread_deg := 2.0
var aim_blend := 0.0
var fov := 80.0

## 피격 방향 표시. 각 항목은 [화면 기준 각도(라디안, 0이 정면, 시계 방향), 불투명도].
var damage_marks: Array = []

var _hit_left := 0.0
var _hit_color := HIT_COLOR


func flash_hit(headshot: bool, killed: bool) -> void:
	_hit_left = HIT_TIME
	_hit_color = HIT_COLOR
	if killed:
		_hit_color = KILL_COLOR
	elif headshot:
		_hit_color = HEADSHOT_COLOR


func _process(delta: float) -> void:
	_hit_left = maxf(_hit_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var alpha := 1.0 - aim_blend
	if alpha > 0.01:
		# 퍼짐 각도를 화면 픽셀로 근사한다.
		var gap := 4.0 + spread_deg * size.y / maxf(fov, 1.0)
		var color := Color(1.0, 1.0, 1.0, 0.9 * alpha)
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var start := center + direction * gap
			draw_line(start, start + direction * LINE_LENGTH, color, LINE_WIDTH)
		draw_circle(center, 1.5, color)
	for mark: Array in damage_marks:
		var middle := float(mark[0]) - PI / 2.0
		var mark_color := Color(1.0, 0.15, 0.1, 0.85 * float(mark[1]))
		draw_arc(center, 120.0, middle - 0.3, middle + 0.3, 12, mark_color, 7.0)
	if _hit_left > 0.0:
		var hit_alpha := _hit_left / HIT_TIME
		var color := Color(_hit_color.r, _hit_color.g, _hit_color.b, hit_alpha)
		for direction: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var unit := direction.normalized()
			draw_line(center + unit * 7.0, center + unit * 15.0, color, LINE_WIDTH)
