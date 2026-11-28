extends CharacterBody3D
## 플레이어 한 명. 입력(InputCmd)을 받아 이동과 무기를 시뮬레이션한다.
## 같은 스크립트가 세 곳에서 쓰인다.
## - 로컬 플레이어: 화면, HUD, 소리를 갖고 키보드와 마우스에서 입력을 만든다.
## - 서버 측 플레이어: 화면 없이 클라이언트가 보낸 입력으로 움직인다.
## - 클라이언트 예측: 서버 상태로 되돌린 뒤(restore_state) 밀린 입력을 다시 돌린다.
## 이동 수치와 계산은 MoveMath에 둔다.

signal health_changed(health: float)
## 수류탄을 던졌을 때. 판정 권한이 있는 쪽(서버, 로컬 대전)만 받아서 실제로 만든다.
## kind는 "frag"(수류탄) 또는 "flash"(섬광탄).
signal grenade_thrown(origin: Vector3, direction: Vector3, kind: String)
## 근접 공격을 휘둘렀을 때. 맞았는지는 판정 권한이 있는 쪽이 정한다.
signal melee_swung(origin: Vector3, direction: Vector3)

enum MoveState { NORMAL, SLIDING, MANTLING }

const MoveMath := preload("res://game/movement/move_math.gd")
const InputCmd := preload("res://game/player/input_cmd.gd")
const WeaponController := preload("res://game/weapons/weapon_controller.gd")
const ViewModel := preload("res://game/weapons/view_model.gd")
const Hud := preload("res://game/ui/hud.gd")
const TouchControls := preload("res://game/ui/touch_controls.gd")
const AimAssist := preload("res://game/player/aim_assist.gd")
const SfxSynth := preload("res://game/audio/sfx_synth.gd")
const Effects := preload("res://game/fx/effects.gd")
## ElevenLabs로 만든 효과음. 맞음/처치 알림음은 짧은 합성음을 그대로 쓴다.
const SFX_DRY := preload("res://game/audio/sfx/dry.ogg")
const SFX_RELOAD := preload("res://game/audio/sfx/reload.ogg")
const SFX_STEP := preload("res://game/audio/sfx/step.ogg")
const SFX_IMPACT := preload("res://game/audio/sfx/impact.ogg")
const Armory := preload("res://game/weapons/armory.gd")
const Settings := preload("res://game/core/settings.gd")
## 예측 보정으로 생긴 위치 차이를 화면에서 풀어 주는 속도와, 보간하지 않고 바로 옮기는 거리.
const CORRECTION_SMOOTHING := 12.0
## 근접 공격 사이의 간격과, 그중 총을 쏠 수 없는 앞부분(초).
const MELEE_COOLDOWN := 0.9
const MELEE_BUSY := 0.45
const CORRECTION_SNAP_DISTANCE := 2.0
const DAMAGE_MARK_TIME := 1.5
## 터치로 화면을 끌 때의 시선 감도(화면 단위당 라디안).
const TOUCH_LOOK_SENSITIVITY := 0.0045
const BASE_SENSITIVITY := 0.002
const ADS_SENSITIVITY_SCALE := 0.6
const PITCH_LIMIT := 1.55
const BASE_FOV := 80.0
const SPRINT_FOV_BONUS := 4.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const STAND_EYE := 1.6
const CROUCH_EYE := 0.95
const SLIDE_EYE := 0.8
const MANTLE_REACH := 0.7
const FOOTSTEP_DISTANCE := 2.2
const WORLD_MASK := 1
const BODY_LAYER := 2
const MAX_HEALTH := 100.0

