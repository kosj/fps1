extends CanvasLayer
## 시작 화면. 봇 대전, 사격 연습장, 서버 접속 중 하나를 고른다.
## 웹 빌드에 한글 글꼴이 없어 문구는 영문이다.

signal start_requested(kind: String, options: Dictionary)

const MenuKit := preload("res://game/ui/menu_kit.gd")
const Settings := preload("res://game/core/settings.gd")
const DEFAULT_ADDRESS := "127.0.0.1:7777"

var play_button: Button
var range_button: Button
var join_button: Button
var address_edit: LineEdit
var bot_count: SpinBox
var mode_select: OptionButton


func _ready() -> void:
	layer = 20
	var column := MenuKit.centered_column(self, Color(0.07, 0.08, 0.1, 1.0))
	column.add_child(MenuKit.label("FPS1", 48))
	column.add_child(_spacer(6.0))

	play_button = MenuKit.button("PLAY VS BOTS")
	play_button.pressed.connect(_on_play)
	column.add_child(play_button)

	var bots_row := HBoxContainer.new()
	bots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bots_row.add_theme_constant_override("separation", 12)
	bots_row.add_child(MenuKit.label("Bots", 18))
	bot_count = SpinBox.new()
	bot_count.min_value = 1
	bot_count.max_value = 11
	bot_count.value = int(Settings.read(Settings.BOT_COUNT, 5))
	bots_row.add_child(bot_count)
	mode_select = OptionButton.new()
	mode_select.add_item("Team deathmatch")
	mode_select.add_item("Domination")
	mode_select.selected = 1 if str(Settings.read(Settings.GAME_MODE, "tdm")) == "dom" else 0
	bots_row.add_child(mode_select)
	column.add_child(bots_row)

	range_button = MenuKit.button("SHOOTING RANGE")
	range_button.pressed.connect(func() -> void: start_requested.emit("range", {}))
	column.add_child(range_button)
	column.add_child(_spacer(4.0))

	address_edit = LineEdit.new()
	address_edit.text = str(Settings.read(Settings.SERVER_ADDRESS, DEFAULT_ADDRESS))
	address_edit.placeholder_text = "host:port or wss://address"
	address_edit.custom_minimum_size = Vector2(320.0, 38.0)
	address_edit.add_theme_font_size_override("font_size", 18)
	column.add_child(address_edit)
	join_button = MenuKit.button("JOIN SERVER")
	join_button.pressed.connect(_on_join)
	column.add_child(join_button)
	column.add_child(_spacer(4.0))

	column.add_child(MenuKit.sensitivity_row(Callable()))
	column.add_child(MenuKit.ui_scale_row(get_tree()))
	if not OS.has_feature("web"):
		var quit_button := MenuKit.button("QUIT")
		quit_button.pressed.connect(func() -> void: get_tree().quit())
		column.add_child(quit_button)


func _on_play() -> void:
	var bots := int(bot_count.value)
	var game_mode := "dom" if mode_select.selected == 1 else "tdm"
	Settings.write(Settings.BOT_COUNT, bots)
	Settings.write(Settings.GAME_MODE, game_mode)
	start_requested.emit("bots", {"bots": bots, "mode": game_mode})


func _on_join() -> void:
	var address := address_edit.text.strip_edges()
	if address.is_empty():
		return
	Settings.write(Settings.SERVER_ADDRESS, address)
	start_requested.emit("join", {"address": address})


func _spacer(height: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0.0, height)
	return node
