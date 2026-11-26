extends CharacterBody3D
## 1인칭 플레이어.
## 이동 상태(일반, 슬라이딩, 난간 넘기)와 시점을 관리하고 무기, 뷰모델, HUD, 임시 사운드를 조립한다.
## 이동 수치와 계산은 MoveMath에 둔다.

enum MoveState { NORMAL, SLIDING, MANTLING }

const MoveMath := preload("res://game/movement/move_math.gd")
const WeaponController := preload("res://game/weapons/weapon_controller.gd")
const ViewModel := preload("res://game/weapons/view_model.gd")
const Hud := preload("res://game/ui/hud.gd")
const SfxSynth := preload("res://game/audio/sfx_synth.gd")
const DEFAULT_WEAPON := preload("res://game/weapons/data/rifle_vk7.tres")
const MOUSE_SENSITIVITY := 0.002
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
const IMPACT_LIFETIME := 4.0

var move_state := MoveState.NORMAL
var crouching := false
## 헤드리스 테스트에는 포인터 잠금이 없으므로 끌 수 있게 한다.
var require_mouse_capture := true
var weapon: WeaponController
var view_model: ViewModel
var hud: Hud

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _sprinting := false
var _slide_time := 0.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_progress := 0.0
var _step_distance := 0.0
var _shape: CapsuleShape3D
var _sounds := {}
var _impact_mesh := SphereMesh.new()

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera
@onready var _collision: CollisionShape3D = $Collision


func _ready() -> void:
	# 캡슐 높이를 바꾸므로 씬 간에 공유되지 않게 복제한다.
	_shape = _collision.shape.duplicate() as CapsuleShape3D
	_collision.shape = _shape
	_impact_mesh.radius = 0.035
	_impact_mesh.height = 0.07

	_add_sound("shot", SfxSynth.gunshot(), 6, -4.0)
	_add_sound("hit", SfxSynth.tone(1800.0, 0.06, 45.0), 4, -6.0)
	_add_sound("headshot", SfxSynth.tone(2600.0, 0.08, 40.0), 4, -5.0)
	_add_sound("kill", SfxSynth.kill_confirm(), 2, -4.0)
	_add_sound("dry", SfxSynth.click(0.9, 0.05), 2, -8.0)
	_add_sound("reload", SfxSynth.click(0.5, 0.12), 2, -6.0)
	_add_sound("step", SfxSynth.footstep(), 3, -12.0)

	hud = Hud.new()
	add_child(hud)
	view_model = ViewModel.new()
	_camera.add_child(view_model)
	weapon = WeaponController.new()
	_camera.add_child(weapon)
	weapon.fired.connect(_on_fired)
	weapon.impact.connect(_on_impact)
	weapon.hit_confirmed.connect(_on_hit_confirmed)
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.reload_started.connect(_on_reload_started)
	weapon.reload_finished.connect(_on_reload_finished)
	weapon.dry_fired.connect(_play.bind("dry"))
	weapon.setup(self, _camera, DEFAULT_WEAPON)
	hud.set_weapon_name(weapon.data.display_name)


## 입력을 받아도 되는 상태인지. 브라우저에서는 클릭으로 포인터를 잠근 뒤부터 조작한다.
func input_active() -> bool:
	return not require_mouse_capture or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func is_sprinting() -> bool:
	return _sprinting


## 달리기와 난간 넘기 중에는 조준과 발사를 막는다.
func blocks_weapon() -> bool:
	return _sprinting or move_state == MoveState.MANTLING


## 시점을 돌린다(라디안). 마우스 입력과 반동이 함께 쓴다.
func add_view_rotation(yaw: float, pitch: float) -> void:
	rotate_y(yaw)
	_head.rotation.x = clampf(_head.rotation.x + pitch, -PITCH_LIMIT, PITCH_LIMIT)


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.is_pressed() and not captured:
		# 브라우저는 사용자 클릭이 있어야 포인터 잠금을 허용한다.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and captured:
		var motion := event as InputEventMouseMotion
		var sensitivity := MOUSE_SENSITIVITY * lerpf(1.0, ADS_SENSITIVITY_SCALE, weapon.aim_blend)
		add_view_rotation(-motion.relative.x * sensitivity, -motion.relative.y * sensitivity)
		view_model.add_look_delta(motion.relative)


func _physics_process(delta: float) -> void:
	match move_state:
		MoveState.MANTLING:
			_tick_mantle(delta)
		MoveState.SLIDING:
			_tick_slide(delta)
		_:
			_tick_normal(delta)
	_update_stance(delta)
	_update_footsteps(delta)