var move_state := MoveState.NORMAL
var crouching := false
var health := MAX_HEALTH
var alive := true
## 화면, HUD, 소리를 갖는 로컬 플레이어인지. 트리에 넣기 전에 정한다.
var is_local := true
## 스스로 입력을 읽어 틱을 돌린다. 세션이 틱을 직접 돌릴 때는 끈다.
var auto_simulate := true
## 입력에 담긴 시선 각도를 몸에 그대로 적용한다(서버 측 플레이어와 봇).
var view_from_cmd := false
## 헤드리스 테스트에는 포인터 잠금이 없으므로 끌 수 있게 한다.
var require_mouse_capture := true
## 마우스 감도 배율. - 와 = 키로 조절하고 설정 파일에 저장한다.
var sensitivity_scale := 1.0
var weapon: WeaponController
## 주무기 번호(game/weapons/armory.gd). 무기 칸 0은 이 총, 1은 권총이다.
var primary := Armory.DEFAULT_PRIMARY
## 남은 수류탄. 클라이언트에서는 서버가 알려 주는 값으로 맞춘다.
var grenades := 2:
	set(value):
		grenades = value
		if hud != null:
			hud.set_grenades(grenades, flashes)
## 남은 섬광탄.
var flashes := 1:
	set(value):
		flashes = value
		if hud != null:
			hud.set_grenades(grenades, flashes)
## 다음 근접 공격까지 남은 시간(초).
var melee_cooldown := 0.0
var view_model: ViewModel
var hud: Hud
## 터치 조작. 터치 기기에서만 만들어진다.
var touch: TouchControls
## 조준 보조 대상(보이는 적의 가슴 위치). 터치 조작일 때 세션이 매 틱 채운다.
var assist_targets: Array = []

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _sprinting := false
var _slide_time := 0.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_progress := 0.0
var _prev_buttons := 0
var _suppress_fire := false
var _selected_slot := 0
var _touch_paused := false
var _assist_slow := 1.0
var _visual_offset := Vector3.ZERO
## 최근에 나를 맞힌 위치들. 각 항목은 [위치, 남은 표시 시간].
var _damage_sources: Array = []
var _step_distance := 0.0
var _shape: CapsuleShape3D
var _sounds := {}
var _button_actions := {
	"jump": InputCmd.JUMP,
	"sprint": InputCmd.SPRINT,
	"crouch": InputCmd.CROUCH,
	"fire": InputCmd.FIRE,
	"aim": InputCmd.AIM,
	"reload": InputCmd.RELOAD,
	"grenade": InputCmd.GRENADE,
	"tactical": InputCmd.TACTICAL,
	"melee": InputCmd.MELEE,
}

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera
@onready var _collision: CollisionShape3D = $Collision


func _ready() -> void:
	collision_layer = BODY_LAYER
	collision_mask = WORLD_MASK
	# 캡슐 높이를 바꾸므로 씬 간에 공유되지 않게 복제한다.
	_shape = _collision.shape.duplicate() as CapsuleShape3D
	_collision.shape = _shape
	weapon = WeaponController.new()
	add_child(weapon)
	if is_local:
		_build_view()
	else:
		_camera.current = false
	weapon.setup(self, Armory.loadout(primary))
	if is_local:
		hud.set_health(health, MAX_HEALTH)
		sensitivity_scale = Settings.sensitivity()
		if Settings.touch_enabled() and not view_from_cmd:
			set_touch(true)


## 입력을 받아도 되는 상태인지. 브라우저에서는 클릭으로 포인터를 잠근 뒤부터 조작한다.
func input_active() -> bool:
	if touch != null:
		return not _touch_paused
	return not require_mouse_capture or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## 터치 조작을 켜거나 끈다. 휴대폰에서는 시작할 때, 그 밖의 터치 기기에서는 처음 화면을 만졌을 때 켜진다.
func set_touch(enabled: bool) -> void:
	if not enabled:
		if touch != null:
			touch.queue_free()
			touch = null
			_touch_paused = false
		return
	if touch != null or not is_local:
		return
	touch = TouchControls.new()
	hud.add_child(touch)
	hud.use_touch_layout(touch)
	touch.look.connect(_on_touch_look)
	touch.pause_pressed.connect(set_paused.bind(true))


## 터치 조작에서의 일시 정지. 마우스 조작은 포인터 잠금 여부로 판단하므로 영향받지 않는다.
func set_paused(paused: bool) -> void:
	_touch_paused = paused
	if touch != null:
		touch.visible = not paused
		touch.release_all()


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func is_sprinting() -> bool:
	return _sprinting


func is_low() -> bool:
	return crouching or move_state == MoveState.SLIDING


