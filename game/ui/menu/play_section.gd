extends VBoxContainer
## 시작 화면의 PLAY 판: 경기 방식 카드, 맵 카드(미리보기 사진), 봇 수와 난이도, START MATCH.
## 고른 값은 설정에 저장해 다음에 열 때 그대로 보인다.

signal start_requested(options: Dictionary)

const UiStyle := preload("res://game/ui/ui_style.gd")
const MenuKit := preload("res://game/ui/menu_kit.gd")
const Settings := preload("res://game/core/settings.gd")
const Catalog := preload("res://maps/catalog.gd")
const MODES := [
	["tdm", "TEAM DEATHMATCH", "skull", "First team to 30 kills"],
	["dom", "DOMINATION", "flag", "Hold zones A B C, first to 150"],
]
const DIFFICULTIES := ["easy", "normal", "hard"]
## 맵 카드의 한 줄 소개.
const MAP_NOTES := {
	"depot": "Container yard  ·  open lanes",
	"compound": "Mud-brick village  ·  close quarters",
	"outpost": "Snowy mountain base  ·  three lanes",
}
const THUMBS := "res://game/ui/maps/%s.jpg"

var play_button: Button
var bot_count: SpinBox

var _modes := ButtonGroup.new()
var _maps := ButtonGroup.new()
var _levels := ButtonGroup.new()
var _compact := false


## compact이면(가로 휴대폰) 카드와 사진을 작게 만든다.
func _init(compact: bool) -> void:
	_compact = compact
	add_theme_constant_override("separation", 6 if compact else 10)
	add_child(UiStyle.caption("Game mode"))
	var modes := UiStyle.row(8)
	add_child(modes)
	var saved_mode := str(Settings.read(Settings.GAME_MODE, "tdm"))
	for mode: Array in MODES:
		modes.add_child(_mode_card(mode, mode[0] == saved_mode))
	add_child(UiStyle.caption("Map"))
	var maps := UiStyle.row(8)
	add_child(maps)
	var saved_map := str(Settings.read(Settings.MAP, "depot"))
	var names := Catalog.names()
	var titles := Catalog.titles()
	for index in names.size():
		maps.add_child(_map_card(names[index], titles[index], names[index] == saved_map))
	if _maps.get_pressed_button() == null:
		_maps.get_buttons()[0].button_pressed = true
	add_child(_options_row())
	add_child(UiStyle.spacer(0.0, 2.0))
	play_button = MenuKit.icon_button("START MATCH", "play", "PrimaryButton")
	play_button.custom_minimum_size = Vector2(0.0, 46.0 if compact else 52.0)
	play_button.pressed.connect(_on_play)
	add_child(play_button)


func selected_mode() -> String:
	return str(_modes.get_pressed_button().get_meta("value", "tdm"))


func selected_map() -> String:
	return str(_maps.get_pressed_button().get_meta("value", "depot"))


func selected_difficulty() -> String:
	return str(_levels.get_pressed_button().get_meta("value", "normal"))


func _on_play() -> void:
	var options := {
		"bots": int(bot_count.value), "mode": selected_mode(),
		"difficulty": selected_difficulty(), "map": selected_map(),
	}
	Settings.write(Settings.BOT_COUNT, options["bots"])
	Settings.write(Settings.GAME_MODE, options["mode"])
	Settings.write(Settings.DIFFICULTY, options["difficulty"])
	Settings.write(Settings.MAP, options["map"])
	start_requested.emit(options)


func _mode_card(mode: Array, on: bool) -> Button:
	var card := _toggle(_modes, mode[0], on)
	card.custom_minimum_size = Vector2(0.0, 46.0 if _compact else 62.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UiStyle.row(12)
	_fill(card, row)
	row.add_child(UiStyle.icon(mode[2], UiStyle.SIZE_XL if not _compact else UiStyle.SIZE_L,
		UiStyle.ACCENT))
	var text := UiStyle.column(0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	text.add_child(UiStyle.label(mode[1], UiStyle.SIZE_L if not _compact else UiStyle.SIZE_M,
		Color.WHITE, UiStyle.display_font()))
	text.add_child(UiStyle.label(mode[3], UiStyle.SIZE_XS, UiStyle.TEXT_DIM))
	return card


func _map_card(map_name: String, title: String, on: bool) -> Button:
	var card := _toggle(_maps, map_name, on)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 100.0 if _compact else 160.0)
	var column := UiStyle.column(4)
	_fill(card, column)
	var picture := TextureRect.new()
	var path := THUMBS % map_name
	if ResourceLoader.exists(path):
		picture.texture = load(path)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.custom_minimum_size = Vector2(0.0, 58.0 if _compact else 92.0)
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(picture)
	column.add_child(UiStyle.label(title.to_upper(), UiStyle.SIZE_M, Color.WHITE,
		UiStyle.display_font()))
	if not _compact:
		column.add_child(UiStyle.label(str(MAP_NOTES.get(map_name, "")), UiStyle.SIZE_XS,
			UiStyle.TEXT_DIM))
	return card


func _options_row() -> Control:
	var row := UiStyle.row(18)
	var bots := UiStyle.column(4)
	bots.add_child(UiStyle.caption("Bots"))
	bot_count = SpinBox.new()
	bot_count.min_value = 1
	bot_count.max_value = 11
	bot_count.value = int(Settings.read(Settings.BOT_COUNT, 5))
	bot_count.custom_minimum_size = Vector2(96.0, 0.0)
	bot_count.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bots.add_child(bot_count)
	row.add_child(bots)
	var difficulty := UiStyle.column(4)
	difficulty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty.add_child(UiStyle.caption("Bot difficulty"))
	var levels := UiStyle.row(0)
	difficulty.add_child(levels)
	var saved := Settings.difficulty()
	for level: String in DIFFICULTIES:
		var button := _toggle(_levels, level, level == saved)
		button.text = level.to_upper()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme_type_variation = ""
		levels.add_child(button)
	if _levels.get_pressed_button() == null:
		_levels.get_buttons()[1].button_pressed = true
	row.add_child(difficulty)
	return row


func _toggle(group: ButtonGroup, value: String, on: bool) -> Button:
	var button := Button.new()
	button.theme_type_variation = "CardButton"
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = on
	button.set_meta("value", value)
	return button


## 버튼 안에 레이아웃을 채운다(버튼 글자 대신 여러 줄과 그림을 넣는다).
func _fill(button: Button, content: Control) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vertical := 5 if _compact else 8
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side,
			10 if side in ["left", "right"] else vertical)
	margin.add_child(content)
	button.add_child(margin)
	# Button은 자식 크기를 최소 크기에 넣지 않으므로, 내용이 넘치지 않게 높이를 맞춘다.
	var base := button.custom_minimum_size.y
	var fit := func() -> void:
		button.custom_minimum_size.y = maxf(base, margin.get_combined_minimum_size().y)
	margin.minimum_size_changed.connect(fit)
	fit.call_deferred()
