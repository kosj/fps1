extends Node3D
## 1인칭 무기 모델(임시 상자 모델)과 프로시저럴 애니메이션.
## 흔들림, 보행 흔들림, 반동, 정조준 전환, 달리기 자세, 재장전 동작을 스프링과 보간으로 만든다.
## M3에서 Varco 3D와 Blender로 만든 모델로 교체한다.

const Spring := preload("res://game/core/spring.gd")
const HIP_POSITION := Vector3(0.2, -0.19, -0.42)
const ADS_POSITION := Vector3(0.0, -0.085, -0.3)
const SPRINT_ROTATION := Vector3(-0.2, 0.55, 0.1)
const RELOAD_DROP := Vector3(0.02, -0.16, 0.04)
const RELOAD_TILT := Vector3(0.5, 0.0, -0.35)
const MUZZLE_POSITION := Vector3(0.0, 0.0, -0.72)
const FLASH_TIME := 0.045

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
var _muzzle_mesh: MeshInstance3D


func _ready() -> void:
	position = HIP_POSITION
	_build_placeholder_rifle()


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

	var base := HIP_POSITION.lerp(ADS_POSITION, smoothstep(0.0, 1.0, aim_blend))
	var spring_offset := _position_spring.update(Vector3.ZERO, delta)
	position = base + bob + RELOAD_DROP * reload_curve + spring_offset

	var sprint_pose := SPRINT_ROTATION * _sprint_blend * hip_weight
	var spring_rotation := _rotation_spring.update(Vector3.ZERO, delta)
	rotation = sprint_pose + RELOAD_TILT * reload_curve + spring_rotation

	_flash_left = maxf(_flash_left - delta, 0.0)
	var flashing := _flash_left > 0.0
	_muzzle_mesh.visible = flashing
	_muzzle_light.light_energy = 2.5 if flashing else 0.0


func _build_placeholder_rifle() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.13, 0.14, 0.16)
	metal.metallic = 0.6
	metal.roughness = 0.45
	var polymer := StandardMaterial3D.new()
	polymer.albedo_color = Color(0.22, 0.23, 0.2)
	polymer.roughness = 0.8

	_add_part(Vector3(0.0, 0.0, -0.15), Vector3(0.06, 0.09, 0.5), metal)
	_add_part(Vector3(0.0, 0.01, -0.55), Vector3(0.025, 0.025, 0.3), metal)
	_add_part(Vector3(0.0, -0.12, -0.12), Vector3(0.04, 0.16, 0.07), polymer)
	_add_part(Vector3(0.0, -0.1, 0.06), Vector3(0.04, 0.12, 0.05), polymer)
	_add_part(Vector3(0.0, -0.01, 0.22), Vector3(0.05, 0.1, 0.26), polymer)
	_add_part(Vector3(0.0, 0.06, 0.04), Vector3(0.012, 0.03, 0.012), metal)
	_add_part(Vector3(0.0, 0.06, -0.38), Vector3(0.008, 0.03, 0.008), metal)

	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.85, 0.45)
	_muzzle_mesh = _add_part(MUZZLE_POSITION, Vector3(0.07, 0.07, 0.07), flash_material)
	_muzzle_mesh.visible = false

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.position = MUZZLE_POSITION
	_muzzle_light.light_color = Color(1.0, 0.8, 0.5)
	_muzzle_light.omni_range = 6.0
	_muzzle_light.light_energy = 0.0
	add_child(_muzzle_light)


func _add_part(center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = center
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	return part