## 달리기와 난간 넘기 중에는 조준과 발사를 막는다.
func blocks_weapon() -> bool:
	var swinging := melee_cooldown > MELEE_COOLDOWN - MELEE_BUSY
	return _sprinting or move_state == MoveState.MANTLING or not alive or swinging


## 수류탄(G), 섬광탄(F), 근접 공격(V). 예측을 다시 돌릴 때는 부르지 않는다(한 번만 일어나야 한다).
func _use_equipment(pressed: int, delta: float) -> void:
	melee_cooldown = maxf(melee_cooldown - delta, 0.0)
	if move_state == MoveState.MANTLING or not alive:
		return
	var aim := -_head.global_transform.basis.z
	if (pressed & InputCmd.GRENADE) != 0 and grenades > 0:
		grenades -= 1
		grenade_thrown.emit(eye_position(), aim, "frag")
	if (pressed & InputCmd.TACTICAL) != 0 and flashes > 0:
		flashes -= 1
		grenade_thrown.emit(eye_position(), aim, "flash")
	if (pressed & InputCmd.MELEE) != 0 and melee_cooldown <= 0.0:
		melee_cooldown = MELEE_COOLDOWN
		if view_model != null:
			view_model.play_melee()
			_play("melee")
		melee_swung.emit(eye_position(), aim)


## 반동을 시점에 적용할지. 시선을 입력에서 받는 플레이어는 적용하지 않는다.
func applies_recoil() -> bool:
	return is_local and not view_from_cmd


func eye_position() -> Vector3:
	return global_position + Vector3.UP * _head.position.y


## 시점을 돌린다(라디안). 마우스 입력과 반동이 함께 쓴다.
func add_view_rotation(yaw: float, pitch: float) -> void:
	rotate_y(yaw)
	_head.rotation.x = clampf(_head.rotation.x + pitch, -PITCH_LIMIT, PITCH_LIMIT)


## 키보드와 마우스 상태로 이번 틱의 입력을 만든다.
func gather_cmd() -> InputCmd:
	var cmd := InputCmd.new()
	cmd.yaw = rotation.y
	cmd.pitch = _head.rotation.x
	# 일시 정지 중에도 들고 있는 무기는 그대로 둔다(0으로 두면 서버가 첫 무기로 바꿔 버린다).
	cmd.weapon = _selected_slot
	if not input_active():
		return cmd
	if touch != null:
		cmd.move = touch.move
		cmd.buttons = touch.buttons()
		var steps := touch.take_weapon_steps()
		_selected_slot = (_selected_slot + steps) % weapon.loadout.size()
		cmd.weapon = _selected_slot
		return cmd
	cmd.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	for action: String in _button_actions:
		if Input.is_action_pressed(action):
			cmd.buttons |= int(_button_actions[action])
	for index in weapon.loadout.size():
		if Input.is_action_pressed("weapon_%d" % (index + 1)):
			_selected_slot = index
	cmd.weapon = _selected_slot
	# 포인터를 잠그려고 누른 클릭이 그대로 발사되지 않게 한다.
	if _suppress_fire:
		if cmd.has(InputCmd.FIRE):
			cmd.buttons &= ~InputCmd.FIRE
		else:
			_suppress_fire = false
	return cmd


## 입력 하나로 한 틱 진행한다. replay는 예측 보정으로 과거 입력을 다시 돌릴 때 켠다.
## 다시 돌릴 때는 이동만 재현하고, 이미 일어난 발사와 소리는 반복하지 않는다.
func simulate(cmd: InputCmd, delta: float, replay: bool = false) -> void:
	if view_from_cmd and not replay:
		rotation.y = cmd.yaw
		_head.rotation.x = cmd.pitch
	var pressed := cmd.buttons & ~_prev_buttons
	_prev_buttons = cmd.buttons
	if not alive:
		velocity = Vector3.ZERO
		_sprinting = false
		return
	match move_state:
		MoveState.MANTLING:
			_tick_mantle(cmd, delta)
		MoveState.SLIDING:
			_tick_slide(cmd, pressed, delta)
		_:
			_tick_normal(cmd, pressed, delta)
	_update_stance(delta)
	if replay:
		return
	_use_equipment(pressed, delta)
	weapon.tick(cmd, pressed, delta)
	_update_footsteps(delta)


