extends CanvasLayer
## 전투 HUD. 배치(데스크톱 1280x720 기준, 가로 휴대폰은 약 1040x480):
## - 위 가운데: 점수판(아군·시간·적, 목표 점수 막대, 경기 방식, 점령전 거점)
## - 왼쪽 위: 킬 로그 / 왼쪽 아래: 체력 / 오른쪽 아래: 무기·탄약·수류탄(터치에서는 오른쪽 위)
## - 가운데: 조준선과 히트마커, 죽었을 때 KILLED BY 카드, 판이 끝나면 결과와 점수판
## 모양은 ui_style.gd의 토큰을 따른다. 웹 빌드의 글꼴에 한글이 없어 문구는 영문이다.

const UiStyle := preload("res://game/ui/ui_style.gd")
const Crosshair := preload("res://game/ui/crosshair.gd")
const ScoreBar := preload("res://game/ui/hud/score_bar.gd")
const KillFeed := preload("res://game/ui/hud/kill_feed.gd")
const AmmoPanel := preload("res://game/ui/hud/ammo_panel.gd")
const HealthBar := preload("res://game/ui/hud/health_bar.gd")
const Scoreboard := preload("res://game/ui/hud/scoreboard.gd")
const ResultBanner := preload("res://game/ui/hud/result_banner.gd")
const DeathCard := preload("res://game/ui/hud/death_card.gd")
const MARGIN := 22
const NARROW_WIDTH := 760.0
## 화면 높이(캔버스 단위)가 이보다 낮으면 결과와 점수판을 작게 그린다.
const SHORT_HEIGHT := 600.0
const NOTICE_TIME := 2.0

var _root: Control
var _crosshair: Crosshair
var _damage: TextureRect
var _score: ScoreBar
var _feed: KillFeed
var _ammo: AmmoPanel
var _health: HealthBar
var _death: DeathCard
var _notice: PanelContainer
var _notice_label: Label
var _notice_left := 0.0
var _hint: Control
var _dim: ColorRect
var _stack: VBoxContainer
var _result: ResultBanner
var _scoreboard: Scoreboard
var _touch: Control
var _frags := 2
var _flashes := 1


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_damage = _damage_vignette()
	_root.add_child(_damage)
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair)

	_score = ScoreBar.new()
	_place(_score, Control.PRESET_CENTER_TOP, Vector2(0.0, 8.0))
	_feed = KillFeed.new()
	_place(_feed, Control.PRESET_TOP_LEFT, Vector2(MARGIN, MARGIN))
	_ammo = AmmoPanel.new()
	_place(_ammo, Control.PRESET_BOTTOM_RIGHT, Vector2(-MARGIN, -MARGIN + 4))
	_health = HealthBar.new()
	_place(_health, Control.PRESET_BOTTOM_LEFT, Vector2(MARGIN, -MARGIN))

	_death = DeathCard.new()
	_place(_death, Control.PRESET_CENTER, Vector2(0.0, 110.0))
	_death.visible = false
	_notice = UiStyle.panel(UiStyle.margins(UiStyle.box(Color(0, 0, 0, 0.6)), 14, 5))
	_notice_label = UiStyle.label("", UiStyle.SIZE_S, UiStyle.TEXT, UiStyle.caps_font())
	_notice.add_child(_notice_label)
	_place(_notice, Control.PRESET_CENTER_TOP, Vector2(0.0, 120.0))
	_notice.visible = false
	_hint = _controls_hint()
	_place(_hint, Control.PRESET_CENTER_BOTTOM, Vector2(0.0, -110.0))


## 터치 조작용 배치. 오른쪽 아래는 버튼이 차지하므로 탄약을 오른쪽 위로 옮기고 체력은 왼쪽 아래에 둔다.
## controls는 터치 조작 노드(수류탄 수를 버튼에 표시하는 데 쓴다).
func use_touch_layout(controls: Control = null) -> void:
	_touch = controls
	if _touch != null:
		_touch.set("badges", {"grenade": _frags, "tactical": _flashes})
	_ammo.set_compact(true)
	_place(_ammo, Control.PRESET_TOP_RIGHT, Vector2(-MARGIN, 70.0))
	_place(_health, Control.PRESET_BOTTOM_LEFT, Vector2(MARGIN, -14.0))
	_health.custom_minimum_size.x = 180.0
	_place(_feed, Control.PRESET_TOP_LEFT, Vector2(16.0, 14.0))
	_hint.visible = false


