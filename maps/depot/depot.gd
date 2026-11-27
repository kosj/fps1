extends Node3D
## 첫 실전 맵 "Depot". 벽으로 나뉜 세 통로(왼쪽, 가운데, 오른쪽)가 양 팀 진영을 잇는다.
##
## - 크기 60 x 80 m. 0팀은 +z 끝, 1팀은 -z 끝에서 시작한다.
## - 통로 사이 벽은 가운데(|z| < 6)와 진영 앞(|z| > 22)에서 끊겨 옆 통로로 넘어갈 수 있다.
## - 거점 A, B, C는 각 통로의 한가운데에 있다.
## - 한쪽 절반만 정의하고 180도 돌려 복사하므로 두 팀의 조건이 같다.
## - 봇이 벽을 돌아갈 수 있도록 이동 그래프(지점과 연결)를 함께 제공한다.
##   tests/smoke/map_check가 모든 연결이 실제로 막혀 있지 않은지 검사한다.

const WALL_HEIGHT := 4.0
const Surfaces := preload("res://game/world/surfaces.gd")
## 구조물 종류. game/world/surfaces.gd의 재질 이름이다.
const WALL_COLOR := "wall"
const TALL_COLOR := "container"
const LOW_COLOR := "crate"

## 절반(z > 0)의 구조물. 각 항목은 [중심, 크기, 재질 종류].
const HALF_BOXES := [
	# 통로를 나누는 벽
	[Vector3(-10.0, 1.75, 14.0), Vector3(1.0, 3.5, 16.0), WALL_COLOR],
	[Vector3(10.0, 1.75, 14.0), Vector3(1.0, 3.5, 16.0), WALL_COLOR],
	# 진영 앞: 가운데 통로를 가리는 벽과 양옆 엄폐물
	[Vector3(0.0, 1.5, 30.0), Vector3(5.0, 3.0, 1.0), WALL_COLOR],
	[Vector3(-13.0, 1.25, 29.0), Vector3(4.0, 2.5, 1.0), TALL_COLOR],
	[Vector3(13.0, 1.25, 29.0), Vector3(4.0, 2.5, 1.0), TALL_COLOR],
	# 왼쪽 통로
	[Vector3(-25.0, 0.6, 18.0), Vector3(2.0, 1.2, 2.0), LOW_COLOR],
	[Vector3(-15.0, 1.25, 10.0), Vector3(2.0, 2.5, 3.0), TALL_COLOR],
	[Vector3(-24.0, 1.25, 5.0), Vector3(3.0, 2.5, 1.5), TALL_COLOR],
	[Vector3(-16.0, 0.6, 22.0), Vector3(3.0, 1.2, 1.2), LOW_COLOR],
	# 가운데 통로
	[Vector3(4.5, 1.25, 15.0), Vector3(2.0, 2.5, 4.0), TALL_COLOR],
	[Vector3(-5.0, 0.6, 9.0), Vector3(3.0, 1.2, 1.5), LOW_COLOR],
	[Vector3(5.0, 0.6, 3.5), Vector3(3.0, 1.2, 1.5), LOW_COLOR],
	[Vector3(-10.0, 1.75, 3.5), Vector3(1.0, 3.5, 1.0), WALL_COLOR],
	# 오른쪽 통로
	[Vector3(25.0, 0.6, 16.0), Vector3(2.0, 1.2, 2.0), LOW_COLOR],
	[Vector3(15.0, 1.25, 12.0), Vector3(2.0, 2.5, 3.0), TALL_COLOR],
	[Vector3(24.0, 1.25, 6.0), Vector3(3.0, 2.5, 1.5), TALL_COLOR],
	[Vector3(16.5, 0.6, 21.0), Vector3(3.0, 1.2, 1.2), LOW_COLOR],
]

## 0팀(z > 0) 스폰 위치. 1팀은 180도 돌린 자리를 쓴다.
const HALF_SPAWNS := [
	Vector3(0.0, 0.1, 34.0),
	Vector3(-6.0, 0.1, 35.5),
	Vector3(6.0, 0.1, 35.5),
	Vector3(-14.0, 0.1, 33.0),
	Vector3(14.0, 0.1, 33.0),
	Vector3(-22.0, 0.1, 33.0),
	Vector3(22.0, 0.1, 33.0),
]

