extends Control
## 경험치 알림: 조준선 오른쪽 아래에 "+100 KILL" 같은 줄이 톡 튀어나왔다가 사라지고,
## 레벨이 오르면 화면 위쪽에 LEVEL UP 카드(새로 풀린 무기 포함)를 띄운다.

const UiStyle := preload("res://game/ui/ui_style.gd")
const AWARD_TIME := 1.7
const BANNER_TIME := 3.5
const POP_TIME := 0.16
const MAX_AWARDS := 4

var _awards: VBoxContainer
var _banner: PanelContainer
var _banner_column: VBoxContainer
var _banner_left := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# hud가 점수판·사망·결과 화면을 띄우는 동안 이 알림을 숨긴다.
	add_to_group(&"hud_popups")
	# 조준선 바로 아래 가운데. 오른쪽은 휴대폰의 터치 버튼이 차지한다.
	_awards = UiStyle.column(0)
	_awards.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_awards.anchor_top = 0.5
	_awards.anchor_bottom = 0.5
	_awards.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_awards.offset_top = 44.0
	_awards.offset_bottom = 44.0
	_awards.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_awards)
	var style := UiStyle.stripe_box(Color(0.03, 0.035, 0.045, 0.82), UiStyle.ACCENT, 4)
	_banner = UiStyle.panel(UiStyle.margins(style, 22, 10))
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# 점수 막대(거점 표시 포함) 바로 아래: 조준선을 가리지 않게 화면 위쪽에 띄운다.
	_banner.position.y += 112.0
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_column = UiStyle.column(0)
	_banner.add_child(_banner_column)


## text는 "+100  KILL" 모양(점수와 이유를 두 칸 띄어 쓴다).
func show_award(text: String) -> void:
	var parts := text.split("  ", false, 1)
	var row := UiStyle.row(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var amount := UiStyle.label(parts[0], UiStyle.SIZE_L + 2, UiStyle.ACCENT, UiStyle.FONT_DISPLAY)
	row.add_child(_outline(amount))
	if parts.size() > 1:
		var reason := UiStyle.label(parts[1].strip_edges(), UiStyle.SIZE_S, UiStyle.TEXT,
			UiStyle.caps_font())
		reason.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_outline(reason))
	row.set_meta("left", AWARD_TIME)
	_awards.add_child(row)
	row.pivot_offset = Vector2(row.get_combined_minimum_size().x * 0.5, 14.0)
	row.scale = Vector2(1.35, 1.35)
	while _awards.get_child_count() > MAX_AWARDS:
		var oldest := _awards.get_child(0)
		_awards.remove_child(oldest)
		oldest.queue_free()


## names는 이 레벨에서 풀린 무기 이름들.
func show_level_up(level: int, names: Array) -> void:
	for child in _banner_column.get_children():
		child.queue_free()
	var caption := UiStyle.caption("LEVEL UP", UiStyle.ACCENT, UiStyle.SIZE_S)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_column.add_child(caption)
	var title := UiStyle.label("LEVEL %d" % level, UiStyle.SIZE_XXL, Color.WHITE,
		UiStyle.display_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_column.add_child(title)
	for weapon_name: String in names:
		var unlocked := UiStyle.caption("NEW WEAPON  %s  ·  LOADOUT" % weapon_name, UiStyle.TEXT, 13)
		unlocked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_banner_column.add_child(unlocked)
	_banner_left = BANNER_TIME


func _process(delta: float) -> void:
	for child: Control in _awards.get_children():
		var left: float = float(child.get_meta("left")) - delta
		child.set_meta("left", left)
		child.modulate.a = clampf(left / 0.4, 0.0, 1.0)
		var grown := clampf((AWARD_TIME - left) / POP_TIME, 0.0, 1.0)
		child.scale = Vector2.ONE * lerpf(1.35, 1.0, grown)
		if left <= 0.0:
			child.queue_free()
	_banner_left = maxf(_banner_left - delta, 0.0)
	_banner.modulate.a = clampf(_banner_left / 0.5, 0.0, 1.0)


static func _outline(label: Label) -> Label:
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("outline_size", 5)
	return label
