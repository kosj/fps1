extends CanvasLayer
## 전투 HUD: 조준선, 히트마커, 탄약, 무기 이름, 안내 문구.
## 웹 빌드에는 시스템 글꼴이 없어 한글이 표시되지 않으므로, 한글 글꼴을 넣기 전까지 영문만 쓴다.

const Crosshair := preload("res://game/ui/crosshair.gd")
const MARGIN := 32
const FEED_TIME := 5.0
const FEED_LINES := 5
const NARROW_WIDTH := 760.0
## 화면 높이(캔버스 단위)가 이보다 낮으면 결과와 점수판을 작게 그린다.
const SHORT_HEIGHT := 600.0
## 색은 아군 파랑, 적 빨강으로 보이므로(팀 이름과 무관) 점수판 머리글도 그 기준으로 쓴다.
const SCORE_HEADERS := ["YOUR TEAM", "ENEMY"]

var _crosshair: Crosshair
var _ammo_label: Label
var _weapon_label: Label
var _weapon_name := ""
var _grenades := 2
var _status_label: Label
var _hint_label: Label
var _health_label: Label
var _score_label: Label
var _damage_overlay: ColorRect
var _result_dim: ColorRect
var _result_title: Label
var _result_detail: Label
var _score_panel: PanelContainer
var _stack: VBoxContainer
var _score_columns: Array = []
var _score_hash := 0
var _message_label: Label
var _notice_label: Label
var _zone_row: HBoxContainer
var _feed: VBoxContainer
var _notice_left := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_damage_overlay = ColorRect.new()
	_damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_overlay.color = Color(0.8, 0.0, 0.0, 0.0)
	root.add_child(_damage_overlay)

	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)

	_ammo_label = _make_label(root, 40, Control.PRESET_BOTTOM_RIGHT)
	_ammo_label.offset_bottom = -MARGIN
	_weapon_label = _make_label(root, 22, Control.PRESET_BOTTOM_RIGHT)
	_weapon_label.offset_bottom = -MARGIN - 52
	_health_label = _make_label(root, 40, Control.PRESET_BOTTOM_LEFT)
	_health_label.offset_bottom = -MARGIN
	_health_label.offset_left = MARGIN
	_score_label = _make_label(root, 24, Control.PRESET_CENTER_TOP)
	_score_label.offset_top = MARGIN
	_score_label.offset_bottom = MARGIN + 28
	_message_label = _make_label(root, 44, Control.PRESET_CENTER)
	_message_label.offset_top = -200
	_message_label.offset_bottom = -150
	_zone_row = HBoxContainer.new()
	_zone_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_zone_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_zone_row.offset_top = MARGIN + 38
	_zone_row.add_theme_constant_override("separation", 28)
	_zone_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_zone_row)
	_feed = VBoxContainer.new()
	# 왼쪽 위에 둔다. 오른쪽은 터치 버튼과 탄약 표시가 쓴다.
	_feed.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_feed.offset_top = MARGIN
	_feed.offset_left = 110
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_feed)
	_notice_label = _make_label(root, 24, Control.PRESET_CENTER)
	_notice_label.offset_top = 110
	_notice_label.offset_bottom = 140
	_status_label = _make_label(root, 24, Control.PRESET_CENTER)
	_status_label.offset_top = 60
	_status_label.offset_bottom = 90
	_hint_label = _make_label(root, 22, Control.PRESET_CENTER)
	_hint_label.offset_top = -120
	_hint_label.offset_bottom = -90
	_hint_label.text = (
		"Click to play | WASD  Shift  Ctrl  Space  1-2 weapons  G grenade  -/= sensitivity"
	)


func set_ammo(ammo: int, magazine_size: int) -> void:
	_ammo_label.text = "%d / %d" % [ammo, magazine_size]
	var low := ammo <= magazine_size / 5
	_ammo_label.modulate = Color(1.0, 0.4, 0.3) if low else Color(1.0, 1.0, 1.0)


func set_health(health: float, max_health: float) -> void:
	_health_label.text = "+ %d" % int(ceilf(health))
	var low := health <= max_health * 0.35
	_health_label.modulate = Color(1.0, 0.4, 0.3) if low else Color(1.0, 1.0, 1.0)


