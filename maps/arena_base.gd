extends Node3D
## 대칭 경기장 맵의 공통 부분. 맵은 절반(z > 0)만 정의하고, 여기서 180도 돌려 복사해
## 두 팀의 조건을 같게 만든다. 스폰, 거점, 봇 이동 그래프도 같은 방식으로 펼친다.
##
## 맵 스크립트는 _init에서 아래 변수들을 채우고 _ready에서 build_arena를 부른다.

const Surfaces := preload("res://game/world/surfaces.gd")
const Dressing := preload("res://maps/dressing.gd")
const CONTAINER_KINDS := ["container", "container_blue", "container_rust"]
const CONTAINER := "container"

## 절반의 구조물. 각 항목은 [중심, 크기, 재질 종류].
var half_boxes: Array = []
## 0팀(z > 0) 스폰 위치. 1팀은 180도 돌린 자리를 쓴다.
var half_spawns: Array = []
## 이동 그래프의 절반 지점과 그 사이 연결(지점 번호 쌍).
var half_nodes: Array = []
var half_edges: Array = []
## 가운데 선 위의 지점. 거점 A, B, C의 중심이기도 하다.
var center_nodes: Array = []
## 절반 지점과 가운데 지점의 연결. [half_nodes 번호, center_nodes 번호].
var half_to_center: Array = []
## 거점이 아닌 가운데 선(z = 0) 위의 지점. 180도 돌려도 목록 안의 다른 지점이 되도록 짝을 지어 넣는다
## (예: 양쪽 가장자리 골목). 절반 지점과의 연결은 [half_nodes 번호, line_nodes 번호].
var line_nodes: Array = []
var half_to_line: Array = []


## 바깥 벽과 구조물을 만든다. size는 경기장의 [가로(x), 세로(z)] 크기.
func build_arena(size: Vector2, wall_height: float, wall_kind: String) -> void:
	var half_x := size.x / 2.0 + 0.5
	var half_z := size.y / 2.0 + 0.5
	var y := wall_height / 2.0
	add_box(Vector3(-half_x, y, 0.0), Vector3(1.0, wall_height, size.y + 2.0), wall_kind)
	add_box(Vector3(half_x, y, 0.0), Vector3(1.0, wall_height, size.y + 2.0), wall_kind)
	add_box(Vector3(0.0, y, -half_z), Vector3(size.x + 2.0, wall_height, 1.0), wall_kind)
	add_box(Vector3(0.0, y, half_z), Vector3(size.x + 2.0, wall_height, 1.0), wall_kind)
	for index in half_boxes.size():
		var box: Array = half_boxes[index]
		var kind: String = box[2]
		var other := kind
		if kind == CONTAINER:
			# 컨테이너는 색을 섞고, 넓은 것 일부는 2단으로 쌓는다(위 칸도 총알을 막는다).
			kind = CONTAINER_KINDS[index % CONTAINER_KINDS.size()]
			other = CONTAINER_KINDS[(index + 1) % CONTAINER_KINDS.size()]
			var box_size: Vector3 = box[1]
			if index % 2 == 0 and box_size.x * box_size.z >= 4.5:
				var above := Vector3(0.0, box_size.y, 0.0)
				add_box(box[0] + above, box_size, other)
				add_box(mirror(box[0]) + above, box_size, kind)
		add_box(box[0], box[1], kind)
		add_box(mirror(box[0]), box[1], other)


func spawn_count() -> int:
	return half_spawns.size() * 2


## 앞쪽 절반 번호는 0팀, 뒤쪽 절반 번호는 1팀 스폰이다.
func spawn_point(index: int) -> Transform3D:
	var wrapped := index % spawn_count()
	if wrapped < half_spawns.size():
		return Transform3D(Basis.IDENTITY, half_spawns[wrapped])
	var facing := Basis.from_euler(Vector3(0.0, PI, 0.0))
	return Transform3D(facing, mirror(half_spawns[wrapped - half_spawns.size()]))


## 이 팀이 쓸 수 있는 스폰 번호.
func spawn_indices_for(team: int) -> Array:
	var indices: Array = []
	for index in half_spawns.size():
		indices.append(index + team * half_spawns.size())
	return indices


func capture_zones() -> Array:
	return [["A", center_nodes[0]], ["B", center_nodes[1]], ["C", center_nodes[2]]]


func nav_points() -> Array:
	return nav_graph()["points"]


## 봇 이동 그래프. points는 지점 목록, edges는 연결된 지점 번호 쌍.
func nav_graph() -> Dictionary:
	var half := half_nodes.size()
	var mirror_start := half + center_nodes.size()
	var points: Array = []
	points.append_array(half_nodes)
	points.append_array(center_nodes)
	for node: Vector3 in half_nodes:
		points.append(mirror(node))
	var edges: Array = []
	for edge: Array in half_edges:
		edges.append([edge[0], edge[1]])
		edges.append([mirror_start + int(edge[0]), mirror_start + int(edge[1])])
	for link: Array in half_to_center:
		var center: int = link[1]
		edges.append([link[0], half + center])
		# 180도 돌리면 A와 C가 서로 바뀐다.
		edges.append([mirror_start + int(link[0]), half + (center_nodes.size() - 1 - center)])
	for index in center_nodes.size() - 1:
		edges.append([half + index, half + index + 1])
	var line_start := points.size()
	points.append_array(line_nodes)
	for link: Array in half_to_line:
		var line: int = link[1]
		edges.append([link[0], line_start + line])
		var mirrored := line_nodes.find(mirror(line_nodes[line]))
		edges.append([mirror_start + int(link[0]), line_start + mirrored])
	return {"points": points, "edges": edges}


func mirror(point: Vector3) -> Vector3:
	return Vector3(-point.x, point.y, -point.z)


## 충돌이 있는 상자 구조물 하나. 그 크기의 엄폐물 모델이 있으면 모델을, 없으면 상자를 보여 준다.
func add_box(center: Vector3, size: Vector3, kind: String) -> void:
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
	Dressing.add_contact_shadow(self, center, size)


## 경기장 밖 건물(보이기만 하고 충돌은 없다). 각 항목은 [중심, 크기].
func add_buildings(items: Array, kind: String) -> void:
	for item: Array in items:
		Dressing.add_building(self, item[0], item[1], kind)


## 반복 재생되는 배경음.
func play_ambience(stream: AudioStream, volume_db: float) -> void:
	var ambience := AudioStreamPlayer.new()
	var loop := stream as AudioStreamOggVorbis
	loop.loop = true
	ambience.stream = loop
	ambience.volume_db = volume_db
	ambience.autoplay = true
	add_child(ambience)