## 예측 보정과 스냅샷에 쓰는 이동 상태 전체.
func capture_state() -> Array:
	return [
		global_position, velocity, move_state, crouching, _slide_time,
		_mantle_from, _mantle_to, _mantle_progress, _prev_buttons,
		_shape.height, _head.position.y, _sprinting,
	]


func restore_state(state: Array) -> void:
	global_position = state[0]
	velocity = state[1]
	move_state = state[2]
	crouching = state[3]
	_slide_time = state[4]
	_mantle_from = state[5]
	_mantle_to = state[6]
	_mantle_progress = state[7]
	_prev_buttons = state[8]
	_shape.height = state[9]
	_collision.position.y = _shape.height / 2.0
	_head.position.y = state[10]
	_sprinting = state[11]
	# is_on_floor()는 move_and_slide 뒤에만 갱신되므로 제자리 이동으로 새로 고친다.
	var kept := velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = kept
	global_position = state[0]


## 주무기를 바꾼다(권총은 늘 함께 든다). 같은 주무기면 아무것도 하지 않는다.
func set_primary(id: int) -> void:
	id = Armory.valid_primary(id)
	if id == primary:
		return
	primary = id
	_selected_slot = 0
	if weapon != null and weapon.loadout.size() > 0:
		weapon.set_loadout(Armory.loadout(primary))


## 서버가 알려 준 체력, 생존 여부, 탄약, 주무기를 반영한다.
func apply_net_status(
	new_health: float, new_alive: bool, ammo: int, server_slot: int, server_primary: int
) -> void:
	set_primary(server_primary)
	if new_alive and not alive:
		weapon.reset()
		move_state = MoveState.NORMAL
		crouching = false
	alive = new_alive
	if absf(new_health - health) > 0.01:
		if is_local and new_health < health:
			hud.flash_damage()
		health = new_health
		health_changed.emit(health)
		if is_local:
			hud.set_health(health, MAX_HEALTH)
	# 예측한 탄약이 서버와 크게 어긋났을 때만 맞춘다(발사 직후의 작은 차이는 정상).
	if server_slot == weapon.slot and absi(weapon.state.ammo - ammo) > 3:
		weapon.state.ammo = ammo
		weapon.ammo_changed.emit(ammo, weapon.data.magazine_size)


func set_sensitivity(value: float) -> void:
	sensitivity_scale = clampf(value, Settings.MIN_SENSITIVITY, Settings.MAX_SENSITIVITY)


## 예측 보정으로 몸이 순간 이동했을 때 부른다. 카메라만 원래 자리에서 새 자리로 부드럽게 따라간다.
## 판정에 쓰는 실제 위치는 바로 바뀌고 화면만 늦게 따라오므로 결과에는 영향이 없다.
func add_visual_offset(world_offset: Vector3) -> void:
	if not is_local or world_offset.length() > CORRECTION_SNAP_DISTANCE:
		_visual_offset = Vector3.ZERO
		return
	_visual_offset += world_offset


## 맞은 방향을 화면에 표시한다. from은 쏜 사람의 위치.
func show_damage_from(from: Vector3) -> void:
	if not is_local:
		return
	_damage_sources.append([from, DAMAGE_MARK_TIME])
	if _damage_sources.size() > 6:
		_damage_sources.pop_front()


func show_hit(headshot: bool, killed: bool) -> void:
	if not is_local:
		return
	hud.show_hit(headshot, killed)
	if killed:
		_play("kill")
	elif headshot:
		_play("headshot")
	else:
		_play("hit")


func _input(event: InputEvent) -> void:
	# 터치를 감지하면 그때부터 터치 조작으로 바꾼다(태블릿, 터치 노트북).
	if touch != null or not is_local or view_from_cmd or not event is InputEventScreenTouch:
		return
	if str(Settings.read(Settings.TOUCH_MODE, "auto")) != "off":
		set_touch(true)


