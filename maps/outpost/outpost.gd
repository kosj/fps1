extends "res://maps/arena_base.gd"
## 세 번째 맵 "Outpost". 안개 낀 겨울 아침의 산속 전초기지로, 세 갈래 길이 뚜렷하다.
##
## - 크기 56 x 72 m. 0팀은 +z 끝, 1팀은 -z 끝에서 시작한다.
## - 양옆(x = ±18)에 지붕 있는 통나무 막사가 하나씩 있다. 남북 끝에 문, 가운데 쪽 벽에 옆문과 창,
##   바깥쪽 벽에 창이 있다. 거점 A와 C는 막사 안, B는 두 막사 사이의 열린 광장이다.
## - 막사 바깥으로 경기장 벽까지 좁은 골목(x = ±23)이 있어 옆으로 돌아 들어갈 수 있다.
## - 진영 앞을 허리 높이 돌담(z = ±17)이 가로지르고, 광장 한가운데 쌓인 컨테이너가 진영 사이의 긴 시야를 끊는다.
## - 한쪽 절반만 정의하고 180도 돌려 복사하므로 두 팀의 조건이 같다.

## 하늘 사진(maps/sky/README.md)과 그 속의 해 자리(u, v).
const SKY := preload("res://maps/sky/outpost_sky.jpg")
const SKY_SUN := Vector2(0.4700, 0.3413)
const SKY_ENERGY := 1.0
const AMBIENCE := preload("res://game/audio/sfx/ambience_wind.ogg")
const AMBIENCE_VOLUME_DB := -20.0
const ARENA := Vector2(56.0, 72.0)
const BOUNDARY_HEIGHT := 4.0
const STONE := "stone"
const PLANKS := "planks"
## 막사: 가운데 x, 벽 높이와 두께, 바닥 크기(x, z), 문 너비와 높이.
const CABIN_X := 18.0
const CABIN_HEIGHT := 3.7
const CABIN_WALL := 0.4
const CABIN_SIZE := Vector2(7.0, 12.0)
const DOOR_WIDTH := 2.4
const DOOR_HEIGHT := 2.4
## 창의 아래턱과 위턱 높이.
const SILL := 1.0
const HEAD := 2.2