## 화면이 좁은지(세로로 든 휴대폰). 좁으면 윗줄 문구를 짧게 쓴다.
func is_narrow() -> bool:
	return is_inside_tree() and get_viewport().get_visible_rect().size.x < NARROW_WIDTH


func set_score(text: String) -> void:
	_score_label.text = text


## 화면 가운데의 큰 안내 문구(리스폰 대기, 승패). 빈 문자열이면 숨긴다.
func set_message(text: String) -> void:
	_message_label.text = text


## 피격 시 화면 가장자리가 붉게 번쩍인다.
## 경기 결과 화면. title이 비어 있으면 숨긴다.
func set_result(title: String, color: Color, detail: String) -> void:
	if _result_dim == null:
		var root := _damage_overlay.get_parent() as Control
		_result_dim = ColorRect.new()
		_result_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_result_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_result_dim.color = Color(0.0, 0.0, 0.0, 0.55)
		root.add_child(_result_dim)
		# 결과 문구는 점수판과 같은 세로 묶음의 위쪽에 들어간다. 어둡게 하는 막은 그 묶음 아래에 둔다.
		var stack := _center_stack()
		if _result_dim.get_index() > stack.get_index():
			root.move_child(_result_dim, stack.get_index())
		_result_title = Label.new()
		_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_result_title.add_theme_font_size_override("font_size", 64 if _is_short() else 96)
		_result_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		_result_title.add_theme_constant_override("outline_size", 10)
		stack.add_child(_result_title)
		stack.move_child(_result_title, 0)
		_result_detail = Label.new()
		_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_result_detail.add_theme_font_size_override("font_size", 24 if _is_short() else 34)
		stack.add_child(_result_detail)
		stack.move_child(_result_detail, 1)
	var shown := title != ""
	_result_dim.visible = shown
	_result_title.visible = shown
	_result_detail.visible = shown
	_result_title.text = title
	_result_title.add_theme_color_override("font_color", color)
	_result_detail.text = detail


## 화면 가운데에 세로로 쌓는 묶음(결과 문구, 점수판). 들어 있는 것만큼만 차지하고 가운데에 놓인다.
func _center_stack() -> VBoxContainer:
	if _stack == null:
		var root := _damage_overlay.get_parent() as Control
		_stack = VBoxContainer.new()
		_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
		_stack.alignment = BoxContainer.ALIGNMENT_CENTER
		_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stack.add_theme_constant_override("separation", 10)
		root.add_child(_stack)
	return _stack


## 가로로 든 휴대폰처럼 화면 높이가 낮으면 결과와 점수판 글씨를 줄인다.
func _is_short() -> bool:
	return get_viewport().get_visible_rect().size.y < SHORT_HEIGHT


## 점수판. lines는 [팀, 이름, 킬, 데스, 나인지]. 내 팀이 왼쪽에 온다.
func set_scoreboard(shown: bool, lines: Array, own_team: int) -> void:
	if _score_panel == null:
		if not shown:
			return
		_build_scoreboard()
	_score_panel.visible = shown
	var content_hash := [lines, own_team].hash()
	if not shown or content_hash == _score_hash:
		return
	_score_hash = content_hash
	for side in 2:
		var team := own_team if side == 0 else 1 - own_team
		var grid: GridContainer = _score_columns[side]
		for child in grid.get_children():
			child.queue_free()
		var color := Color(0.5, 0.75, 1.0) if side == 0 else Color(1.0, 0.5, 0.45)
		for header: String in [SCORE_HEADERS[side], "K", "D"]:
			grid.add_child(_score_cell(header, color, header.length() > 1))
		for line: Array in lines:
			if int(line[0]) != team:
				continue
			var tint := Color(1.0, 0.95, 0.6) if bool(line[4]) else Color(0.92, 0.92, 0.92)
			grid.add_child(_score_cell(str(line[1]), tint, true))
			grid.add_child(_score_cell(str(line[2]), tint, false))
			grid.add_child(_score_cell(str(line[3]), tint, false))


