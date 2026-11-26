extends RefCounted
## 전투 봇의 판단. 주변 상황을 받아 사람과 같은 형식의 입력(InputCmd)을 만든다.
## 입력만 만들기 때문에 봇도 사람과 똑같은 이동, 무기, 판정 규칙을 따른다.
##
## 사람처럼 보이게 하는 장치:
## - 반응 시간: 적을 본 뒤 일정 시간이 지나야 쏜다.
## - 회전 속도 제한: 시선이 순간 이동하지 않는다.
## - 조준 오차: 처음에는 크고, 계속 보고 있으면 줄어든다.

const InputCmd := preload("res://game/player/input_cmd.gd")
const AIM_HEIGHT := 1.0
const WAYPOINT_RADIUS := 2.0
const CHASE_TIME := 4.0
const ERROR_REROLL_TIME := 0.35

## 난이도 조절 값. 사람이 직접 상대해 보며 조정해야 하는 잠정치다.
var reaction_time := 0.5
var turn_speed := 4.5
var aim_error_start := 0.11
var aim_error_min := 0.03
var settle_time := 1.5
var fire_cone := 0.05
## 봇이 드는 무기 슬롯.
var weapon_slot := 0

var _rng := RandomNumberGenerator.new()
var _yaw := 0.0
var _pitch := 0.0
var _seen_time := 0.0
var _error := Vector2.ZERO
var _error_left := 0.0
var _waypoint := Vector3.ZERO
var _has_waypoint := false
var _last_known := Vector3.ZERO
var _chase_left := 0.0
var _stuck_time := 0.0
var _jump_ticks := 0
var _strafe := 1.0
var _strafe_left := 0.0


func _init(p_seed: int = 1, start_yaw: float = 0.0) -> void:
	_rng.seed = p_seed
	_yaw = start_yaw


## eye와 feet는 자기 위치, speed는 현재 수평 속력, enemies는 지금 보이는 적들의 발 위치,
## nav_points는 돌아다닐 지점 목록.
func make_cmd(
	delta: float, eye: Vector3, feet: Vector3, speed: float, enemies: Array, nav_points: Array
) -> InputCmd:
	var cmd := InputCmd.new()
	if enemies.is_empty():
		_seen_time = 0.0
		_roam(cmd, delta, feet, speed, nav_points)
	else:
		_fight(cmd, delta, eye, feet, enemies)
	cmd.yaw = _yaw
	cmd.pitch = _pitch
	cmd.weapon = weapon_slot
	return cmd


func _fight(cmd: InputCmd, delta: float, eye: Vector3, feet: Vector3, enemies: Array) -> void:
	var target: Vector3 = enemies[0]
	for enemy: Vector3 in enemies:
		if feet.distance_squared_to(enemy) < feet.distance_squared_to(target):
			target = enemy
	_seen_time += delta
	_last_known = target
	_chase_left = CHASE_TIME

	# 조준 오차는 주기적으로 다시 뽑고, 오래 볼수록 작아진다.
	_error_left -= delta
	if _error_left <= 0.0:
		_error_left = ERROR_REROLL_TIME
		var settle := clampf(_seen_time / settle_time, 0.0, 1.0)
		var size := lerpf(aim_error_start, aim_error_min, settle)
		_error = Vector2(_rng.randf_range(-size, size), _rng.randf_range(-size, size) * 0.6)

	var to_target := target + Vector3.UP * AIM_HEIGHT - eye
	var wanted_yaw := atan2(-to_target.x, -to_target.z)
	var wanted_pitch := atan2(to_target.y, Vector2(to_target.x, to_target.z).length())
	_turn_toward(wanted_yaw + _error.x, wanted_pitch + _error.y, delta)

	var distance := feet.distance_to(target)
	_strafe_left -= delta
	if _strafe_left <= 0.0:
		_strafe_left = _rng.randf_range(0.8, 2.0)
		_strafe = -_strafe if _rng.randf() < 0.7 else _strafe
	cmd.move.x = _strafe
	if distance > 25.0:
		cmd.move.y = -1.0
	elif distance < 6.0:
		cmd.move.y = 1.0

	cmd.buttons = InputCmd.AIM
	var off_target := absf(angle_difference(_yaw, wanted_yaw)) + absf(_pitch - wanted_pitch)
	if _seen_time >= reaction_time and off_target <= fire_cone + _error.length():
		cmd.buttons |= InputCmd.FIRE


func _roam(cmd: InputCmd, delta: float, feet: Vector3, speed: float, nav_points: Array) -> void:
	var destination := _waypoint
	_chase_left -= delta
	if _chase_left > 0.0:
		destination = _last_known
		if _flat_distance(feet, destination) < WAYPOINT_RADIUS:
			_chase_left = 0.0
	else:
		var arrived := _has_waypoint and _flat_distance(feet, _waypoint) < WAYPOINT_RADIUS
		if not _has_waypoint or arrived:
			_pick_waypoint(feet, nav_points)
		destination = _waypoint
	if not _has_waypoint and _chase_left <= 0.0:
		return

	var to_destination := destination - feet
	_turn_toward(atan2(-to_destination.x, -to_destination.z), 0.0, delta)
	cmd.move.y = -1.0
	if _flat_distance(feet, destination) > 12.0:
		cmd.buttons |= InputCmd.SPRINT

	# 막혔으면 먼저 뛰어넘기를 시도하고, 그래도 안 되면 다른 곳으로 간다.
	_stuck_time = _stuck_time + delta if speed < 0.5 else 0.0
	if _jump_ticks > 0:
		_jump_ticks -= 1
		cmd.buttons |= InputCmd.JUMP
	elif _stuck_time > 0.5 and _stuck_time < 0.55:
		_jump_ticks = 3
	if _stuck_time > 1.6:
		_stuck_time = 0.0
		_chase_left = 0.0
		_pick_waypoint(feet, nav_points)


func _pick_waypoint(feet: Vector3, nav_points: Array) -> void:
	_has_waypoint = not nav_points.is_empty()
	if not _has_waypoint:
		return
	# 지금 있는 곳과 다른 지점을 고른다.
	for attempt in 4:
		_waypoint = nav_points[_rng.randi_range(0, nav_points.size() - 1)]
		if _flat_distance(feet, _waypoint) > WAYPOINT_RADIUS * 2.0:
			return


func _turn_toward(wanted_yaw: float, wanted_pitch: float, delta: float) -> void:
	var step := turn_speed * delta
	_yaw = wrapf(_yaw + clampf(angle_difference(_yaw, wanted_yaw), -step, step), -PI, PI)
	_pitch += clampf(wanted_pitch - _pitch, -step, step)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
