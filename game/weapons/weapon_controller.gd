extends Node
## 무기 처리. 입력(InputCmd)을 받아 고정 틱에서 WeaponState를 갱신하고 발사를 결정한다.
## 탄이 무엇을 맞혔는지는 resolve_shot에 맡긴다. 오프라인, 클라이언트 예측, 서버가 각자 다른 판정을 쓴다.
## 화면 연출(뷰모델, HUD, 소리)은 시그널을 받는 쪽에서 처리한다.

signal fired(kick_deg: Vector2)
signal impact(point: Vector3, normal: Vector3)
signal hit_confirmed(headshot: bool, killed: bool)
signal ammo_changed(ammo: int, magazine_size: int)
signal reload_started(duration: float)
signal reload_finished
signal dry_fired
signal weapon_changed(weapon: WeaponData)

const InputCmd := preload("res://game/player/input_cmd.gd")
const WeaponData := preload("res://game/weapons/weapon_data.gd")
const WeaponState := preload("res://game/weapons/weapon_state.gd")
const Recoil := preload("res://game/weapons/recoil.gd")
const WORLD_MASK := 1
## 월드(1)와 히트박스(4). 캐릭터 몸체 캡슐(2)은 맞히지 않는다.
const HIT_MASK := 5
## 무기를 바꾼 뒤 쏠 수 있게 되기까지의 시간(초).
const SWITCH_TIME := 0.4

## 지금 들고 있는 무기의 데이터와 상태.
var data: WeaponData
var state: WeaponState
var loadout: Array = []
var slot := 0
var recoil := Recoil.new()
## 0은 지향 사격, 1은 정조준.
var aim_blend := 0.0
var shots_fired := 0
var hits_landed := 0
## 발사된 탄의 판정을 맡는 함수. (origin: Vector3, direction: Vector3)를 받는다.
var resolve_shot: Callable

var _player: CharacterBody3D
var _applied_recoil := Vector2.ZERO
var _trigger_was_down := false
var _states: Array = []
var _switch_left := 0.0


func setup(player: CharacterBody3D, weapons: Array) -> void:
	_player = player
	loadout = weapons
	resolve_shot = resolve_offline
	reset()


## 모든 무기의 탄창을 채우고 상태를 처음으로 되돌린다(리스폰). 들고 있던 슬롯은 유지한다.
func reset() -> void:
	_states.clear()
	for index in loadout.size():
		_states.append(WeaponState.new(loadout[index], index + 1))
	aim_blend = 0.0
	_trigger_was_down = false
	_switch_left = 0.0
	_select(clampi(slot, 0, loadout.size() - 1))


func is_switching() -> bool:
	return _switch_left > 0.0


func current_spread_deg() -> float:
	if data == null:
		return 0.0
	var speed_ratio := clampf(_player.horizontal_speed() / 7.5, 0.0, 1.0)
	var hip := data.hip_spread_deg + data.move_spread_deg * speed_ratio
	return lerpf(hip, data.ads_spread_deg, aim_blend)


## 한 틱 진행한다. pressed는 이번 틱에 새로 눌린 버튼 비트.
func tick(cmd: InputCmd, pressed: int, delta: float) -> void:
	var wanted := clampi(cmd.weapon, 0, loadout.size() - 1)
	if wanted != slot:
		state.cancel_reload()
		_select(wanted)
		_switch_left = SWITCH_TIME
		aim_blend = 0.0
	_switch_left = maxf(_switch_left - delta, 0.0)
	var can_use: bool = not _player.blocks_weapon() and _switch_left <= 0.0
	var wants_aim := can_use and cmd.has(InputCmd.AIM)
	var aim_target := 1.0 if wants_aim else 0.0
	aim_blend = move_toward(aim_blend, aim_target, delta / maxf(data.ads_time, 0.01))

	if state.update(delta):
		reload_finished.emit()
		ammo_changed.emit(state.ammo, data.magazine_size)
	if (pressed & InputCmd.RELOAD) != 0:
		_reload()

	var trigger := can_use and cmd.has(InputCmd.FIRE)
	var trigger_pressed := trigger and not _trigger_was_down
	_trigger_was_down = trigger
	var wants_fire := trigger if data.automatic else trigger_pressed
	if not wants_fire:
		return
	if state.can_fire():
		_fire(cmd)
	elif state.ammo == 0 and state.phase == WeaponState.Phase.READY:
		if trigger_pressed:
			dry_fired.emit()
		_reload()


## 월드에 광선을 쏴 결과를 돌려준다. 맞은 것이 없으면 빈 딕셔너리.
func world_ray(origin: Vector3, direction: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * data.max_range)
	query.exclude = [_player.get_rid()]
	query.collision_mask = mask
	return _player.get_world_3d().direct_space_state.intersect_ray(query)


## 오프라인 판정: 물리 광선으로 더미 같은 피해 대상을 직접 맞힌다.
func resolve_offline(origin: Vector3, direction: Vector3) -> void:
	var result := world_ray(origin, direction, HIT_MASK)
	if result.is_empty():
		return
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


## 클라이언트 예측용 판정: 탄착 연출만 하고 피해는 서버 통보를 기다린다.
func resolve_visual_only(origin: Vector3, direction: Vector3) -> void:
	var result := world_ray(origin, direction, WORLD_MASK)
	if not result.is_empty():
		impact.emit(result["position"], result["normal"])


func _process(delta: float) -> void:
	if state == null or not _player.applies_recoil():
		return
	var offset := recoil.update(delta, data.recoil_recovery)
	var change := offset - _applied_recoil
	_applied_recoil = offset
	_player.add_view_rotation(deg_to_rad(-change.x), deg_to_rad(change.y))


func _select(index: int) -> void:
	slot = index
	data = loadout[index]
	state = _states[index]
	weapon_changed.emit(data)
	ammo_changed.emit(state.ammo, data.magazine_size)


func _reload() -> void:
	if state.start_reload():
		reload_started.emit(data.reload_time)


func _fire(cmd: InputCmd) -> void:
	state.try_fire()
	shots_fired += 1
	var kick := state.last_kick * lerpf(1.0, data.ads_recoil_scale, aim_blend)
	recoil.add_kick(kick)

	var spread := state.roll_spread(current_spread_deg())
	var view := Basis.from_euler(Vector3(cmd.pitch, cmd.yaw, 0.0))
	var aim := (-view.z).rotated(view.y, spread.x).rotated(view.x, spread.y).normalized()
	var origin: Vector3 = _player.eye_position()
	for pellet in data.pellets:
		var direction := aim
		if data.pellets > 1:
			var offset := state.roll_spread(data.pellet_spread_deg)
			direction = aim.rotated(view.y, offset.x).rotated(view.x, offset.y).normalized()
		resolve_shot.call(origin, direction)

	fired.emit(kick)
	ammo_changed.emit(state.ammo, data.magazine_size)
