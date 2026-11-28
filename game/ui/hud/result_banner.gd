extends VBoxContainer
## 판이 끝났을 때의 결과: 큰 VICTORY / DEFEAT / DRAW, 양 팀 점수, 이번 판 경험치, 다음 판 안내.

const UiStyle := preload("res://game/ui/ui_style.gd")
const TITLES := {"victory": "VICTORY", "defeat": "DEFEAT", "draw": "DRAW"}

var compact := false

var _title: Label
var _line: ColorRect
var _mine: Label
var _theirs: Label
var _xp: Label
var _next: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 2)
	_title = UiStyle.label("", 96, UiStyle.ACCENT, UiStyle.display_font())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_title.add_theme_constant_override("outline_size", 8)
	add_child(_title)
	_line = ColorRect.new()
	_line.custom_minimum_size = Vector2(160.0, 3.0)
	_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line)
	var scores := UiStyle.row(14)
	scores.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(scores)
	_mine = UiStyle.label("0", UiStyle.SIZE_XXL, UiStyle.ALLY, UiStyle.FONT_DISPLAY)
	scores.add_child(_mine)
	scores.add_child(UiStyle.label("-", UiStyle.SIZE_XL, UiStyle.TEXT_DIM, UiStyle.FONT_DISPLAY))
	_theirs = UiStyle.label("0", UiStyle.SIZE_XXL, UiStyle.ENEMY, UiStyle.FONT_DISPLAY)
	scores.add_child(_theirs)
	_xp = UiStyle.label("", UiStyle.SIZE_M, UiStyle.ACCENT, UiStyle.caps_font())
	_xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_xp)
	_next = UiStyle.caption("NEXT MATCH STARTING SOON", UiStyle.TEXT_DIM, 12)
	_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_next)


## outcome은 victory, defeat, draw. xp_line은 비어 있을 수 있다.
func show_result(outcome: String, mine: int, theirs: int, xp_line: String) -> void:
	var color := UiStyle.TEXT
	if outcome == "victory":
		color = UiStyle.ACCENT
	elif outcome == "defeat":
		color = UiStyle.ENEMY
	_title.text = str(TITLES.get(outcome, outcome.to_upper()))
	_title.add_theme_color_override("font_color", color)
	_title.add_theme_font_size_override("font_size", 64 if compact else 96)
	_line.color = color
	_mine.text = str(mine)
	_theirs.text = str(theirs)
	_xp.text = xp_line
	_xp.visible = not xp_line.is_empty()
