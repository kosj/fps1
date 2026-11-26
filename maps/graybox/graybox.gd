extends Node3D
## 그레이박스 사격장. 엄폐물, 난간 넘기 연습용 상자, 거리별 사격 더미를 코드로 배치한다.

const TargetDummy := preload("res://game/combat/target_dummy.gd")

## 각 항목은 [중심 위치, 크기].
const COVERS := [
	[Vector3(4.0, 0.75, -6.0), Vector3(3.0, 1.5, 1.0)],
	[Vector3(-5.0, 0.75, -9.0), Vector3(1.0, 1.5, 4.0)],
	[Vector3(0.0, 0.5, -14.0), Vector3(6.0, 1.0, 1.0)],
	[Vector3(8.0, 1.5, -15.0), Vector3(2.0, 3.0, 2.0)],
	[Vector3(-9.0, 1.5, -3.0), Vector3(2.0, 3.0, 6.0)],
]

## 난간 넘기 연습용 계단식 상자: 높이 0.5m, 1.0m, 1.4m(넘을 수 있음), 2.2m(넘을 수 없음).
const LEDGES := [
	[Vector3(-4.0, 0.25, 6.0), Vector3(3.0, 0.5, 3.0)],
	[Vector3(0.0, 0.5, 6.0), Vector3(3.0, 1.0, 3.0)],
	[Vector3(4.0, 0.7, 6.0), Vector3(3.0, 1.4, 3.0)],
	[Vector3(8.0, 1.1, 6.0), Vector3(3.0, 2.2, 3.0)],
]

## 더미 위치. 근거리, 피해 감소가 시작되는 25m, 최소 피해가 적용되는 60m.
const DUMMIES := [
	Vector3(-2.0, 0.0, -10.0),
	Vector3(2.0, 0.0, -10.0),
	Vector3(0.0, 0.0, -25.0),
	Vector3(-4.0, 0.0, -40.0),
	Vector3(4.0, 0.0, -60.0),
]

## 스폰 지점. 각 항목은 [위치, 바라보는 방향(yaw, 도)].
const SPAWNS := [
	[Vector3(0.0, 0.1, 0.0), 0.0],
	[Vector3(0.0, 0.1, -32.0), 180.0],
	[Vector3(-12.0, 0.1, -16.0), -90.0],
	[Vector3(12.0, 0.1, -16.0), 90.0],
	[Vector3(-10.0, 0.1, 2.0), -30.0],
	[Vector3(10.0, 0.1, -30.0), 150.0],
]

const EXTRA_NAV_POINTS := [
	Vector3(0.0, 0.0, -8.0),
	Vector3(6.0, 0.0, -10.0),
	Vector3(-7.0, 0.0, -14.0),
	Vector3(3.0, 0.0, -20.0),
	Vector3(-3.0, 0.0, -26.0),
	Vector3(12.0, 0.0, -6.0),
	Vector3(-12.0, 0.0, -28.0),
]

@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	_sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	var cover_material := StandardMaterial3D.new()
	cover_material.albedo_color = Color(0.55, 0.57, 0.6)
	for cover: Array in COVERS:
		_add_box(cover[0], cover[1], cover_material)
	var ledge_material := StandardMaterial3D.new()
	ledge_material.albedo_color = Color(0.35, 0.5, 0.65)
	for ledge: Array in LEDGES:
		_add_box(ledge[0], ledge[1], ledge_material)


## 세션이 플레이어를 놓을 자리. 인원이 스폰 수보다 많으면 처음부터 다시 쓴다.
func spawn_count() -> int:
	return SPAWNS.size()


## 봇이 돌아다닐 지점.
func nav_points() -> Array:
	var points: Array = []
	for spawn: Array in SPAWNS:
		points.append(spawn[0])
	points.append_array(EXTRA_NAV_POINTS)
	return points


func spawn_point(index: int) -> Transform3D:
	var spawn: Array = SPAWNS[index % SPAWNS.size()]
	var facing := Basis.from_euler(Vector3(0.0, deg_to_rad(spawn[1]), 0.0))
	return Transform3D(facing, spawn[0])


## 혼자 연습할 때만 사격 더미를 세운다. 네트워크 대전에서는 상태를 동기화하지 않으므로 두지 않는다.
func spawn_offline_targets() -> void:
	for spot: Vector3 in DUMMIES:
		var dummy := TargetDummy.new()
		dummy.position = spot
		add_child(dummy)


func _add_box(center: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)