func _on_touch_look(relative: Vector2) -> void:
	var zoom := lerpf(1.0, weapon.data.ads_fov / BASE_FOV, weapon.aim_blend)
	var sensitivity := TOUCH_LOOK_SENSITIVITY * sensitivity_scale * zoom * _assist_slow
	add_view_rotation(-relative.x * sensitivity, -relative.y * sensitivity)
	view_model.add_look_delta(relative)


func _unhandled_input(event: InputEvent) -> void:
	# 터치 기기에서는 터치가 마우스 입력으로도 들어오므로 마우스 처리를 건너뛴다.
	if not is_local or view_from_cmd or touch != null:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.is_pressed() and not captured:
		# 브라우저는 사용자 클릭이 있어야 포인터 잠금을 허용한다.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_suppress_fire = true
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("sens_down"):
		_nudge_sensitivity(1.0 / 1.1)
	elif event.is_action_pressed("sens_up"):
		_nudge_sensitivity(1.1)
	elif event is InputEventMouseButton and event.is_pressed() and captured:
		# 마우스 휠로 다음/이전 무기.
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_DOWN:
			_selected_slot = (_selected_slot + 1) % weapon.loadout.size()
		elif button == MOUSE_BUTTON_WHEEL_UP:
			_selected_slot = (_selected_slot + 1) % weapon.loadout.size()
	elif event is InputEventMouseMotion and captured:
		var motion := event as InputEventMouseMotion
		var zoom := weapon.data.ads_fov / BASE_FOV
		var ads_scale := lerpf(1.0, ADS_SENSITIVITY_SCALE * zoom / 0.6875, weapon.aim_blend)
		var sensitivity := BASE_SENSITIVITY * sensitivity_scale * ads_scale
		add_view_rotation(-motion.relative.x * sensitivity, -motion.relative.y * sensitivity)
		view_model.add_look_delta(motion.relative)


func _physics_process(delta: float) -> void:
	if auto_simulate:
		simulate(gather_cmd(), delta)


func _process(delta: float) -> void:
	if not is_local:
		return
	var aim := weapon.aim_blend
	view_model.aim_blend = aim
	view_model.sprint_target = 1.0 if _sprinting else 0.0
	view_model.move_speed = horizontal_speed()
	view_model.on_floor = is_on_floor() and move_state == MoveState.NORMAL
	view_model.visible = alive

	var target_fov := lerpf(BASE_FOV, weapon.data.ads_fov, smoothstep(0.0, 1.0, aim))
	if _sprinting or move_state == MoveState.SLIDING:
		target_fov += SPRINT_FOV_BONUS
	_camera.fov = lerpf(_camera.fov, target_fov, clampf(delta * 14.0, 0.0, 1.0))

	_visual_offset = _visual_offset.lerp(Vector3.ZERO, clampf(delta * CORRECTION_SMOOTHING, 0.0, 1.0))
	_camera.position = _head.global_transform.basis.inverse() * _visual_offset

	_assist_slow = 1.0
	if touch != null and alive and not _touch_paused:
		var assist := AimAssist.evaluate(eye_position(), rotation.y, _head.rotation.x, assist_targets)
		_assist_slow = assist[0]
		add_view_rotation(float(assist[1]) * delta, float(assist[2]) * delta)

	var marks: Array = []
	for source: Array in _damage_sources:
		source[1] = float(source[1]) - delta
		var offset: Vector3 = source[0] - global_position
		# 정면이 0, 오른쪽이 +인 화면 기준 각도.
		marks.append([atan2(offset.x, -offset.z) + rotation.y, float(source[1]) / DAMAGE_MARK_TIME])
	_damage_sources = _damage_sources.filter(func(item: Array) -> bool: return float(item[1]) > 0.0)
	hud.set_damage_marks(marks)

	var scope := smoothstep(0.8, 1.0, aim) if weapon.data.hide_when_aimed else 0.0
	hud.set_crosshair(weapon.current_spread_deg(), aim, _camera.fov, scope)
	hud.set_hint_visible(false)