func set_ammo(ammo: int, magazine_size: int) -> void:
	_ammo.set_ammo(ammo, magazine_size)


func set_health(health: float, max_health: float) -> void:
	_health.set_health(health, max_health)


## 화면이 좁은지(세로로 든 휴대폰).
func is_narrow() -> bool:
	return is_inside_tree() and get_viewport().get_visible_rect().size.x < NARROW_WIDTH


## 위 가운데 점수판. limit는 목표 점수, mode_title은 경기 방식 이름.
func set_match_score(mine: int, theirs: int, seconds: int, limit: int, mode_title: String) -> void:
	_score.set_score(mine, theirs, seconds, limit, mode_title)


## 죽었을 때의 KILLED BY 카드. killer가 비어 있으면 RESPAWNING만.
func set_death(dead: bool, killer: String) -> void:
	_death.visible = dead
	if dead:
		_death.show_killer(killer)


## 판 결과. outcome이 비어 있으면 숨긴다(victory, defeat, draw).
func set_result(outcome: String, mine: int, theirs: int, xp_line: String) -> void:
	if outcome.is_empty():
		if _result != null:
			_dim.visible = false
			_result.visible = false
		return
	_center_stack()
	if _result == null:
		_result = ResultBanner.new()
		_stack.add_child(_result)
		_stack.move_child(_result, 0)
	_result.compact = _is_short()
	_result.show_result(outcome, mine, theirs, xp_line)
	_dim.visible = true
	_result.visible = true


## 점수판. lines는 [팀, 이름, 킬, 데스, 나인지, 봇인지]. 내 팀이 왼쪽에 온다.
func set_scoreboard(shown: bool, lines: Array, own_team: int) -> void:
	if _scoreboard == null:
		if not shown:
			return
		_center_stack()
		_scoreboard = Scoreboard.new()
		_stack.add_child(_scoreboard)
	_scoreboard.visible = shown
	if shown:
		_scoreboard.compact = _is_short()
		_scoreboard.set_lines(lines, own_team)


func flash_damage() -> void:
	_damage.modulate.a = 1.0


## 점령전 거점. 각 항목은 [글자, 주인 색, 주인이 있는지, 점령 중인 쪽 색, 진행도].
func set_zones(items: Array) -> void:
	_score.set_zones(items)


## 킬 로그 한 줄. mine이면 나와 관련된 줄로 강조한다.
func add_kill(
	killer: String, killer_color: Color, victim: String, victim_color: Color,
	headshot: bool, mine: bool
) -> void:
	_feed.add(killer, killer_color, victim, victim_color, headshot, mine)


func set_damage_marks(marks: Array) -> void:
	_crosshair.damage_marks = marks


## 설정 변경 같은 짧은 알림을 2초간 보여 준다.
func show_notice(text: String) -> void:
	_notice_label.text = text.to_upper()
	_notice_left = NOTICE_TIME


func set_weapon(weapon_id: int, slot: int) -> void:
	_ammo.set_weapon(weapon_id, slot)


## 남은 수류탄(G)과 섬광탄(F).
func set_grenades(frags: int, flashes: int) -> void:
	_frags = frags
	_flashes = flashes
	_ammo.set_grenades(frags, flashes)
	if _touch != null:
		_touch.set("badges", {"grenade": frags, "tactical": flashes})


func set_reloading(reloading: bool) -> void:
	_ammo.set_reloading(reloading)


func set_hint_visible(shown: bool) -> void:
	_hint.visible = shown and _touch == null


func set_crosshair(spread_deg: float, aim_blend: float, fov: float, scope := 0.0) -> void:
	_crosshair.spread_deg = spread_deg
	_crosshair.aim_blend = aim_blend
	_crosshair.fov = fov
	_crosshair.scope_blend = scope