func _build_scoreboard() -> void:
	_score_panel = PanelContainer.new()
	_score_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.78)
	style.set_content_margin_all(12.0 if _is_short() else 18.0)
	style.set_corner_radius_all(6)
	_score_panel.add_theme_stylebox_override("panel", style)
	_center_stack().add_child(_score_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	_score_panel.add_child(row)
	for side in 2:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 22)
		grid.add_theme_constant_override("v_separation", 1 if _is_short() else 4)
		row.add_child(grid)
		_score_columns.append(grid)


func _score_cell(text: String, color: Color, wide: bool) -> Label:
	var cell := Label.new()
	cell.text = text
	cell.add_theme_font_size_override("font_size", 19 if _is_short() else 24)
	cell.add_theme_color_override("font_color", color)
	cell.custom_minimum_size.x = 160.0 if wide else 32.0
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_RIGHT
	return cell


func flash_damage() -> void:
	_damage_overlay.color.a = 0.35


## 터치 조작용 배치. 오른쪽 아래는 버튼이 차지하므로 탄약과 무기 이름을 오른쪽 위로 옮긴다.
func use_touch_layout() -> void:
	for label: Label in [_ammo_label, _weapon_label]:
		label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		label.grow_vertical = Control.GROW_DIRECTION_END
		label.offset_right = -MARGIN
	_ammo_label.offset_top = MARGIN - 8
	_ammo_label.offset_bottom = MARGIN + 40
	_weapon_label.offset_top = MARGIN + 44
	_weapon_label.offset_bottom = MARGIN + 72


## 점령전 거점 상태. 각 항목은 [표시할 글자, 색].
func set_zones(items: Array) -> void:
	while _zone_row.get_child_count() < items.size():
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		label.add_theme_constant_override("outline_size", 4)
		_zone_row.add_child(label)
	for index in items.size():
		var label: Label = _zone_row.get_child(index)
		label.text = str(items[index][0])
		label.modulate = items[index][1]


## 킬 로그 한 줄을 추가한다. 5초 뒤 사라지고 최대 5줄까지 보인다.
func add_feed_line(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.set_meta("left", FEED_TIME)
	_feed.add_child(label)
	if _feed.get_child_count() > FEED_LINES:
		_feed.get_child(0).queue_free()


func set_damage_marks(marks: Array) -> void:
	_crosshair.damage_marks = marks


## 설정 변경 같은 짧은 알림을 2초간 보여 준다.
func show_notice(text: String) -> void:
	_notice_label.text = text
	_notice_left = 2.0


func _process(delta: float) -> void:
	_damage_overlay.color.a = maxf(_damage_overlay.color.a - delta * 0.9, 0.0)
	_notice_left = maxf(_notice_left - delta, 0.0)
	_notice_label.visible = _notice_left > 0.0
	for line: Node in _feed.get_children():
		var left: float = float(line.get_meta("left")) - delta
		line.set_meta("left", left)
		(line as Label).modulate.a = clampf(left, 0.0, 1.0)
		if left <= 0.0:
			line.queue_free()


func set_weapon_name(weapon_name: String) -> void:
	_weapon_name = weapon_name
	_show_weapon_line()


func set_grenades(count: int) -> void:
	_grenades = count
	_show_weapon_line()


func _show_weapon_line() -> void:
	_weapon_label.text = "%s   G x%d" % [_weapon_name, _grenades]


func set_reloading(reloading: bool) -> void:
	_status_label.text = "RELOADING" if reloading else ""


func set_hint_visible(shown: bool) -> void:
	_hint_label.visible = shown


func set_crosshair(spread_deg: float, aim_blend: float, fov: float, scope := 0.0) -> void:
	_crosshair.spread_deg = spread_deg
	_crosshair.aim_blend = aim_blend
	_crosshair.fov = fov
	_crosshair.scope_blend = scope


func show_hit(headshot: bool, killed: bool) -> void:
	_crosshair.flash_hit(headshot, killed)


func _make_label(parent: Control, font_size: int, preset: Control.LayoutPreset) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.set_anchors_preset(preset)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if preset == Control.PRESET_BOTTOM_RIGHT:
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		label.offset_right = -MARGIN
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	elif preset == Control.PRESET_BOTTOM_LEFT:
		label.grow_horizontal = Control.GROW_DIRECTION_END
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label
