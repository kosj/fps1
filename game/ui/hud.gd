extends CanvasLayer
## 전투 HUD: 조준선, 히트마커, 탄약, 무기 이름, 안내 문구.
## 웹 빌드에는 시스템 글꼴이 없어 한글이 표시되지 않으므로, 한글 글꼴을 넣기 전까지 영문만 쓴다.

const Crosshair := preload("res://game/ui/crosshair.gd")
const MARGIN := 32
const FEED_TIME := 5.0
const FEED_LINES := 5

var _crosshair: Crosshair
var _ammo_label: Label
var _weapon_label: Label
var _status_label: Label
var _hint_label: Label
var _health_label: Label
var _score_label: Label
var _damage_overlay: ColorRect
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
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.offset_top = MARGIN
	_feed.offset_right = -MARGIN
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
	_hint_label.text = "Click to play | WASD  Shift  Ctrl  Space  1-4 weapons  -/= sensitivity"


func set_ammo(ammo: int, magazine_size: int) -> void:
	_ammo_label.text = "%d / %d" % [ammo, magazine_size]
	var low := ammo <= magazine_size / 5
	_ammo_label.modulate = Color(1.0, 0.4, 0.3) if low else Color(1.0, 1.0, 1.0)


func set_health(health: float, max_health: float) -> void:
	_health_label.text = "+ %d" % int(ceilf(health))
	var low := health <= max_health * 0.35
	_health_label.modulate = Color(1.0, 0.4, 0.3) if low else Color(1.0, 1.0, 1.0)


func set_score(text: String) -> void:
	_score_label.text = text


## 화면 가운데의 큰 안내 문구(리스폰 대기, 승패). 빈 문자열이면 숨긴다.
func set_message(text: String) -> void:
	_message_label.text = text


## 피격 시 화면 가장자리가 붉게 번쩍인다.
func flash_damage() -> void:
	_damage_overlay.color.a = 0.35


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
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	_weapon_label.text = weapon_name


func set_reloading(reloading: bool) -> void:
	_status_label.text = "RELOADING" if reloading else ""


func set_hint_visible(shown: bool) -> void:
	_hint_label.visible = shown


func set_crosshair(spread_deg: float, aim_blend: float, fov: float) -> void:
	_crosshair.spread_deg = spread_deg
	_crosshair.aim_blend = aim_blend
	_crosshair.fov = fov


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
