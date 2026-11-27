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

const CONTAINER_KINDS := ["container", "container_blue", "container_rust"]
## 경기장 바깥의 창고 건물(보이기만 하고 충돌은 없다). [중심, 크기].
const BACKDROP := [
	[Vector3(-41.0, 5.0, -18.0), Vector3(18.0, 10.0, 34.0)],
	[Vector3(-41.0, 4.0, 22.0), Vector3(18.0, 8.0, 30.0)],
	[Vector3(41.0, 6.0, 12.0), Vector3(18.0, 12.0, 36.0)],
	[Vector3(41.0, 4.0, -24.0), Vector3(18.0, 8.0, 24.0)],
	[Vector3(-12.0, 5.5, -51.0), Vector3(36.0, 11.0, 18.0)],
	[Vector3(22.0, 4.0, -51.0), Vector3(22.0, 8.0, 18.0)],
	[Vector3(10.0, 5.0, 51.0), Vector3(40.0, 10.0, 18.0)],
	[Vector3(-24.0, 3.5, 51.0), Vector3(20.0, 7.0, 18.0)],
]
const LANE_X := [-20.0, 0.0, 20.0]

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
	# 통로 가장자리의 방호벽과 드럼통. 이동 그래프의 선(x = -20, 0, 20, z = 26, 30)은 비워 둔다.
	[Vector3(-27.0, 0.5, 11.0), Vector3(0.6, 1.0, 3.0), "barrier"],
	[Vector3(-13.0, 0.5, 17.0), Vector3(1.4, 1.0, 1.4), "barrels"],
	[Vector3(-27.5, 0.5, 23.0), Vector3(1.4, 1.0, 1.4), "barrels"],
	[Vector3(-6.5, 0.5, 19.0), Vector3(3.0, 1.0, 0.6), "barrier"],
	[Vector3(7.0, 0.5, 22.5), Vector3(1.4, 1.0, 1.4), "barrels"],
	[Vector3(3.8, 0.5, 8.0), Vector3(3.0, 1.0, 0.6), "barrier"],
	[Vector3(27.0, 0.5, 10.5), Vector3(0.6, 1.0, 3.0), "barrier"],
	[Vector3(13.0, 0.5, 19.0), Vector3(1.4, 1.0, 1.4), "barrels"],
	[Vector3(27.5, 0.5, 23.0), Vector3(1.4, 1.0, 1.4), "barrels"],
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
	for index in HALF_BOXES.size():
		var box: Array = HALF_BOXES[index]
		var kind: String = box[2]
		var other := kind
		if kind == TALL_COLOR:
			# 컨테이너는 색을 섞고, 넓은 것 일부는 2단으로 쌓는다(위 칸도 총알을 막는다).
			kind = CONTAINER_KINDS[index % CONTAINER_KINDS.size()]
			other = CONTAINER_KINDS[(index + 1) % CONTAINER_KINDS.size()]
			var size: Vector3 = box[1]
			if index % 2 == 0 and size.x * size.z >= 4.5:
				var above := Vector3(0.0, size.y, 0.0)
				_add_box(box[0] + above, size, other)
				_add_box(_mirror(box[0]) + above, size, kind)
		_add_box(box[0], box[1], kind)
		_add_box(_mirror(box[0]), box[1], other)
	_add_backdrop()


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
	var body := StaticBody3D.new()
	body.position = center
	var visual := Surfaces.prop(kind, size)
	if visual == null:
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = Surfaces.material(kind)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = mesh
		visual = mesh_instance
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(visual)
	body.add_child(collision)
	add_child(body)


## 경기장 밖 건물과 바닥 차선. 플레이에는 영향이 없는 꾸밈이다.
func _add_backdrop() -> void:
	for item: Array in BACKDROP:
		var mesh := BoxMesh.new()
		mesh.size = item[1]
		mesh.material = Surfaces.material("warehouse")
		var building := MeshInstance3D.new()
		building.mesh = mesh
		building.position = item[0]
		add_child(building)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.78, 0.74, 0.5)
	paint.roughness = 0.9
	var dash := BoxMesh.new()
	dash.size = Vector3(0.14, 0.01, 2.2)
	dash.material = paint
	for x: float in LANE_X:
		for step in range(-7, 8):
			var line := MeshInstance3D.new()
			line.mesh = dash
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			line.position = Vector3(x, 0.006, step * 5.0)
			add_child(line)