func _process(delta: float) -> void:
	var aim := weapon.aim_blend
	view_model.aim_blend = aim
	view_model.sprint_target = 1.0 if _sprinting else 0.0
	view_model.move_speed = horizontal_speed()
	view_model.on_floor = is_on_floor() and move_state == MoveState.NORMAL

	var target_fov := lerpf(BASE_FOV, weapon.data.ads_fov, smoothstep(0.0, 1.0, aim))
	if _sprinting or move_state == MoveState.SLIDING:
		target_fov += SPRINT_FOV_BONUS
	_camera.fov = lerpf(_camera.fov, target_fov, clampf(delta * 14.0, 0.0, 1.0))

	hud.set_crosshair(weapon.current_spread_deg(), aim, _camera.fov)
	hud.set_hint_visible(not input_active())


func _held(action: StringName) -> bool:
	return input_active() and Input.is_action_pressed(action)


func _pressed(action: StringName) -> bool:
	return input_active() and Input.is_action_just_pressed(action)


func _tick_normal(delta: float) -> void:
	var on_floor := is_on_floor()
	var input_dir := Vector2.ZERO
	if input_active():
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var using_weapon := _held("fire") or _held("aim")
	var moving_forward := input_dir.y < -0.1
	_sprinting = on_floor and _held("sprint") and moving_forward and not using_weapon

	if _sprinting and _pressed("crouch") and MoveMath.can_start_slide(horizontal_speed()):
		_start_slide()
		return
	crouching = _held("crouch") or (crouching and not _can_stand())
	if crouching:
		_sprinting = false

	if not on_floor:
		velocity.y -= _gravity * delta
		# 공중에서 점프를 누른 채 전진하면 닿는 난간을 자동으로 잡는다.
		if _held("jump") and moving_forward and _try_mantle():
			return
	elif _pressed("jump"):
		if _try_mantle():
			return
		if _can_stand():
			crouching = false
			velocity.y = MoveMath.JUMP_VELOCITY

	var target: Vector3 = MoveMath.wish_velocity(input_dir, rotation.y, _sprinting, crouching)
	velocity = MoveMath.accelerate(velocity, target, on_floor, delta)
	move_and_slide()


func _start_slide() -> void:
	move_state = MoveState.SLIDING
	_sprinting = false
	_slide_time = 0.0
	velocity = MoveMath.slide_start_velocity(velocity)


func _tick_slide(delta: float) -> void:
	_slide_time += delta
	if not is_on_floor():
		velocity.y -= _gravity * delta
	velocity = MoveMath.slide_step(velocity, delta)
	var jumped := _pressed("jump") and is_on_floor() and _can_stand()
	if jumped:
		velocity.y = MoveMath.JUMP_VELOCITY
	move_and_slide()
	if jumped or MoveMath.slide_finished(horizontal_speed(), _slide_time):
		move_state = MoveState.NORMAL
		crouching = not jumped and (_held("crouch") or not _can_stand())


func _try_mantle() -> bool:
	var feet := global_position
	var forward := -global_transform.basis.z
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


func _tick_mantle(delta: float) -> void:
	_mantle_progress += delta / MoveMath.MANTLE_TIME
	global_position = MoveMath.mantle_position(_mantle_from, _mantle_to, _mantle_progress)
	if _mantle_progress >= 1.0:
		move_state = MoveState.NORMAL
		var forward := -global_transform.basis.z
		velocity = forward * MoveMath.WALK_SPEED * 0.5


func _can_stand() -> bool:
	var from := global_position + Vector3.UP * (CROUCH_HEIGHT - 0.1)
	var to := global_position + Vector3.UP * (STAND_HEIGHT + 0.05)
	return _ray(from, to).is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _update_stance(delta: float) -> void:
	var sliding := move_state == MoveState.SLIDING
	var target_height := STAND_HEIGHT
	var target_eye := STAND_EYE
	if sliding:
		target_height = CROUCH_HEIGHT
		target_eye = SLIDE_EYE
	elif crouching:
		target_height = CROUCH_HEIGHT
		target_eye = CROUCH_EYE
	_shape.height = move_toward(_shape.height, target_height, delta * 6.0)
	_collision.position.y = _shape.height / 2.0
	_head.position.y = move_toward(_head.position.y, target_eye, delta * 5.0)


func _update_footsteps(delta: float) -> void:
	if move_state != MoveState.NORMAL or not is_on_floor() or crouching:
		return
	_step_distance += horizontal_speed() * delta
	if _step_distance >= FOOTSTEP_DISTANCE:
		_step_distance = 0.0
		_play("step")


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


func _on_impact(point: Vector3, _normal: Vector3) -> void:
	var marker := MeshInstance3D.new()
	marker.mesh = _impact_mesh
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(marker)
	marker.global_position = point
	get_tree().create_timer(IMPACT_LIFETIME).timeout.connect(marker.queue_free)


func _on_hit_confirmed(headshot: bool, killed: bool) -> void:
	hud.show_hit(headshot, killed)
	if killed:
		_play("kill")
	elif headshot:
		_play("headshot")
	else:
		_play("hit")


func _on_reload_started(duration: float) -> void:
	view_model.play_reload(duration)
	hud.set_reloading(true)
	_play("reload")


func _on_reload_finished() -> void:
	hud.set_reloading(false)
	_play("reload")