func _tick_normal(cmd: InputCmd, pressed: int, delta: float) -> void:
	var on_floor := is_on_floor()
	var using_weapon := cmd.has(InputCmd.FIRE) or cmd.has(InputCmd.AIM)
	var moving_forward := cmd.move.y < -0.1
	var wants_sprint := cmd.has(InputCmd.SPRINT) and moving_forward
	_sprinting = on_floor and wants_sprint and not using_weapon

	var crouch_pressed := (pressed & InputCmd.CROUCH) != 0
	if _sprinting and crouch_pressed and MoveMath.can_start_slide(horizontal_speed()):
		_start_slide()
		return
	crouching = cmd.has(InputCmd.CROUCH) or (crouching and not _can_stand())
	if crouching:
		_sprinting = false

	if not on_floor:
		velocity.y -= _gravity * delta
		# 공중에서 점프를 누른 채 전진하면 닿는 난간을 자동으로 잡는다.
		if cmd.has(InputCmd.JUMP) and moving_forward and _try_mantle(cmd.yaw):
			return
	elif (pressed & InputCmd.JUMP) != 0:
		if _try_mantle(cmd.yaw):
			return
		if _can_stand():
			crouching = false
			velocity.y = MoveMath.JUMP_VELOCITY

	var target: Vector3 = MoveMath.wish_velocity(cmd.move, cmd.yaw, _sprinting, crouching)
	velocity = MoveMath.accelerate(velocity, target, on_floor, delta)
	move_and_slide()


func _start_slide() -> void:
	move_state = MoveState.SLIDING
	_sprinting = false
	_slide_time = 0.0
	velocity = MoveMath.slide_start_velocity(velocity)


func _tick_slide(cmd: InputCmd, pressed: int, delta: float) -> void:
	_slide_time += delta
	if not is_on_floor():
		velocity.y -= _gravity * delta
	velocity = MoveMath.slide_step(velocity, delta)
	var jumped := (pressed & InputCmd.JUMP) != 0 and is_on_floor() and _can_stand()
	if jumped:
		velocity.y = MoveMath.JUMP_VELOCITY
	move_and_slide()
	if jumped or MoveMath.slide_finished(horizontal_speed(), _slide_time):
		move_state = MoveState.NORMAL
		crouching = not jumped and (cmd.has(InputCmd.CROUCH) or not _can_stand())


func _try_mantle(yaw: float) -> bool:
	var feet := global_position
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	# 1) 무릎 높이 앞에 벽이 있는지 본다.
	var knee := feet + Vector3.UP * 0.3
	var wall := _ray(knee, knee + forward * MANTLE_REACH)
	if wall.is_empty():
		return false
	# 2) 벽 안쪽 지점 위에서 아래로 쏴서 윗면을 찾는다.
	var wall_point: Vector3 = wall["position"]
	var probe := Vector3(wall_point.x, feet.y, wall_point.z) + forward * 0.35
	var above := probe + Vector3.UP * (MoveMath.MANTLE_MAX_HEIGHT + 0.1)
	var below := probe + Vector3.UP * (MoveMath.MANTLE_MIN_HEIGHT - 0.05)
	var ledge := _ray(above, below)
	if ledge.is_empty():
		return false
	var top: Vector3 = ledge["position"]
	if not MoveMath.can_mantle(top.y - feet.y):
		return false
	# 3) 올라선 자리에 설 공간이 있는지 본다.
	var headroom := _ray(top + Vector3.UP * 0.05, top + Vector3.UP * CROUCH_HEIGHT)
	if not headroom.is_empty():
		return false
	move_state = MoveState.MANTLING
	_sprinting = false
	crouching = false
	_mantle_from = feet
	_mantle_to = top + Vector3.UP * 0.02
	_mantle_progress = 0.0
	velocity = Vector3.ZERO
	return true


func _tick_mantle(cmd: InputCmd, delta: float) -> void:
	_mantle_progress += delta / MoveMath.MANTLE_TIME
	global_position = MoveMath.mantle_position(_mantle_from, _mantle_to, _mantle_progress)
	if _mantle_progress >= 1.0:
		move_state = MoveState.NORMAL
		velocity = Vector3(-sin(cmd.yaw), 0.0, -cos(cmd.yaw)) * MoveMath.WALK_SPEED * 0.5


func _can_stand() -> bool:
	var from := global_position + Vector3.UP * (CROUCH_HEIGHT - 0.1)
	var to := global_position + Vector3.UP * (STAND_HEIGHT + 0.05)
	return _ray(from, to).is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = WORLD_MASK
	return get_world_3d().direct_space_state.intersect_ray(query)


