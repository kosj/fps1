extends Node3D
## 1인칭 무기 모델과 프로시저럴 애니메이션.
## 흔들림, 보행 흔들림, 반동, 정조준 전환, 달리기 자세, 재장전 동작을 스프링과 보간으로 만든다.
## 모델은 tools/asset_pipeline/build_weapons.py로 만든 GLB이고, 없으면 임시 상자 모델을 쓴다.

const Spring := preload("res://game/core/spring.gd")
const HIP_POSITION := Vector3(0.17, -0.17, -0.3)
const ADS_POSITION := Vector3(0.0, -0.085, -0.2)
const SPRINT_ROTATION := Vector3(-0.2, 0.55, 0.1)
const RELOAD_DROP := Vector3(0.02, -0.16, 0.04)
const RELOAD_TILT := Vector3(0.5, 0.0, -0.35)
const MUZZLE_POSITION := Vector3(0.0, 0.0, -0.72)
const FLASH_TIME := 0.045
const MAG_DROP := Vector3(0.0, -0.22, 0.03)
const ACTION_TRAVEL := 0.035
const ARMS := preload("res://game/weapons/models/arms.glb")
const Effects := preload("res://game/fx/effects.gd")
const EJECT_TIME := 0.09
const EJECT_PORT := Vector3(0.03, 0.02, -0.08)
## 팔꿈치 위치(총 원점 기준). 손목에서 이쪽으로 팔이 뻗는다.
const ELBOW_RIGHT := Vector3(0.14, -0.3, 0.5)
## 손목 축을 기준으로 손을 돌리는 각도(도). 오른손은 손잡이를 쥐게 세우고, 왼손은 손바닥이 위로.
const ARM_TINT := Color(0.5, 0.52, 0.44)
const ROLL_RIGHT := 90.0

var aim_blend := 0.0
var sprint_target := 0.0
var move_speed := 0.0
var on_floor := true

var _position_spring := Spring.new(170.0, 17.0)
var _rotation_spring := Spring.new(150.0, 15.0)
var _sprint_blend := 0.0
var _bob_time := 0.0
var _reload_left := 0.0
var _reload_total := 1.0
var _flash_left := 0.0
var _muzzle_light: OmniLight3D
var _muzzle_mesh: Node3D
var _shells: CPUParticles3D
var _eject_left := 0.0
var _model: Node3D
var _placeholder: Node3D
var _arm_right: Node3D
var _arm_left: Node3D
var _left_rest_y := 0.0
var _mag: Node3D
var _action: Node3D
var _mag_rest := Vector3.ZERO
var _action_rest := Vector3.ZERO
var _action_kick := 0.0
var _ads_position := ADS_POSITION
var _hip_position := HIP_POSITION
var _hide_when_aimed := false


func _ready() -> void:
	position = HIP_POSITION
	_build_muzzle_flash()
	if _model == null:
		_build_placeholder_rifle()


## 무기 데이터에 맞는 모델로 바꾼다. 모델이 없는 데이터면 임시 상자 모델을 유지한다.
func set_weapon(data: Resource) -> void:
	var scene := data.get("model") as PackedScene
	if scene == null:
		return
	if _model != null:
		_model.queue_free()
	if _placeholder != null:
		_placeholder.queue_free()
		_placeholder = null
	_model = scene.instantiate() as Node3D
	add_child(_model)
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mag = _model.find_child("mag", true, false) as Node3D
	_action = _model.find_child("action", true, false) as Node3D
	_mag_rest = _mag.position if _mag != null else Vector3.ZERO
	_action_rest = _action.position if _action != null else Vector3.ZERO
	var muzzle := _model.find_child("muzzle", true, false) as Node3D
	var muzzle_at := muzzle.position if muzzle != null else MUZZLE_POSITION
	if _muzzle_mesh != null:
		_muzzle_mesh.position = muzzle_at
		_muzzle_light.position = muzzle_at
	_place_arms(data)
	_hip_position = HIP_POSITION + (data.get("hip_offset") as Vector3)
	_ads_position = Vector3(0.0, -float(data.get("sight_height")), -float(data.get("aim_distance")))
	_hide_when_aimed = bool(data.get("hide_when_aimed"))


## 마우스 이동량(픽셀)을 받아 총이 시선을 살짝 늦게 따라오게 한다.
func add_look_delta(relative: Vector2) -> void:
	var push := Vector3(-relative.x, relative.y, 0.0) * 0.0025
	_position_spring.add_impulse(push.limit_length(0.6))


func kick(kick_deg: Vector2) -> void:
	var factor := lerpf(1.0, 0.45, aim_blend)
	_position_spring.add_impulse(Vector3(0.0, 0.1, 0.6) * factor)
	var pitch := deg_to_rad(kick_deg.y) * 20.0
	var yaw := deg_to_rad(-kick_deg.x) * 20.0
	_rotation_spring.add_impulse(Vector3(pitch, yaw, 0.0) * factor)
	_flash_left = FLASH_TIME
	_action_kick = 1.0
	_eject_left = EJECT_TIME
	Effects.show_flash(_muzzle_mesh)


func play_reload(duration: float) -> void:
	_reload_total = maxf(duration, 0.01)
	_reload_left = _reload_total


