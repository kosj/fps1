extends CanvasLayer
## 시작 화면. 왼쪽에 큰 메뉴(PLAY, ONLINE, LOADOUT, RANGE, SETTINGS), 오른쪽에 고른 메뉴의 판,
## 위 오른쪽에 내 카드(레벨, 이름, 경험치). 뒤에는 실제 맵을 천천히 도는 카메라
## (저사양 설정에서는 같은 맵의 사진)를 깔고 왼쪽을 어둡게 해 글씨가 잘 보이게 한다.
## 웹 빌드의 글꼴에 한글이 없어 문구는 영문이다.

signal start_requested(kind: String, options: Dictionary)

const MenuKit := preload("res://game/ui/menu_kit.gd")
const UiStyle := preload("res://game/ui/ui_style.gd")
const PlaySection := preload("res://game/ui/menu/play_section.gd")
const Settings := preload("res://game/core/settings.gd")
const Armory := preload("res://game/weapons/armory.gd")
const LoadoutPanel := preload("res://game/ui/loadout_panel.gd")
const Progression := preload("res://game/core/progression.gd")
const Names := preload("res://game/core/names.gd")
const MenuMusic := preload("res://game/audio/menu_music.gd")
## 공용 서버(Render 무료 요금제). 예전 기본값(내 PC)이 저장돼 있으면 이 주소로 바꿔 보여 준다.
const DEFAULT_ADDRESS := "wss://fps1-server.onrender.com"
const OLD_DEFAULT_ADDRESS := "127.0.0.1:7777"
const BACKDROP_MAP := "res://maps/depot/depot.tscn"
const BACKDROP_PICTURE := "res://game/ui/maps/backdrop.jpg"
const RemoteAvatar := preload("res://game/player/remote_avatar.gd")
## 배경 카메라가 맵 가운데를 도는 반지름, 높이, 한 바퀴 시간(초).
const ORBIT_RADIUS := 17.0
const ORBIT_HEIGHT := 5.5
const ORBIT_PERIOD := 90.0
## 화면 높이가 이보다 낮으면(가로로 든 휴대폰) 판과 글씨를 줄인다.
const SHORT_HEIGHT := 620.0
const SECTIONS := [
	["play", "PLAY"], ["online", "ONLINE"], ["loadout", "LOADOUT"],
	["range", "RANGE"], ["settings", "SETTINGS"],
]

## 시작 화면에 한 번 보여 줄 알림(접속 실패 이유 등). 화면을 다시 불러와도 남도록 static이다.
static var notice := ""

var play_button: Button
var range_button: Button
var join_button: Button
var loadout_button: Button
var address_edit: LineEdit
var name_edit: LineEdit
var bot_count: SpinBox
var low_graphics: CheckButton
var music_toggle: CheckButton

var _camera: Camera3D
var _orbit := 0.6
var _compact := false
var _play: PlaySection
var _sections := {}
var _nav := {}
var _nav_group := ButtonGroup.new()
var _loadout_label: Label
var _music: MenuMusic


