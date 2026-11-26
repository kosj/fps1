extends Node
## 무기 입력과 발사 처리. 고정 틱에서 WeaponState를 갱신하고 히트스캔 판정을 한다.
## 화면 연출(뷰모델, HUD, 소리)은 시그널을 받는 쪽에서 처리한다.

signal fired(kick_deg: Vector2)
signal impact(point: Vector3, normal: Vector3)
signal hit_confirmed(headshot: bool, killed: bool)
signal ammo_changed(ammo: int, magazine_size: int)
signal reload_started(duration: float)
signal reload_finished
signal dry_fired

const WeaponData := preload("res://game/weapons/weapon_data.gd")
const WeaponState := preload("res://game/weapons/weapon_state.gd")
const Recoil := preload("res://game/weapons/recoil.gd")

var data: WeaponData
var state: WeaponState
var recoil := Recoil.new()
## 0은 지향 사격, 1은 정조준.
var aim_blend := 0.0
var shots_fired := 0
var hits_landed := 0

var _player: CharacterBody3D
var _camera: Camera3D
var _applied_recoil := Vector2.ZERO
var _trigger_was_down := false


func setup(player: CharacterBody3D, camera: Camera3D, weapon: WeaponData) -> void:
	_player = player
	_camera = camera
	data = weapon
	state = WeaponState.new(weapon)
	ammo_changed.emit(state.ammo, data.magazine_size)


func current_spread_deg() -> float:
	if data == null:
		return 0.0
	var speed_ratio := clampf(_player.horizontal_speed() / 7.5, 0.0, 1.0)
	var hip := data.hip_spread_deg + data.move_spread_deg * speed_ratio
	return lerpf(hip, data.ads_spread_deg, aim_blend)


func _physics_process(delta: float) -> void:
	if state == null:
		return
	var active: bool = _player.input_active()
	var can_use_weapon: bool = active and not _player.blocks_weapon()
	var wants_aim := can_use_weapon and Input.is_action_pressed("aim")
	var aim_target := 1.0 if wants_aim else 0.0
	aim_blend = move_toward(aim_blend, aim_target, delta / maxf(data.ads_time, 0.01))

	if state.update(delta):
		reload_finished.emit()
		ammo_changed.emit(state.ammo, data.magazine_size)

	if active and Input.is_action_just_pressed("reload"):
		_reload()

	var trigger := can_use_weapon and Input.is_action_pressed("fire")
	var pressed := trigger and not _trigger_was_down
	_trigger_was_down = trigger
	var wants_fire := trigger if data.automatic else pressed
	if not wants_fire:
		return
	if state.can_fire():
		_fire()
	elif state.ammo == 0 and state.phase == WeaponState.Phase.READY:
		if pressed:
			dry_fired.emit()
		_reload()


func _process(delta: float) -> void:
	if state == null:
		return
	var offset := recoil.update(delta, data.recoil_recovery)
	var change := offset - _applied_recoil
	_applied_recoil = offset
	_player.add_view_rotation(deg_to_rad(-change.x), deg_to_rad(change.y))


func _reload() -> void:
	if state.start_reload():
		reload_started.emit(data.reload_time)


func _fire() -> void:
	state.try_fire()
	shots_fired += 1
	var kick := state.last_kick * lerpf(1.0, data.ads_recoil_scale, aim_blend)
	recoil.add_kick(kick)

	var spread := state.roll_spread(current_spread_deg())
	var view := _camera.global_transform.basis
	var direction := (-view.z).rotated(view.y, spread.x).rotated(view.x, spread.y).normalized()
	var origin := _camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * data.max_range)
	query.exclude = [_player.get_rid()]
	var result := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		_resolve_hit(origin, result)

	fired.emit(kick)
	ammo_changed.emit(state.ammo, data.magazine_size)


func _resolve_hit(origin: Vector3, result: Dictionary) -> void:
	var point: Vector3 = result["position"]
	var normal: Vector3 = result["normal"]
	var collider: Object = result["collider"]
	impact.emit(point, normal)
	if collider == null or not collider.has_method("apply_damage"):
		return
	var headshot: bool = collider.get("is_head") == true
	var amount: float = WeaponState.damage_at(data, origin.distance_to(point), headshot)
	var killed: bool = collider.call("apply_damage", amount)
	hits_landed += 1
	hit_confirmed.emit(headshot, killed)