func show_hit(headshot: bool, killed: bool) -> void:
	_crosshair.flash_hit(headshot, killed)


func _process(delta: float) -> void:
	_damage.modulate.a = maxf(_damage.modulate.a - delta * 1.6, 0.0)
	_notice_left = maxf(_notice_left - delta, 0.0)
	_notice.visible = _notice_left > 0.0
	_notice.modulate.a = clampf(_notice_left * 3.0, 0.0, 1.0)
	if _touch != null:
		# 점수판이나 결과가 떠 있으면 터치 버튼을 흐리게 해 가리지 않게 한다(버튼은 그대로 눌린다).
		var board := _scoreboard != null and _scoreboard.visible
		var covered := board or (_result != null and _result.visible)
		_touch.modulate.a = move_toward(_touch.modulate.a, 0.22 if covered else 1.0, delta * 6.0)


## 화면 가운데에 세로로 쌓는 묶음(결과, 점수판)과 그 뒤를 어둡게 하는 막.
func _center_stack() -> void:
	if _stack != null:
		return
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = Color(0.01, 0.015, 0.02, 0.62)
	_dim.visible = false
	_root.add_child(_dim)
	_stack = VBoxContainer.new()
	_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_constant_override("separation", 14)
	_root.add_child(_stack)


func _is_short() -> bool:
	return get_viewport().get_visible_rect().size.y < SHORT_HEIGHT


## 화면 가장자리부터 붉게 번지는 피격 표시.
func _damage_vignette() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0.7, 0, 0, 0), Color(0.7, 0, 0, 0.05),
		Color(0.75, 0.02, 0.0, 0.7)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.05, 0.5)
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0
	return rect


## 데스크톱에서 처음 클릭하기 전에 보이는 조작 안내.
func _controls_hint() -> Control:
	var style := UiStyle.box(Color(0, 0, 0, 0.62), UiStyle.LINE, 1)
	var box := UiStyle.panel(UiStyle.margins(style, 18, 8))
	var column := UiStyle.column(4)
	box.add_child(column)
	var title := UiStyle.label("CLICK TO PLAY", UiStyle.SIZE_L, UiStyle.ACCENT,
		UiStyle.display_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var keys := (
		"WASD MOVE   SHIFT SPRINT   CTRL SLIDE   SPACE JUMP   "
		+ "1 / 2 WEAPONS   G FRAG   F FLASH   V MELEE"
	)
	var line := UiStyle.caption(keys, UiStyle.TEXT_DIM, 12)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(line)
	return box


## 앵커 한 곳에 붙이고, 그 앵커를 기준으로 offset만큼 옮긴다. 크기는 내용을 따른다.
func _place(node: Control, preset: Control.LayoutPreset, offset: Vector2) -> void:
	if node.get_parent() == null:
		_root.add_child(node)
	node.set_anchors_preset(preset)
	var grow_x := Control.GROW_DIRECTION_BOTH
	var grow_y := Control.GROW_DIRECTION_BOTH
	match preset:
		Control.PRESET_TOP_LEFT:
			grow_x = Control.GROW_DIRECTION_END
			grow_y = Control.GROW_DIRECTION_END
		Control.PRESET_TOP_RIGHT:
			grow_x = Control.GROW_DIRECTION_BEGIN
			grow_y = Control.GROW_DIRECTION_END
		Control.PRESET_BOTTOM_LEFT:
			grow_x = Control.GROW_DIRECTION_END
			grow_y = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_RIGHT:
			grow_x = Control.GROW_DIRECTION_BEGIN
			grow_y = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_TOP:
			grow_y = Control.GROW_DIRECTION_END
		Control.PRESET_CENTER_BOTTOM:
			grow_y = Control.GROW_DIRECTION_BEGIN
	node.grow_horizontal = grow_x
	node.grow_vertical = grow_y
	node.offset_left = offset.x
	node.offset_right = offset.x
	node.offset_top = offset.y
	node.offset_bottom = offset.y
