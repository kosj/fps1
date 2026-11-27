extends RefCounted
## 병사 모델의 자세를 부품 회전으로 만든다: 걷기/달리기, 앉기, 총을 든 팔.
## 스키닝 애니메이션 없이 관절 노드만 돌리므로 모델 파일이 작고 웹에서도 가볍다.

const HitMath := preload("res://game/combat/hit_math.gd")
const STRIDE := 1.9
const HIPS_STAND := 0.95
const CROUCH_DROP := 0.42
## 총을 견착했을 때의 팔 각도(도). [위팔 x, 위팔 y, 위팔 z, 아래팔 x, 아래팔 y].
const ARM_RIGHT := [38.0, 0.0, -6.0, 88.0, 38.0]
const ARM_LEFT := [72.0, 0.0, 10.0, 34.0, -42.0]
const WEAPON_OFFSET := Vector3(0.12, 0.36, -0.2)

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_l_lower: Node3D
var _arm_r: Node3D
var _arm_r_lower: Node3D
var _leg_l: Node3D
var _leg_l_lower: Node3D
var _leg_r: Node3D
var _leg_r_lower: Node3D
var _phase := 0.0
var _crouch := 0.0
var _moving := 0.0


func bind(model: Node3D, weapon: Node3D) -> void:
	_hips = _find(model, "hips")
	_torso = _find(model, "torso")
	_head = _find(model, "head")
	_arm_l = _find(model, "arm_l_upper")
	_arm_l_lower = _find(model, "arm_l_lower")
	_arm_r = _find(model, "arm_r_upper")
	_arm_r_lower = _find(model, "arm_r_lower")
	_leg_l = _find(model, "leg_l_upper")
	_leg_l_lower = _find(model, "leg_l_lower")
	_leg_r = _find(model, "leg_r_upper")
	_leg_r_lower = _find(model, "leg_r_lower")
	if weapon != null and _torso != null:
		_torso.add_child(weapon)
		weapon.position = WEAPON_OFFSET
	_set_arm(_arm_r, _arm_r_lower, ARM_RIGHT)
	_set_arm(_arm_l, _arm_l_lower, ARM_LEFT)


## speed는 수평 속도(m/s), low는 앉기/슬라이드 자세 여부.
func update(delta: float, speed: float, low: bool) -> void:
	if _hips == null:
		return
	var blend := 1.0 if delta <= 0.0 else clampf(delta * 10.0, 0.0, 1.0)
	_crouch = lerpf(_crouch, 1.0 if low else 0.0, blend)
	_moving = lerpf(_moving, clampf(speed / 3.0, 0.0, 1.0), blend)
	_phase = fposmod(_phase + speed * delta / STRIDE * TAU, TAU)

	var swing := sin(_phase) * 0.62 * _moving
	var bob := absf(cos(_phase)) * 0.035 * _moving
	_hips.position.y = HIPS_STAND - CROUCH_DROP * _crouch + bob
	_torso.rotation.x = -0.12 * _moving - 0.3 * _crouch
	_head.rotation.x = 0.1 * _moving + 0.25 * _crouch
	_pose_leg(_leg_l, _leg_l_lower, swing)
	_pose_leg(_leg_r, _leg_r_lower, -swing)


## 눈높이(히트 판정과 같은 키)에 맞는지 확인하는 데 쓴다.
func top_height() -> float:
	return lerpf(HitMath.STAND_HEIGHT, HitMath.LOW_HEIGHT, _crouch)


func _pose_leg(upper: Node3D, lower: Node3D, swing: float) -> void:
	# 앉으면 허벅지를 앞으로 들고 무릎을 접는다. 걸을 때는 뒤로 가는 다리의 무릎이 더 접힌다.
	var lift := 1.25 * _crouch
	upper.rotation.x = swing + lift
	lower.rotation.x = -(maxf(-swing, 0.0) * 1.1 + 0.15 * _moving + 2.1 * _crouch)


func _set_arm(upper: Node3D, lower: Node3D, degrees: Array) -> void:
	if upper == null or lower == null:
		return
	upper.rotation_degrees = Vector3(degrees[0], degrees[1], degrees[2])
	lower.rotation_degrees = Vector3(degrees[3], degrees[4], 0.0)


func _find(model: Node3D, part: String) -> Node3D:
	return model.find_child(part, true, false) as Node3D