func _process(delta: float) -> void:
	_sprint_blend = move_toward(_sprint_blend, sprint_target, delta * 6.0)
	var hip_weight := 1.0 - aim_blend

	if on_floor and move_speed > 0.5:
		_bob_time += delta * move_speed * 1.6
	var bob_scale := lerpf(0.15, 1.0, hip_weight) * clampf(move_speed / 5.0, 0.0, 1.5)
	var bob := Vector3(cos(_bob_time) * 0.006, -absf(sin(_bob_time)) * 0.008, 0.0) * bob_scale

	_reload_left = maxf(_reload_left - delta, 0.0)
	var reload_curve := sin(PI * (1.0 - _reload_left / _reload_total))
	if _reload_left <= 0.0:
		reload_curve = 0.0

	var base := _hip_position.lerp(_ads_position, smoothstep(0.0, 1.0, aim_blend))
	var spring_offset := _position_spring.update(Vector3.ZERO, delta)
	position = base + bob + RELOAD_DROP * reload_curve + spring_offset

	var sprint_pose := SPRINT_ROTATION * _sprint_blend * hip_weight
	var spring_rotation := _rotation_spring.update(Vector3.ZERO, delta)
	rotation = sprint_pose + RELOAD_TILT * reload_curve + spring_rotation

	# 부품 움직임: 재장전 중간에 탄창이 빠졌다 들어오고, 쏠 때 노리쇠(펌프)가 뒤로 밀린다.
	_action_kick = move_toward(_action_kick, 0.0, delta * 9.0)
	if _mag != null:
		_mag.position = _mag_rest + MAG_DROP * reload_curve
	if _action != null:
		_action.position = _action_rest + Vector3(0.0, 0.0, ACTION_TRAVEL * _action_kick)
	var shown := not (_hide_when_aimed and aim_blend > 0.85)
	if _model != null:
		_model.visible = shown
	if _arm_right != null:
		_arm_right.visible = shown
		# 왼손은 재장전 때 탄창을 따라 내려갔다 올라온다.
		_arm_left.visible = shown
		_arm_left.position.y = _left_rest_y + MAG_DROP.y * 0.8 * reload_curve

	_flash_left = maxf(_flash_left - delta, 0.0)
	var flashing := _flash_left > 0.0
	_muzzle_mesh.visible = flashing
	_eject_left = maxf(_eject_left - delta, 0.0)
	_shells.emitting = _eject_left > 0.0
	_muzzle_light.light_energy = 2.5 if flashing else 0.0


func _build_placeholder_rifle() -> void:
	_placeholder = Node3D.new()
	add_child(_placeholder)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.13, 0.14, 0.16)
	metal.metallic = 0.6
	metal.roughness = 0.45
	var polymer := StandardMaterial3D.new()
	polymer.albedo_color = Color(0.22, 0.23, 0.2)
	polymer.roughness = 0.8

	_add_part(Vector3(0.0, 0.0, -0.15), Vector3(0.06, 0.09, 0.5), metal, _placeholder)
	_add_part(Vector3(0.0, 0.01, -0.55), Vector3(0.025, 0.025, 0.3), metal, _placeholder)
	_add_part(Vector3(0.0, -0.12, -0.12), Vector3(0.04, 0.16, 0.07), polymer, _placeholder)
	_add_part(Vector3(0.0, -0.1, 0.06), Vector3(0.04, 0.12, 0.05), polymer, _placeholder)
	_add_part(Vector3(0.0, -0.01, 0.22), Vector3(0.05, 0.1, 0.26), polymer, _placeholder)
	_add_part(Vector3(0.0, 0.06, 0.04), Vector3(0.012, 0.03, 0.012), metal, _placeholder)
	_add_part(Vector3(0.0, 0.06, -0.38), Vector3(0.008, 0.03, 0.008), metal, _placeholder)


## 총구의 월드 위치. 예광탄의 출발점으로 쓴다.
func muzzle_global() -> Vector3:
	return _muzzle_mesh.global_position if _muzzle_mesh != null else global_position


func _place_arms(data: Resource) -> void:
	if _arm_right == null:
		var arms := ARMS.instantiate() as Node3D
		add_child(arms)
		_arm_right = arms.find_child("arm_r", true, false) as Node3D
		_arm_left = arms.find_child("arm_l", true, false) as Node3D
		for found in arms.find_children("*", "MeshInstance3D", true, false):
			var mesh := found as MeshInstance3D
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# 밝은 회색 군복 텍스처를 어두운 국방색으로 눌러 총과 어울리게 한다.
			var material := mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			material.albedo_color = ARM_TINT
			mesh.set_surface_override_material(0, material)
	_aim_arm(_arm_right, ELBOW_RIGHT, data.get("grip_point"), ROLL_RIGHT)
	_aim_arm(_arm_left, data.get("support_elbow"), data.get("support_point"), data.get("support_roll"))
	_left_rest_y = _arm_left.position.y if _arm_left != null else 0.0


## 팔 모델(원점이 손목, -Z가 손끝 방향)을 팔꿈치에서 손 위치로 뻗게 놓는다.
func _aim_arm(arm: Node3D, elbow: Vector3, hand: Vector3, roll_deg: float) -> void:
	if arm == null:
		return
	var forward := (hand - elbow).normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var up := side.cross(forward)
	var basis := Basis(side, up, -forward).rotated(forward, deg_to_rad(roll_deg))
	arm.transform = Transform3D(basis, hand)


func _build_muzzle_flash() -> void:
	_muzzle_mesh = Effects.muzzle_flash()
	_muzzle_mesh.position = MUZZLE_POSITION
	add_child(_muzzle_mesh)
	_shells = Effects.shell_ejector()
	_shells.position = EJECT_PORT
	add_child(_shells)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.position = MUZZLE_POSITION
	_muzzle_light.light_color = Color(1.0, 0.8, 0.5)
	_muzzle_light.omni_range = 6.0
	_muzzle_light.light_energy = 0.0
	add_child(_muzzle_light)


func _add_part(
	center: Vector3, size: Vector3, material: Material, parent: Node = self
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = center
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part
