extends CanvasLayer
## 로드아웃 선택 화면. 주무기 네 가지를 카드(옆모습, 이름, 능력치 막대)로 보여 주고,
## 카드를 누르면 그 총을 고르고 닫힌다. 권총은 늘 함께 든다.
## 시작 화면과 일시 정지 화면이 함께 쓴다.

## 주무기를 골랐을 때(game/weapons/armory.gd의 번호). 그다음 closed가 온다.
signal chosen(id: int)
signal closed

const Armory := preload("res://game/weapons/armory.gd")
const MenuKit := preload("res://game/ui/menu_kit.gd")
const Progression := preload("res://game/core/progression.gd")
const STAT_NAMES := ["DAMAGE", "FIRE RATE", "RANGE", "HANDLING"]
const CARD_COLOR := Color(0.1, 0.12, 0.15, 0.94)
const PICKED_BORDER := Color(0.95, 0.72, 0.28)
const IDLE_BORDER := Color(1.0, 1.0, 1.0, 0.12)
const BAR_COLOR := Color(0.86, 0.88, 0.9)
const DIM_TEXT := Color(0.72, 0.75, 0.8)
const LOCK_TEXT := Color(1.0, 0.62, 0.3)
## 화면 폭이 이보다 좁으면(세로로 든 휴대폰) 카드를 두 줄로 놓는다.
const WIDE_WIDTH := 1000.0

## 지금 고른 주무기. 화면을 열기 전에 넣어 두면 그 카드가 강조된다.
var selected := Armory.DEFAULT_PRIMARY
var back_button: Button

var _styles := {}
var _done := false
var _level := 1
var _hint: Label


func _ready() -> void:
	layer = 40
	_level = Progression.saved_level()
	var column := MenuKit.centered_column(self, Color(0.03, 0.04, 0.05, 0.97))
	column.add_child(MenuKit.label("LOADOUT", 40))
	_hint = MenuKit.label("Choose your primary weapon    (LEVEL %d)" % _level, 18)
	_hint.add_theme_color_override("font_color", DIM_TEXT)
	column.add_child(_hint)
	var grid := GridContainer.new()
	var wide := get_viewport().get_visible_rect().size.x >= WIDE_WIDTH
	grid.columns = Armory.PRIMARIES.size() if wide else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for id: int in Armory.PRIMARIES:
		grid.add_child(_card(id))
	column.add_child(grid)
	column.add_child(_sidearm_row())
	back_button = MenuKit.button("BACK")
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(_close)
	column.add_child(back_button)
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
		_hint.text = "%s unlocks at level %d" % [Armory.title(id), needed]
		_hint.add_theme_color_override("font_color", LOCK_TEXT)
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
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(228.0, 0.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.set_content_margin_all(10.0)
	card.add_theme_stylebox_override("panel", style)
	_styles[id] = style
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var icon := TextureRect.new()
	icon.texture = Armory.ICONS[id]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(208.0, 80.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	box.add_child(_text(Armory.title(id), 22, Color.WHITE))
	if Progression.is_unlocked(id, _level):
		box.add_child(_text(Armory.ROLES[id], 14, DIM_TEXT))
	else:
		# 잠긴 총: 흐리게 보이고, 역할 대신 풀리는 레벨을 쓴다.
		box.modulate = Color(1.0, 1.0, 1.0, 0.45)
		var needed := "LOCKED  -  LEVEL %d" % Progression.unlock_level(id)
		box.add_child(_text(needed, 14, LOCK_TEXT))
	var values: Array = Armory.stats(id)
	for index in STAT_NAMES.size():
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var caption := _text(STAT_NAMES[index], 12, DIM_TEXT)
		caption.custom_minimum_size = Vector2(78.0, 0.0)
		row.add_child(caption)
		row.add_child(_bar(float(values[index])))
		box.add_child(row)
	card.gui_input.connect(_on_card_input.bind(id))
	return card


func _sidearm_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = Armory.ICONS[Armory.SIDEARM]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(56.0, 40.0)
	row.add_child(icon)
	var title := Armory.title(Armory.SIDEARM)
	row.add_child(_text("Sidearm: %s pistol, always carried (key 2 / GUN)" % title, 16, DIM_TEXT))
	return row


func _text(content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _bar(value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(118.0, 7.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1.0, 1.0, 1.0, 0.12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BAR_COLOR
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _highlight() -> void:
	for id: int in _styles:
		(_styles[id] as StyleBoxFlat).border_color = PICKED_BORDER if id == selected else IDLE_BORDER


func _on_card_input(event: InputEvent, id: int) -> void:
	var mouse := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	var clicked := mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if clicked or (touch != null and touch.pressed):
		pick(id)