## 절반(z > 0)의 엄폐물. 각 항목은 [중심, 크기, 재질 종류]. 막사 벽은 _cabin_half가 덧붙인다.
## 0번 컨테이너는 짝수 번호라 2단으로 쌓인다(광장의 표지 겸 시야 차단).
const HALF_OBJECTS := [
	[Vector3(0.0, 1.25, 11.0), Vector3(3.0, 2.5, 1.5), "container"],
	[Vector3(25.5, 1.25, 26.0), Vector3(3.0, 2.5, 1.5), "container"],
	# 왼쪽 골목의 빨간 철판 창고
	[Vector3(-26.0, 1.25, 10.0), Vector3(2.0, 2.5, 4.0), "shed"],
	# 광장(거점 B)
	[Vector3(-4.5, 1.0, 4.5), Vector3(3.5, 2.0, 0.6), STONE],
	[Vector3(5.5, 0.6, 2.5), Vector3(2.0, 1.2, 2.0), "crate"],
	[Vector3(-8.5, 0.5, 8.5), Vector3(1.4, 1.0, 1.4), "barrels"],
	# 허리 높이 돌담. 틈: |x| < 6, 그리고 막사 쪽 끝(|x| > 13).
	[Vector3(-9.5, 0.55, 17.0), Vector3(7.0, 1.1, 0.6), STONE],
	[Vector3(9.5, 0.55, 17.0), Vector3(7.0, 1.1, 0.6), STONE],
	# 막사 앞
	[Vector3(-13.0, 0.6, 8.0), Vector3(3.0, 1.2, 1.2), "crate"],
	[Vector3(13.5, 0.5, 8.5), Vector3(1.4, 1.0, 1.4), "barrels"],
	# 오른쪽 골목
	[Vector3(24.8, 0.5, 3.0), Vector3(0.6, 1.0, 3.0), "barrier"],
	[Vector3(25.5, 0.6, 14.0), Vector3(2.0, 1.2, 2.0), "crate"],
	# 진영 앞. 가운데 돌담이 양 팀 첫 스폰 사이의 시야를 막는다.
	[Vector3(0.0, 1.5, 24.0), Vector3(4.0, 3.0, 0.6), STONE],
	[Vector3(-9.0, 0.5, 22.5), Vector3(3.0, 1.0, 0.6), "barrier"],
	[Vector3(11.0, 0.5, 21.5), Vector3(1.4, 1.0, 1.4), "barrels"],
	[Vector3(-24.5, 0.6, 25.0), Vector3(3.0, 1.2, 1.5), "crate"],
	# 광장의 시야를 끊는 장작더미와 컨테이너(홀수 번호라 한 단)
	[Vector3(9.0, 0.9, 7.0), Vector3(3.0, 1.8, 1.2), PLANKS],
	[Vector3(-10.5, 1.25, 3.0), Vector3(2.0, 2.5, 3.0), "container"],
]
## 경기장 밖의 통나무집들(보이기만 하고 충돌은 없다). [중심, 크기].
const BACKDROP := [
	[Vector3(-37.0, 2.5, -12.0), Vector3(8.0, 5.0, 10.0)],
	[Vector3(-38.0, 3.0, 16.0), Vector3(10.0, 6.0, 8.0)],
	[Vector3(37.0, 2.5, 10.0), Vector3(9.0, 5.0, 12.0)],
	[Vector3(36.0, 3.0, -20.0), Vector3(8.0, 6.0, 10.0)],
	[Vector3(-14.0, 2.5, 44.0), Vector3(12.0, 5.0, 8.0)],
	[Vector3(16.0, 3.0, -45.0), Vector3(10.0, 6.0, 9.0)],
]

const HALF_SPAWNS := [
	Vector3(0.0, 0.1, 31.5),
	Vector3(-5.0, 0.1, 32.5),
	Vector3(5.0, 0.1, 32.5),
	Vector3(-11.0, 0.1, 31.0),
	Vector3(11.0, 0.1, 31.0),
	Vector3(-17.0, 0.1, 32.0),
	Vector3(17.0, 0.1, 32.0),
]