func _ready() -> void:
	layer = 20
	_compact = get_viewport().get_visible_rect().size.y < SHORT_HEIGHT
	_build_backdrop()
	_music = MenuMusic.new()
	add_child(_music)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(_shade())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var edge := 18 if _compact else 36
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, edge)
	margin.add_theme_constant_override("margin_top", 12 if _compact else 26)
	margin.add_theme_constant_override("margin_bottom", 10 if _compact else 22)
	root.add_child(margin)
	var page := UiStyle.column(10 if _compact else 18)
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(page)
	page.add_child(_top_bar())
	var body := UiStyle.row(18 if _compact else 40)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(body)
	body.add_child(_nav_column())
	var content := UiStyle.column(0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(content)
	_build_sections(content)
	show_section("play")


## 오른쪽 판을 바꾼다(play, online, loadout, range, settings).
func show_section(section: String) -> void:
	for key: String in _sections:
		(_sections[key] as Control).visible = key == section
	if _nav.has(section):
		(_nav[section] as Button).button_pressed = true


## 로드아웃 화면을 연다. 고른 주무기는 저장해 두고 다음 경기부터 쓴다.
func open_loadout() -> LoadoutPanel:
	var panel := LoadoutPanel.new()
	panel.selected = _saved_primary()
	panel.chosen.connect(
		func(id: int) -> void:
			Settings.write(Settings.PRIMARY, id)
			_show_loadout()
	)
	add_child(panel)
	return panel


func _process(delta: float) -> void:
	if _camera == null:
		return
	_orbit += delta * TAU / ORBIT_PERIOD
	_camera.position = Vector3(cos(_orbit) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(_orbit) * ORBIT_RADIUS)
	_camera.look_at(Vector3(0.0, 1.2, 0.0))


func _top_bar() -> Control:
	var bar := UiStyle.row(14)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	var brand := UiStyle.column(0)
	bar.add_child(brand)
	brand.add_child(UiStyle.label("FPS1", 40 if _compact else 56, Color.WHITE, UiStyle.display_font()))
	brand.add_child(UiStyle.caption("Tactical arena shooter", UiStyle.ACCENT, 12))
	bar.add_child(UiStyle.spacer(0.0, 0.0, true))
	if notice != "":
		var warning := UiStyle.panel(UiStyle.margins(UiStyle.stripe_box(Color(0, 0, 0, 0.6),
			UiStyle.ENEMY, 3), 12, 6))
		warning.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		warning.add_child(UiStyle.label(notice, UiStyle.SIZE_S, Color(1.0, 0.75, 0.68)))
		bar.add_child(warning)
		notice = ""
	bar.add_child(_player_card())
	return bar


## 내 카드: 레벨 숫자 상자, 이름 칸(온라인에서 다른 사람에게 보이는 이름), 경험치 막대.
func _player_card() -> Control:
	var xp := Progression.saved_xp()
	var progress := Progression.progress_in_level(xp)
	var card := UiStyle.panel(UiStyle.margins(UiStyle.box(UiStyle.PANEL_SOFT, UiStyle.LINE, 1), 8, 8))
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := UiStyle.row(12)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(row)
	var badge := UiStyle.panel(UiStyle.margins(UiStyle.box(UiStyle.ACCENT), 0, 0))
	badge.custom_minimum_size = Vector2(52.0, 52.0)
	var level := UiStyle.label(str(Progression.level_for(xp)), UiStyle.SIZE_XL,
		UiStyle.ACCENT_DARK, UiStyle.FONT_DISPLAY)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(level)
	row.add_child(badge)
	var info := UiStyle.column(3)
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(info)
	name_edit = LineEdit.new()
	name_edit.text = Names.saved()
	name_edit.max_length = Names.MAX_LENGTH
	name_edit.custom_minimum_size = Vector2(180.0, 0.0)
	name_edit.add_theme_font_size_override("font_size", UiStyle.SIZE_M)
	name_edit.add_theme_stylebox_override("normal",
		UiStyle.margins(UiStyle.box(Color(0, 0, 0, 0.25)), 8, 3))
	name_edit.add_theme_stylebox_override("focus",
		UiStyle.margins(UiStyle.box(Color(0, 0, 0, 0.45), UiStyle.ACCENT, 1), 8, 3))
	name_edit.text_changed.connect(_on_name_changed)
	info.add_child(name_edit)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(180.0, 5.0)
	bar.show_percentage = false
	bar.max_value = maxf(float(progress[1]), 1.0)
	bar.value = float(progress[0]) if int(progress[1]) > 0 else bar.max_value
	info.add_child(bar)
	var text := "MAX LEVEL" if int(progress[1]) == 0 else "%d / %d XP" % [progress[0], progress[1]]
	info.add_child(UiStyle.caption(text, UiStyle.TEXT_DIM, 11))
	return card


func _nav_column() -> Control:
	var nav := UiStyle.column(2 if _compact else 6)
	nav.custom_minimum_size = Vector2(200.0 if _compact else 260.0, 0.0)
	nav.mouse_filter = Control.MOUSE_FILTER_PASS
	for item: Array in SECTIONS:
		var button := Button.new()
		button.text = item[1]
		button.theme_type_variation = "NavButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = _nav_group
		if _compact:
			button.add_theme_font_size_override("font_size", UiStyle.SIZE_L + 4)
		button.pressed.connect(show_section.bind(item[0]))
		nav.add_child(button)
		_nav[item[0]] = button
	if not OS.has_feature("web"):
		var quit_button := Button.new()
		quit_button.text = "QUIT"
		quit_button.theme_type_variation = "NavButton"
		quit_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if _compact:
			quit_button.add_theme_font_size_override("font_size", UiStyle.SIZE_L + 4)
		quit_button.pressed.connect(func() -> void: get_tree().quit())
		nav.add_child(quit_button)
	nav.add_child(UiStyle.spacer(0.0, 0.0, false))
	var filler := UiStyle.spacer()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(filler)
	var device := "MOBILE" if Settings.is_mobile() else "DESKTOP"
	var build := Settings.build_version()
	nav.add_child(UiStyle.caption("BUILD %s  ·  %s" % [build if build != "" else "DEV", device],
		UiStyle.TEXT_FAINT, 11))
	return nav


func _build_sections(content: VBoxContainer) -> void:
	_play = PlaySection.new(_compact)
	_play.start_requested.connect(func(options: Dictionary) -> void:
		start_requested.emit("bots", options))
	play_button = _play.play_button
	bot_count = _play.bot_count
	_add_section(content, "play", "Quick match vs bots", _play)
	_add_section(content, "online", "Play online", _online_section())
	_add_section(content, "loadout", "Loadout", _loadout_section())
	_add_section(content, "range", "Shooting range", _range_section())
	_add_section(content, "settings", "Settings", _settings_section())


func _add_section(content: VBoxContainer, key: String, title: String, body: Control) -> void:
	var style := UiStyle.box(Color(0.04, 0.045, 0.055, 0.8), UiStyle.LINE, 1)
	var panel := UiStyle.panel(UiStyle.margins(style, 16 if _compact else 24, 12 if _compact else 20))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UiStyle.column(8 if _compact else 14)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(column)
	var heading := UiStyle.label(title.to_upper(), UiStyle.SIZE_L + 2 if _compact else UiStyle.SIZE_XL,
		Color.WHITE, UiStyle.display_font())
	# 가로 휴대폰에서는 PLAY 판이 화면에 다 들어가도록 제목을 뺀다(왼쪽 메뉴가 이미 알려 준다).
	heading.visible = not (_compact and key == "play")
	column.add_child(heading)
	column.add_child(body)
	content.add_child(panel)
	_sections[key] = panel


func _online_section() -> Control:
	var column := UiStyle.column(10)
	column.add_child(UiStyle.caption("Server address"))
	address_edit = LineEdit.new()
	var saved := str(Settings.read(Settings.SERVER_ADDRESS, DEFAULT_ADDRESS))
	address_edit.text = DEFAULT_ADDRESS if saved == OLD_DEFAULT_ADDRESS else saved
	address_edit.placeholder_text = "host:port or wss://address"
	column.add_child(address_edit)
	var note := UiStyle.label(
		"The public server sleeps when nobody plays. The first connection can take up to a minute.",
		UiStyle.SIZE_S, UiStyle.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	join_button = MenuKit.icon_button("CONNECT", "wifi", "PrimaryButton")
	join_button.pressed.connect(_on_join)
	column.add_child(join_button)
	return column


func _loadout_section() -> Control:
	var column := UiStyle.column(10)
	var row := UiStyle.row(16)
	column.add_child(row)
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(220.0, 90.0) if not _compact else Vector2(160.0, 64.0)
	picture.set_meta("primary_picture", true)
	row.add_child(picture)
	var text := UiStyle.column(2)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	text.add_child(UiStyle.caption("Primary"))
	_loadout_label = UiStyle.label("", UiStyle.SIZE_XL, Color.WHITE, UiStyle.display_font())
	text.add_child(_loadout_label)
	text.add_child(UiStyle.caption("Sidearm  %s" % Armory.title(Armory.SIDEARM), UiStyle.TEXT_DIM))
	loadout_button = MenuKit.icon_button("CHANGE WEAPON", "gun")
	loadout_button.pressed.connect(open_loadout)
	column.add_child(loadout_button)
	_show_loadout(picture)
	return column


func _range_section() -> Control:
	var column := UiStyle.column(10)
	var note := UiStyle.label(
		"Practice on targets at 10 to 60 m. Try every weapon, aim down sights and learn the recoil.",
		UiStyle.SIZE_S + 1, UiStyle.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	range_button = MenuKit.icon_button("ENTER RANGE", "bullseye", "PrimaryButton")
	range_button.pressed.connect(func() -> void: start_requested.emit("range", {}))
	column.add_child(range_button)
	return column


func _settings_section() -> Control:
	var column := UiStyle.column(6 if _compact else 10)
	column.add_child(MenuKit.sensitivity_row(Callable()))
	column.add_child(MenuKit.ui_scale_row(get_tree()))
	column.add_child(MenuKit.touch_toggle(Callable()))
	low_graphics = MenuKit.switch("Low graphics (faster on phones)", Settings.low_graphics())
	low_graphics.toggled.connect(
		func(enabled: bool) -> void: Settings.write(Settings.LOW_GRAPHICS, enabled)
	)
	column.add_child(low_graphics)
	music_toggle = MenuKit.switch("Menu music", bool(Settings.read(Settings.MUSIC, true)))
	music_toggle.toggled.connect(
		func(enabled: bool) -> void:
			Settings.write(Settings.MUSIC, enabled)
			_music.refresh()
	)
	column.add_child(music_toggle)
	return column


func _saved_primary() -> int:
	var saved := Armory.valid_primary(int(Settings.read(Settings.PRIMARY, Armory.DEFAULT_PRIMARY)))
	return Progression.allowed_primary(saved, Armory.DEFAULT_PRIMARY)


func _show_loadout(picture: TextureRect = null) -> void:
	var primary := _saved_primary()
	_loadout_label.text = Armory.title(primary).to_upper()
	if picture == null:
		for node in _sections.get("loadout", self).find_children("*", "TextureRect", true, false):
			if node.has_meta("primary_picture"):
				picture = node
	if picture != null:
		picture.texture = Armory.ICONS[primary]


func _on_name_changed(text: String) -> void:
	var clean := Names.sanitize(text)
	if not clean.is_empty():
		Settings.write(Names.KEY, clean)


func _on_join() -> void:
	var address := address_edit.text.strip_edges()
	if address.is_empty():
		return
	Settings.write(Settings.SERVER_ADDRESS, address)
	start_requested.emit("join", {"address": address})


## 배경을 왼쪽부터 어둡게 하는 막(글씨가 맵 위에서도 읽히게).
func _shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color(0.02, 0.025, 0.03, 0.92),
		Color(0.02, 0.025, 0.03, 0.72), Color(0.02, 0.025, 0.03, 0.35)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	var shade := TextureRect.new()
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade


## 메뉴 뒤에 보이는 배경: 실제 맵을 천천히 도는 카메라와 서 있는 병사 몇 명.
## 저사양 설정에서는 3D 대신 맵 사진을 깐다. 메뉴가 닫히면 함께 사라진다.
func _build_backdrop() -> void:
	if Settings.low_graphics() or not ResourceLoader.exists(BACKDROP_MAP):
		_build_picture_backdrop()
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


func _build_picture_backdrop() -> void:
	var back := ColorRect.new()
	back.color = UiStyle.INK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	if not ResourceLoader.exists(BACKDROP_PICTURE):
		return
	var picture := TextureRect.new()
	picture.texture = load(BACKDROP_PICTURE)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