## 이동 그래프의 절반(z > 0) 지점.
const HALF_NODES := [
	Vector3(0.0, 0.0, 34.0),
	Vector3(-20.0, 0.0, 30.0),
	Vector3(20.0, 0.0, 30.0),
	Vector3(-20.0, 0.0, 26.0),
	Vector3(0.0, 0.0, 26.0),
	Vector3(20.0, 0.0, 26.0),
	Vector3(-20.0, 0.0, 14.0),
	Vector3(0.0, 0.0, 14.0),
	Vector3(20.0, 0.0, 14.0),
	Vector3(-6.0, 0.0, 30.0),
	Vector3(6.0, 0.0, 30.0),
]
## 절반 지점끼리의 연결(HALF_NODES 번호).
const HALF_EDGES := [
	[0, 1], [0, 2], [0, 9], [0, 10], [9, 4], [10, 4], [1, 3], [2, 5],
	[3, 4], [4, 5], [3, 6], [4, 7], [5, 8],
]
## 가운데 선(z = 0) 위의 지점. 거점 A, B, C의 중심이기도 하다.
const CENTER_NODES := [
	Vector3(-20.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
	Vector3(20.0, 0.0, 0.0),
]
## 절반 지점과 가운데 지점의 연결. [HALF_NODES 번호, CENTER_NODES 번호].
const HALF_TO_CENTER := [[6, 0], [7, 1], [8, 2]]

@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	_sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	($Floor/Mesh as MeshInstance3D).material_override = Surfaces.material("floor")
	_add_box(Vector3(-30.5, WALL_HEIGHT / 2.0, 0.0), Vector3(1.0, WALL_HEIGHT, 82.0), WALL_COLOR)
	_add_box(Vector3(30.5, WALL_HEIGHT / 2.0, 0.0), Vector3(1.0, WALL_HEIGHT, 82.0), WALL_COLOR)
	_add_box(Vector3(0.0, WALL_HEIGHT / 2.0, -40.5), Vector3(62.0, WALL_HEIGHT, 1.0), WALL_COLOR)
	_add_box(Vector3(0.0, WALL_HEIGHT / 2.0, 40.5), Vector3(62.0, WALL_HEIGHT, 1.0), WALL_COLOR)
	for box: Array in HALF_BOXES:
		_add_box(box[0], box[1], box[2])
		_add_box(_mirror(box[0]), box[1], box[2])


func spawn_count() -> int:
	return HALF_SPAWNS.size() * 2


## 앞쪽 절반 번호는 0팀, 뒤쪽 절반 번호는 1팀 스폰이다.
func spawn_point(index: int) -> Transform3D:
	var wrapped := index % spawn_count()
	if wrapped < HALF_SPAWNS.size():
		return Transform3D(Basis.IDENTITY, HALF_SPAWNS[wrapped])
	var facing := Basis.from_euler(Vector3(0.0, PI, 0.0))
	return Transform3D(facing, _mirror(HALF_SPAWNS[wrapped - HALF_SPAWNS.size()]))


## 이 팀이 쓸 수 있는 스폰 번호.
func spawn_indices_for(team: int) -> Array:
	var indices: Array = []
	for index in HALF_SPAWNS.size():
		indices.append(index + team * HALF_SPAWNS.size())
	return indices


func capture_zones() -> Array:
	return [["A", CENTER_NODES[0]], ["B", CENTER_NODES[1]], ["C", CENTER_NODES[2]]]


func nav_points() -> Array:
	return nav_graph()["points"]


## 봇 이동 그래프. points는 지점 목록, edges는 연결된 지점 번호 쌍.
func nav_graph() -> Dictionary:
	var half := HALF_NODES.size()
	var mirror_start := half + CENTER_NODES.size()
	var points: Array = []
	points.append_array(HALF_NODES)
	points.append_array(CENTER_NODES)
	for node: Vector3 in HALF_NODES:
		points.append(_mirror(node))
	var edges: Array = []
	for edge: Array in HALF_EDGES:
		edges.append([edge[0], edge[1]])
		edges.append([mirror_start + int(edge[0]), mirror_start + int(edge[1])])
	for link: Array in HALF_TO_CENTER:
		var center: int = link[1]
		edges.append([link[0], half + center])
		# 180도 돌리면 A와 C가 서로 바뀐다.
		edges.append([mirror_start + int(link[0]), half + (CENTER_NODES.size() - 1 - center)])
	for index in CENTER_NODES.size() - 1:
		edges.append([half + index, half + index + 1])
	return {"points": points, "edges": edges}


func _mirror(point: Vector3) -> Vector3:
	return Vector3(-point.x, point.y, -point.z)


func _add_box(center: Vector3, size: Vector3, kind: String) -> void:
	var material := Surfaces.material(kind)
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
