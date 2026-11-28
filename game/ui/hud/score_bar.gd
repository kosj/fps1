extends VBoxContainer
## 위 가운데 점수판: 아군 점수(파랑) · 남은 시간 · 적 점수(빨강). 점수 아래 막대는 목표 점수까지의 진행,
## 그 아래 작은 글씨는 경기 방식. 점령전이면 맨 아래에 거점 A B C가 붙는다.

const UiStyle := preload("res://game/ui/ui_style.gd")
const ZoneBadge := preload("res://game/ui/hud/zone_badge.gd")

var _mine: Label
var _theirs: Label
var _clock: Label
var _mode: Label
var _mine_bar: ProgressBar
var _theirs_bar: ProgressBar
var _zones: HBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 4)
	var line := UiStyle.row(2)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(line)
	var mine := _team_block(UiStyle.ALLY)
	_mine = mine[1]
	_mine_bar = mine[2]
	line.add_child(mine[0])
	var clock := UiStyle.panel(UiStyle.margins(UiStyle.box(Color(0.0, 0.0, 0.0, 0.72)), 12, 4))
	clock.custom_minimum_size = Vector2(74.0, 0.0)
	_clock = UiStyle.label("5:00", UiStyle.SIZE_L, UiStyle.TEXT, UiStyle.FONT_BOLD)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock.add_child(_clock)
	line.add_child(clock)
	var theirs := _team_block(UiStyle.ENEMY)
	_theirs = theirs[1]
	_theirs_bar = theirs[2]
	line.add_child(theirs[0])
	_mode = UiStyle.caption("", UiStyle.TEXT_DIM, 12)
	_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_mode.add_theme_constant_override("outline_size", 3)
	add_child(_mode)
	_zones = UiStyle.row(6)
	_zones.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_zones)


## 점수, 남은 시간(초), 목표 점수(0이면 막대 없음), 경기 방식 이름.
func set_score(mine: int, theirs: int, seconds: int, limit: int, mode_title: String) -> void:
	_mine.text = str(mine)
	_theirs.text = str(theirs)
	_clock.text = "%d:%02d" % [maxi(seconds, 0) / 60, maxi(seconds, 0) % 60]
	_clock.add_theme_color_override(
		"font_color", UiStyle.ENEMY if seconds <= 30 and seconds > 0 else UiStyle.TEXT
	)
	for item: Array in [[_mine_bar, mine], [_theirs_bar, theirs]]:
		var bar: ProgressBar = item[0]
		bar.visible = limit > 0
		bar.max_value = maxf(float(limit), 1.0)
		bar.value = float(item[1])
	_mode.text = mode_title.to_upper()
	_mode.visible = not mode_title.is_empty()


## 거점 상태. 각 항목은 [글자, 주인 색, 주인이 있는지, 점령 중인 쪽 색, 진행도].
func set_zones(items: Array) -> void:
	while _zones.get_child_count() < items.size():
		_zones.add_child(ZoneBadge.new())
	for index in _zones.get_child_count():
		var badge: ZoneBadge = _zones.get_child(index)
		badge.visible = index < items.size()
		if badge.visible:
			var item: Array = items[index]
			badge.set_state(item[0], item[1], item[2], item[3], item[4])


static func _team_block(color: Color) -> Array:
	var block := UiStyle.column(0)
	var plate := UiStyle.panel(UiStyle.margins(UiStyle.box(Color(0.0, 0.0, 0.0, 0.5)), 10, 0))
	plate.custom_minimum_size = Vector2(66.0, 0.0)
	var number := UiStyle.label("0", UiStyle.SIZE_XL, color, UiStyle.FONT_DISPLAY)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	number.add_theme_constant_override("outline_size", 4)
	plate.add_child(number)
	block.add_child(plate)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 3.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", UiStyle.box(Color(0, 0, 0, 0.55), Color(), 0, 0))
	bar.add_theme_stylebox_override("fill", UiStyle.box(color, Color(), 0, 0))
	block.add_child(bar)
	return [block, number, bar]
