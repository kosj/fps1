extends CanvasLayer
## 로드아웃 선택 화면. 주무기 네 가지를 카드(옆모습, 이름, 능력치 막대)로 보여 주고,
## 카드를 누르면 그 총을 고르고 닫힌다. 권총은 늘 함께 든다.
## 시작 화면과 일시 정지 화면이 함께 쓴다.

## 주무기를 골랐을 때(game/weapons/armory.gd의 번호). 그다음 closed가 온다.
signal chosen(id: int)
signal closed

const Armory := preload("res://game/weapons/armory.gd")
const MenuKit := preload("res://game/ui/menu_kit.gd")
const UiStyle := preload("res://game/ui/ui_style.gd")
const Progression := preload("res://game/core/progression.gd")
const STAT_NAMES := ["DAMAGE", "FIRE RATE", "RANGE", "HANDLING"]
## 화면 폭이 이보다 좁으면(세로로 든 휴대폰) 카드를 두 줄로 놓는다.
const WIDE_WIDTH := 1000.0
const SHORT_HEIGHT := 600.0

## 지금 고른 주무기. 화면을 열기 전에 넣어 두면 그 카드가 강조된다.
var selected := Armory.DEFAULT_PRIMARY
var back_button: Button

var _cards := {}
var _done := false
var _level := 1
var _hint: Label
var _short := false


func _ready() -> void:
	layer = 40
	_level = Progression.saved_level()
	var view := get_viewport().get_visible_rect().size
	_short = view.y < SHORT_HEIGHT
	var column := MenuKit.centered_panel(self, Color(0.01, 0.015, 0.02, 0.86), 0.0)
	var title := UiStyle.row(14)
	column.add_child(title)
	back_button = Button.new()
	back_button.theme_type_variation = "GhostButton"
	back_button.text = "BACK"
	back_button.pressed.connect(_close)
	var heading := UiStyle.column(0)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(heading)
	heading.add_child(UiStyle.label("LOADOUT", UiStyle.SIZE_XL if _short else UiStyle.SIZE_XXL,
		Color.WHITE, UiStyle.display_font()))
	_hint = UiStyle.caption("Choose your primary weapon  ·  level %d" % _level, UiStyle.TEXT_DIM, 12)
	heading.add_child(_hint)
	title.add_child(back_button)
	var grid := GridContainer.new()
	var wide := view.x >= WIDE_WIDTH or _short
	grid.columns = Armory.PRIMARIES.size() if wide else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id: int in Armory.PRIMARIES:
		grid.add_child(_card(id))
	column.add_child(grid)
	column.add_child(_sidearm_row())
	_highlight()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


## 주무기를 고르고 화면을 닫는다.
func pick(id: int) -> void:
	if _done:
		return
	if not Progression.is_unlocked(id, _level):
		var needed := Progression.unlock_level(id)
		_hint.text = "%s unlocks at level %d" % [Armory.title(id).to_upper(), needed]
		_hint.add_theme_color_override("font_color", UiStyle.ACCENT)
		_highlight()
		return
	selected = Armory.valid_primary(id)
	_highlight()
	chosen.emit(selected)
	_close()


func _close() -> void:
	if _done:
		return
	_done = true
	closed.emit()
	queue_free()


func _card(id: int) -> Control:
	var unlocked := Progression.is_unlocked(id, _level)
	var card := Button.new()
	card.theme_type_variation = "CardButton"
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(200.0, 192.0) if _short else Vector2(250.0, 262.0)
	card.pressed.connect(pick.bind(id))
	_cards[id] = card
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)
	var box := UiStyle.column(3)
	margin.add_child(box)
	var head := UiStyle.row(6)
	box.add_child(head)
	var role := UiStyle.caption(Armory.ROLES[id], UiStyle.TEXT_DIM, 11)
	role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(role)
	if not unlocked:
		head.add_child(UiStyle.icon("lock", UiStyle.SIZE_S, UiStyle.ACCENT))
		head.add_child(UiStyle.caption("LEVEL %d" % Progression.unlock_level(id), UiStyle.ACCENT, 11))
	var icon := TextureRect.new()
	icon.texture = Armory.ICONS[id]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(180.0, 58.0) if _short else Vector2(228.0, 92.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	box.add_child(UiStyle.label(Armory.title(id).to_upper(), UiStyle.SIZE_L + 2, Color.WHITE,
		UiStyle.display_font()))
	var values: Array = Armory.stats(id)
	for index in STAT_NAMES.size():
		var row := UiStyle.row(8)
		var caption := UiStyle.caption(STAT_NAMES[index], UiStyle.TEXT_FAINT, 10)
		caption.custom_minimum_size = Vector2(66.0, 0.0)
		row.add_child(caption)
		row.add_child(_bar(float(values[index])))
		box.add_child(row)
	if not unlocked:
		# 잠긴 총은 흐리게: 고를 수는 없고, 누르면 풀리는 레벨을 알려 준다.
		icon.modulate = Color(1.0, 1.0, 1.0, 0.35)
		box.modulate = Color(1.0, 1.0, 1.0, 0.7)
	return card


func _sidearm_row() -> Control:
	var row := UiStyle.row(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.texture = Armory.ICONS[Armory.SIDEARM]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(64.0, 34.0)
	row.add_child(icon)
	var title := Armory.title(Armory.SIDEARM).to_upper()
	row.add_child(UiStyle.caption("Sidearm  %s  ·  always carried  ·  key 2" % title,
		UiStyle.TEXT_DIM, 12))
	return row


func _bar(value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(110.0, 5.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", UiStyle.box(UiStyle.TEXT, Color(), 0, 1))
	return bar


func _highlight() -> void:
	for id: int in _cards:
		(_cards[id] as Button).set_pressed_no_signal(id == selected)