func _update_stance(delta: float) -> void:
	var target_height := STAND_HEIGHT
	var target_eye := STAND_EYE
	if move_state == MoveState.SLIDING:
		target_height = CROUCH_HEIGHT
		target_eye = SLIDE_EYE
	elif crouching:
		target_height = CROUCH_HEIGHT
		target_eye = CROUCH_EYE
	_shape.height = move_toward(_shape.height, target_height, delta * 6.0)
	_collision.position.y = _shape.height / 2.0
	_head.position.y = move_toward(_head.position.y, target_eye, delta * 5.0)


func _update_footsteps(delta: float) -> void:
	if not is_local or move_state != MoveState.NORMAL or not is_on_floor() or crouching:
		return
	_step_distance += horizontal_speed() * delta
	if _step_distance >= FOOTSTEP_DISTANCE:
		_step_distance = 0.0
		_play("step")


func _build_view() -> void:
	_add_sound("shot", SfxSynth.gunshot(), 6, -4.0)
	_add_sound("hit", SfxSynth.tone(1800.0, 0.06, 45.0), 4, -6.0)
	_add_sound("headshot", SfxSynth.tone(2600.0, 0.08, 40.0), 4, -5.0)
	_add_sound("kill", SfxSynth.kill_confirm(), 2, -4.0)
	_add_sound("dry", SFX_DRY, 2, -8.0)
	_add_sound("reload", SFX_RELOAD, 2, -6.0)
	_add_sound("step", SFX_STEP, 3, -10.0)
	_add_sound("melee", SfxSynth.whoosh(), 2, -7.0)
	hud = Hud.new()
	add_child(hud)
	view_model = ViewModel.new()
	_camera.add_child(view_model)
	weapon.fired.connect(_on_fired)
	weapon.impact.connect(_on_impact)
	weapon.hit_confirmed.connect(show_hit)
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.reload_started.connect(_on_reload_started)
	weapon.reload_finished.connect(_on_reload_finished)
	weapon.dry_fired.connect(_play.bind("dry"))
	weapon.weapon_changed.connect(_on_weapon_changed)


func _add_sound(key: String, stream: AudioStream, polyphony: int, volume_db: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.max_polyphony = polyphony
	player.volume_db = volume_db
	add_child(player)
	_sounds[key] = player


func _play(key: String) -> void:
	var player: AudioStreamPlayer = _sounds[key]
	player.play()


func _on_fired(kick_deg: Vector2) -> void:
	view_model.kick(kick_deg)
	_play("shot")


func _on_impact(point: Vector3, normal: Vector3) -> void:
	Effects.tracer(get_parent(), view_model.muzzle_global(), point)
	var mark := Effects.impact(get_parent(), point, normal)
	# 탄착음은 맞은 자리에서 난다. 탄흔이 사라질 때 함께 정리된다.
	var sound := AudioStreamPlayer3D.new()
	sound.stream = SFX_IMPACT
	sound.unit_size = 6.0
	sound.max_distance = 60.0
	sound.pitch_scale = randf_range(0.9, 1.15)
	mark.add_child(sound)
	sound.play()


func _on_weapon_changed(data: Resource) -> void:
	hud.set_weapon(Armory.id_of(data), weapon.slot)
	hud.set_reloading(false)
	view_model.set_weapon(data)
	view_model.play_reload(WeaponController.SWITCH_TIME)
	var shot := data.get("shot_sound") as AudioStream
	if shot != null:
		(_sounds["shot"] as AudioStreamPlayer).stream = shot


func _nudge_sensitivity(factor: float) -> void:
	set_sensitivity(sensitivity_scale * factor)
	Settings.write(Settings.SENSITIVITY, sensitivity_scale)
	hud.show_notice("SENSITIVITY %.2f" % sensitivity_scale)


func _on_reload_started(duration: float) -> void:
	view_model.play_reload(duration)
	hud.set_reloading(true)
	_play("reload")


func _on_reload_finished() -> void:
	hud.set_reloading(false)
	_play("reload")
