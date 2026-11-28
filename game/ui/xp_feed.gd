extends Control
## 경험치 알림: 조준선 오른쪽 아래에 "+100 KILL" 같은 글이 잠깐 떴다 사라지고,
## 레벨이 오르면 화면 위쪽에 큰 글씨로 알린다.

const AWARD_TIME := 1.6
const BANNER_TIME := 3.5
const AWARD_COLOR := Color(1.0, 0.86, 0.4)
const BANNER_COLOR := Color(0.55, 0.85, 1.0)

var _awards: VBoxContainer
var _banner: VBoxContainer
var _banner_left := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_awards = VBoxContainer.new()
	_awards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_awards.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_awards.position += Vector2(60.0, 40.0)
	add_child(_awards)
	_banner = VBoxContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.position.y += 110.0
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_banner)


func show_award(text: String) -> void:
	var label := _label(text, 24, AWARD_COLOR)
	label.set_meta("left", AWARD_TIME)
	_awards.add_child(label)
	while _awards.get_child_count() > 4:
		var oldest := _awards.get_child(0)
		_awards.remove_child(oldest)
		oldest.queue_free()


## names는 이 레벨에서 풀린 무기 이름들.
func show_level_up(level: int, names: Array) -> void:
	for child in _banner.get_children():
		child.queue_free()
	_banner.add_child(_label("LEVEL UP  %d" % level, 44, BANNER_COLOR))
	for weapon_name: String in names:
		_banner.add_child(_label("NEW WEAPON: %s  (LOADOUT)" % weapon_name, 24, AWARD_COLOR))
	_banner_left = BANNER_TIME


func _process(delta: float) -> void:
	for child in _awards.get_children():
		var left: float = float(child.get_meta("left")) - delta
		child.set_meta("left", left)
		(child as Label).modulate.a = clampf(left / 0.4, 0.0, 1.0)
		if left <= 0.0:
			child.queue_free()
	_banner_left = maxf(_banner_left - delta, 0.0)
	_banner.modulate.a = clampf(_banner_left / 0.5, 0.0, 1.0)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	return label
