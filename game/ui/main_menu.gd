extends CanvasLayer
## 시작 화면. 봇 대전, 사격 연습장, 서버 접속 중 하나를 고른다.
## 웹 빌드에 한글 글꼴이 없어 문구는 영문이다.

signal start_requested(kind: String, options: Dictionary)

const MenuKit := preload("res://game/ui/menu_kit.gd")
const Settings := preload("res://game/core/settings.gd")
## 공용 서버(Render 무료 요금제). 예전 기본값(내 PC)이 저장돼 있으면 이 주소로 바꿔 보여 준다.
const DEFAULT_ADDRESS := "wss://fps1-server.onrender.com"
const OLD_DEFAULT_ADDRESS := "127.0.0.1:7777"
const DIFFICULTIES := ["easy", "normal", "hard"]
const BACKDROP_MAP := "res://maps/depot/depot.tscn"
const RemoteAvatar := preload("res://game/player/remote_avatar.gd")
## 배경 카메라가 맵 가운데를 도는 반지름, 높이, 한 바퀴 시간(초).
const ORBIT_RADIUS := 17.0
const ORBIT_HEIGHT := 5.5
const ORBIT_PERIOD := 90.0

## 시작 화면에 한 번 보여 줄 알림(접속 실패 이유 등). 화면을 다시 불러와도 남도록 static이다.
static var notice := ""

var play_button: Button
var range_button: Button
var join_button: Button
var address_edit: LineEdit
var bot_count: SpinBox
var mode_select: OptionButton
var difficulty_select: OptionButton
var low_graphics: CheckButton

var _camera: Camera3D
var _orbit := 0.6


func _ready() -> void:
	layer = 20
	_build_backdrop()
	var column := MenuKit.centered_column(self, Color(0.04, 0.05, 0.07, 0.68))
	column.add_child(MenuKit.label("FPS1", 48))
	if notice != "":
		var notice_label := MenuKit.label(notice, 20)
		notice_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
		column.add_child(notice_label)
		notice = ""
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

	var options_row := HBoxContainer.new()
	options_row.alignment = BoxContainer.ALIGNMENT_CENTER
	options_row.add_theme_constant_override("separation", 12)
	difficulty_select = OptionButton.new()
	for level: String in DIFFICULTIES:
		difficulty_select.add_item("Bots: %s" % level.capitalize())
	difficulty_select.selected = maxi(DIFFICULTIES.find(Settings.difficulty()), 0)
	options_row.add_child(difficulty_select)
	low_graphics = CheckButton.new()
	low_graphics.text = "Low graphics"
	low_graphics.button_pressed = Settings.low_graphics()
	low_graphics.toggled.connect(
		func(enabled: bool) -> void: Settings.write(Settings.LOW_GRAPHICS, enabled)
	)
	options_row.add_child(low_graphics)
	column.add_child(options_row)

	range_button = MenuKit.button("SHOOTING RANGE")
	range_button.pressed.connect(func() -> void: start_requested.emit("range", {}))
	column.add_child(range_button)
	column.add_child(_spacer(4.0))

	address_edit = LineEdit.new()
	var saved := str(Settings.read(Settings.SERVER_ADDRESS, DEFAULT_ADDRESS))
	address_edit.text = DEFAULT_ADDRESS if saved == OLD_DEFAULT_ADDRESS else saved
	address_edit.placeholder_text = "host:port or wss://address"
	address_edit.custom_minimum_size = Vector2(320.0, 38.0)
	address_edit.add_theme_font_size_override("font_size", 18)
	column.add_child(address_edit)
	join_button = MenuKit.button("PLAY ONLINE")
	join_button.pressed.connect(_on_join)
	column.add_child(join_button)
	column.add_child(_spacer(4.0))

	column.add_child(MenuKit.sensitivity_row(Callable()))
	column.add_child(MenuKit.ui_scale_row(get_tree()))
	column.add_child(MenuKit.touch_toggle(Callable()))
	var device := "mobile" if Settings.is_mobile() else "desktop"
	var info := "build %s  |  detected: %s" % [Settings.build_version(), device]
	column.add_child(MenuKit.label(info, 14))
	if not OS.has_feature("web"):
		var quit_button := MenuKit.button("QUIT")
		quit_button.pressed.connect(func() -> void: get_tree().quit())
		column.add_child(quit_button)


func _on_play() -> void:
	var bots := int(bot_count.value)
	var game_mode := "dom" if mode_select.selected == 1 else "tdm"
	Settings.write(Settings.BOT_COUNT, bots)
	var difficulty: String = DIFFICULTIES[difficulty_select.selected]
	Settings.write(Settings.GAME_MODE, game_mode)
	Settings.write(Settings.DIFFICULTY, difficulty)
	start_requested.emit("bots", {"bots": bots, "mode": game_mode, "difficulty": difficulty})


func _on_join() -> void:
	var address := address_edit.text.strip_edges()
	if address.is_empty():
		return
	Settings.write(Settings.SERVER_ADDRESS, address)
	start_requested.emit("join", {"address": address})


func _process(delta: float) -> void:
	if _camera == null:
		return
	_orbit += delta * TAU / ORBIT_PERIOD
	_camera.position = Vector3(cos(_orbit) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(_orbit) * ORBIT_RADIUS)
	_camera.look_at(Vector3(0.0, 1.2, 0.0))


## 메뉴 뒤에 보이는 배경: 실제 맵을 천천히 도는 카메라와 서 있는 병사 몇 명.
## 메뉴가 닫히면 함께 사라진다. 낮은 그래픽 설정에서는 만들지 않는다.
func _build_backdrop() -> void:
	if Settings.low_graphics() or not ResourceLoader.exists(BACKDROP_MAP):
		return
	var backdrop := Node3D.new()
	add_child(backdrop)
	backdrop.add_child((load(BACKDROP_MAP) as PackedScene).instantiate())
	var poses := [
		[Vector3(-2.5, 0.0, 3.0), 2.4, Color(0.25, 0.45, 0.8), false],
		[Vector3(-4.2, 0.0, 4.4), 2.9, Color(0.25, 0.45, 0.8), true],
		[Vector3(3.0, 0.0, -3.5), -0.6, Color(0.75, 0.25, 0.2), false],
	]
	for pose: Array in poses:
		var soldier := RemoteAvatar.new()
		backdrop.add_child(soldier)
		soldier.position = pose[0]
		soldier.rotation.y = pose[1]
		soldier.set_color(pose[2])
		soldier.set_pose(pose[3], true)
	_camera = Camera3D.new()
	_camera.fov = 60.0
	backdrop.add_child(_camera)
	_camera.make_current()


func _spacer(height: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0.0, height)
	return node
