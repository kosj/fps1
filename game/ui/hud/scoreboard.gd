extends PanelContainer
## 점수판: 왼쪽 내 팀, 오른쪽 적 팀. 팀마다 색 띠 머리글(이름과 킬 합계), 줄마다 이름·킬·데스.
## 내 줄은 호박색 띠, 봇은 이름 뒤에 작은 BOT 표시.

const UiStyle := preload("res://game/ui/ui_style.gd")
const HEADERS := ["YOUR TEAM", "ENEMY"]

var compact := false

var _columns: Array = []
var _hash := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := UiStyle.box(Color(0.03, 0.035, 0.045, 0.86), UiStyle.LINE, 1)
	add_theme_stylebox_override("panel", UiStyle.margins(style, 14, 12))
	var row := UiStyle.row(22)
	add_child(row)
	for side in 2:
		var column := UiStyle.column(2)
		column.custom_minimum_size = Vector2(250.0, 0.0)
		row.add_child(column)
		_columns.append(column)


## lines의 각 항목은 [팀, 이름, 킬, 데스, 나인지, 봇인지].
func set_lines(lines: Array, own_team: int) -> void:
	var content_hash := [lines, own_team, compact].hash()
	if content_hash == _hash:
		return
	_hash = content_hash
	for side in 2:
		var team := own_team if side == 0 else 1 - own_team
		var column: VBoxContainer = _columns[side]
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()
		var members: Array = lines.filter(func(line: Array) -> bool: return int(line[0]) == team)
		members.sort_custom(func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2]))
		var kills := 0
		for line: Array in members:
			kills += int(line[2])
		var color := UiStyle.ALLY if side == 0 else UiStyle.ENEMY
		column.add_child(_header(HEADERS[side], kills, color))
		column.add_child(_row(["PLAYER", "K", "D"], false, false, -1, true))
		for index in members.size():
			var line: Array = members[index]
			var cells := [str(line[1]), str(line[2]), str(line[3])]
			column.add_child(_row(cells, bool(line[4]), bool(line[5]) if line.size() > 5 else false,
				index, false))


func _header(title: String, kills: int, color: Color) -> Control:
	var style := UiStyle.stripe_box(Color(color, 0.22), color, 4)
	var plate := UiStyle.panel(UiStyle.margins(style, 10, 3 if compact else 5))
	var row := UiStyle.row(8)
	plate.add_child(row)
	var title_label := UiStyle.label(title, UiStyle.SIZE_M if compact else UiStyle.SIZE_L,
		Color.WHITE, UiStyle.display_font())
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	var total := UiStyle.label(str(kills), UiStyle.SIZE_M if compact else UiStyle.SIZE_L, color,
		UiStyle.FONT_DISPLAY)
	row.add_child(total)
	return plate


func _row(cells: Array, me: bool, bot: bool, index: int, heading: bool) -> Control:
	var back := Color(1, 1, 1, 0.05 if index % 2 == 0 else 0.02)
	var style := UiStyle.box(Color(0, 0, 0, 0) if heading else back)
	if me:
		style = UiStyle.stripe_box(Color(UiStyle.ACCENT, 0.16), UiStyle.ACCENT, 3)
	var plate := UiStyle.panel(UiStyle.margins(style, 10, 0 if compact else 2))
	var row := UiStyle.row(6)
	plate.add_child(row)
	var font_size := UiStyle.SIZE_S if compact else UiStyle.SIZE_M
	for index_cell in cells.size():
		var text: String = cells[index_cell]
		var label: Label
		if heading:
			label = UiStyle.caption(text, UiStyle.TEXT_FAINT, 11)
		else:
			var color := Color.WHITE if me else UiStyle.TEXT
			if index_cell == 2:
				color = UiStyle.TEXT_DIM
			label = UiStyle.label(text, font_size, color, UiStyle.FONT_BOLD)
		if index_cell == 0:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.clip_text = true
			row.add_child(label)
			if bot:
				row.add_child(UiStyle.caption("BOT", UiStyle.TEXT_FAINT, 10))
		else:
			label.custom_minimum_size = Vector2(30.0, 0.0)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(label)
	return plate
