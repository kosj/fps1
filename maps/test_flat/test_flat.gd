extends Node3D
## 자동 테스트용 빈 평지. 엄폐물이 없어 두 스폰 지점이 서로를 항상 볼 수 있다.

## 각 항목은 [위치, 바라보는 방향(yaw, 도)].
const SPAWNS := [
	[Vector3(0.0, 0.1, 0.0), 0.0],
	[Vector3(0.0, 0.1, -20.0), 180.0],
	[Vector3(10.0, 0.1, -10.0), 90.0],
	[Vector3(-10.0, 0.1, -10.0), -90.0],
]
const EXTRA_NAV_POINTS := [Vector3(0.0, 0.0, -10.0)]


func _ready() -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(0.0, -0.5, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(200.0, 1.0, 200.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


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
