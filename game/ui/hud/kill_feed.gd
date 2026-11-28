extends VBoxContainer
## 킬 로그: "누가 [아이콘] 누구를" 한 줄씩, 팀 색 이름. 헤드샷은 호박색 조준 아이콘, 나와 관련된 줄은
## 왼쪽에 호박색 띠. 5초 뒤 흐려지며 사라지고 최대 5줄.

const UiStyle := preload("res://game/ui/ui_style.gd")
const LIFE := 5.0
const MAX_LINES := 5


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 3)


func add(
	killer: String, killer_color: Color, victim: String, victim_color: Color,
	headshot: bool, mine: bool
) -> void:
	var style := UiStyle.box(Color(0.0, 0.0, 0.0, 0.5))
	if mine:
		style = UiStyle.stripe_box(Color(0.0, 0.0, 0.0, 0.62), UiStyle.ACCENT, 3)
	var line := UiStyle.panel(UiStyle.margins(style, 8, 2))
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := UiStyle.row(7)
	line.add_child(row)
	row.add_child(_name(killer, killer_color))
	var glyph := "crosshairs" if headshot else "skull"
	row.add_child(UiStyle.icon(glyph, 13, UiStyle.ACCENT if headshot else UiStyle.TEXT_DIM))
	row.add_child(_name(victim, victim_color))
	line.set_meta("left", LIFE)
	add_child(line)
	while get_child_count() > MAX_LINES:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()


func _process(delta: float) -> void:
	for line: Node in get_children():
		var left: float = float(line.get_meta("left")) - delta
		line.set_meta("left", left)
		(line as Control).modulate.a = clampf(left * 1.5, 0.0, 1.0)
		if left <= 0.0:
			line.queue_free()


static func _name(text: String, color: Color) -> Label:
	var label := UiStyle.label(text, UiStyle.SIZE_S + 1, color, UiStyle.FONT_BOLD)
	return label