const HALF_NODES := [
	Vector3(0.0, 0.0, 29.0),
	Vector3(-13.0, 0.0, 27.0),
	Vector3(13.0, 0.0, 27.0),
	Vector3(-23.2, 0.0, 20.0),
	Vector3(23.2, 0.0, 20.0),
	Vector3(-5.5, 0.0, 19.5),
	Vector3(5.5, 0.0, 19.5),
	Vector3(-3.5, 0.0, 14.0),
	Vector3(3.5, 0.0, 14.0),
	# 막사 남쪽 문 앞과 안
	Vector3(-18.0, 0.0, 9.5),
	Vector3(18.0, 0.0, 9.5),
	Vector3(-18.0, 0.0, 3.5),
	Vector3(18.0, 0.0, 3.5),
	# 골목
	Vector3(-23.2, 0.0, 3.0),
	Vector3(23.2, 0.0, 3.0),
	Vector3(-9.0, 0.0, 12.0),
	Vector3(9.0, 0.0, 12.0),
	Vector3(-23.2, 0.0, 9.5),
	Vector3(23.2, 0.0, 9.5),
]
const HALF_EDGES := [
	[0, 1], [0, 2], [0, 5], [0, 6], [1, 3], [2, 4], [1, 9], [2, 10],
	[5, 7], [6, 8], [7, 8], [7, 15], [8, 16], [15, 9], [16, 10], [9, 11], [10, 12],
	[3, 17], [4, 18], [17, 13], [18, 14], [17, 9], [18, 10],
]
## 거점 A(왼쪽 막사 안), B(광장), C(오른쪽 막사 안).
const CENTER_NODES := [
	Vector3(-18.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
	Vector3(18.0, 0.0, 0.0),
]
const HALF_TO_CENTER := [[11, 0], [12, 2], [7, 1], [8, 1]]
## 두 골목이 가운데 선을 넘는 자리.
const LINE_NODES := [Vector3(-23.2, 0.0, 0.0), Vector3(23.2, 0.0, 0.0)]
const HALF_TO_LINE := [[13, 0], [14, 1]]

@onready var _sun: DirectionalLight3D = $Sun


func _init() -> void:
	var boxes: Array = HALF_OBJECTS.duplicate()
	boxes.append_array(_cabin_half(-CABIN_X, 1.0))
	boxes.append_array(_cabin_half(CABIN_X, -1.0))
	half_boxes = boxes
	half_spawns = HALF_SPAWNS
	half_nodes = HALF_NODES
	half_edges = HALF_EDGES
	center_nodes = CENTER_NODES
	half_to_center = HALF_TO_CENTER
	line_nodes = LINE_NODES
	half_to_line = HALF_TO_LINE


func _ready() -> void:
	var environment: Environment = ($WorldEnvironment as WorldEnvironment).environment
	# 안개 낀 겨울 아침(해 고도 29도). 사진 속 해의 방위로 조명을 돌린다.
	Dressing.use_sky(environment, SKY, SKY_SUN, SKY_ENERGY, _sun)
	Dressing.add_far_ground(self, "snow")
	($Floor/Mesh as MeshInstance3D).material_override = Surfaces.material("snow")
	build_arena(ARENA, BOUNDARY_HEIGHT, STONE)
	for side: float in [-1.0, 1.0]:
		_add_cabin_top(side * CABIN_X, -side)
	_add_snow_caps()
	_add_backdrop()
	play_ambience(AMBIENCE, AMBIENCE_VOLUME_DB)


## 막사 하나의 남쪽 절반(z > 0) 벽과 가구. inner는 광장 쪽 방향(+1 또는 -1).
## 북쪽 절반은 반대편 막사의 남쪽 절반을 180도 돌린 것이라 두 막사는 같은 모양이다.
static func _cabin_half(x: float, inner: float) -> Array:
	var h := CABIN_HEIGHT
	var t := CABIN_WALL
	var half_x := CABIN_SIZE.x * 0.5
	var end_z := CABIN_SIZE.y * 0.5
	var outer_x := x - inner * half_x
	var inner_x := x + inner * half_x
	var side := (half_x * 2.0 - DOOR_WIDTH) * 0.5
	var lintel := h - DOOR_HEIGHT
	var above := h - HEAD
	return [
		# 남쪽 벽과 문
		[Vector3(x - half_x + side * 0.5, h * 0.5, end_z), Vector3(side, h, t), PLANKS],
		[Vector3(x + half_x - side * 0.5, h * 0.5, end_z), Vector3(side, h, t), PLANKS],
		[Vector3(x, DOOR_HEIGHT + lintel * 0.5, end_z), Vector3(DOOR_WIDTH, lintel, t), PLANKS],
		# 바깥쪽 벽: 창(z 2 ~ 4)
		[Vector3(outer_x, h * 0.5, 1.0), Vector3(t, h, 2.0), PLANKS],
		[Vector3(outer_x, SILL * 0.5, 3.0), Vector3(t, SILL, 2.0), PLANKS],
		[Vector3(outer_x, HEAD + above * 0.5, 3.0), Vector3(t, above, 2.0), PLANKS],
		[Vector3(outer_x, h * 0.5, 4.9), Vector3(t, h, 1.8), PLANKS],
		# 광장 쪽 벽: 옆문(|z| < 1.2)은 _add_cabin_top의 인방과 함께 열려 있고, 창(z 2.8 ~ 4.4)
		[Vector3(inner_x, h * 0.5, 2.0), Vector3(t, h, 1.6), PLANKS],
		[Vector3(inner_x, SILL * 0.5, 3.6), Vector3(t, SILL, 1.6), PLANKS],
		[Vector3(inner_x, HEAD + above * 0.5, 3.6), Vector3(t, above, 1.6), PLANKS],
		[Vector3(inner_x, h * 0.5, 5.1), Vector3(t, h, 1.4), PLANKS],
		# 바깥쪽 벽에 붙은 침상과 광장 쪽 탁자
		[Vector3(outer_x + inner * 0.7, 0.45, 3.0), Vector3(1.0, 0.9, 2.2), PLANKS],
		[Vector3(x + inner * 1.8, 0.6, 3.6), Vector3(1.2, 1.2, 1.2), "crate"],
	]


## 가운데 선 위에 걸친 막사 부분: 천장, 눈 덮인 박공지붕, 옆문 인방, 실내등.
func _add_cabin_top(x: float, inner: float) -> void:
	var h := CABIN_HEIGHT
	var ceiling := Vector3(CABIN_SIZE.x + 0.4, 0.3, CABIN_SIZE.y + 0.4)
	add_box(Vector3(x, h + 0.15, 0.0), ceiling, PLANKS)
	var eaves := Vector2(ceiling.x, ceiling.z) + Vector2.ONE * 0.9
	var top := Vector3(x, h + 0.31, 0.0)
	Dressing.add_gable_roof(self, top, eaves, 2.2, Surfaces.material("roof_snow"))
	var lintel := h - DOOR_HEIGHT
	var inner_x := x + inner * CABIN_SIZE.x * 0.5
	var lintel_size := Vector3(CABIN_WALL, lintel, DOOR_WIDTH)
	add_box(Vector3(inner_x, DOOR_HEIGHT + lintel * 0.5, 0.0), lintel_size, PLANKS)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(x, h - 0.6, 0.0)
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.3
	lamp.omni_range = 8.0
	add_child(lamp)


## 돌담과 창고 지붕, 경기장 벽 위에 얇게 쌓인 눈(보이기만 한다).
func _add_snow_caps() -> void:
	var tops: Array = []
	for box: Array in half_boxes:
		if box[2] == STONE or box[2] == "shed":
			tops.append([box[0], box[1]])
			tops.append([mirror(box[0]), box[1]])
	var half := ARENA * 0.5 + Vector2.ONE * 0.5
	var y := BOUNDARY_HEIGHT * 0.5
	for sign_x: float in [-1.0, 1.0]:
		tops.append([Vector3(sign_x * half.x, y, 0.0), Vector3(1.0, BOUNDARY_HEIGHT, ARENA.y + 2.0)])
	for sign_z: float in [-1.0, 1.0]:
		tops.append([Vector3(0.0, y, sign_z * half.y), Vector3(ARENA.x + 2.0, BOUNDARY_HEIGHT, 1.0)])
	var snow := Surfaces.material("roof_snow")
	for item: Array in tops:
		var center: Vector3 = item[0]
		var size: Vector3 = item[1]
		var cap := BoxMesh.new()
		cap.size = Vector3(size.x + 0.08, 0.07, size.z + 0.08)
		cap.material = snow
		var mesh := MeshInstance3D.new()
		mesh.mesh = cap
		mesh.position = center + Vector3.UP * (size.y * 0.5 + 0.035)
		add_child(mesh)


## 경기장 밖: 통나무집, 전나무 숲, 멀리 둘러선 설산.
func _add_backdrop() -> void:
	add_buildings(BACKDROP, "planks_far")
	Dressing.add_pines(self, ARENA * 0.5, 4.0, 150.0, 320, BACKDROP)
	var haze := Color(0.69, 0.7, 0.73)
	var rock := Color(0.26, 0.28, 0.32).lerp(haze, 0.4)
	var snow := Color(0.9, 0.92, 0.95).lerp(haze, 0.25)
	Dressing.add_mountains(self, 700.0, 190.0, rock, snow)
