extends "res://maps/arena_base.gd"
## 두 번째 맵 "Compound". 해 질 녘의 흙벽 주택 단지로, Depot보다 작고 가까운 거리 교전이 많다.
##
## - 크기 48 x 64 m. 0팀은 +z 끝, 1팀은 -z 끝에서 시작한다.
## - 한가운데에 지붕 있는 건물이 있다. 남북 벽에 문과 창이 하나씩, 동서 벽에 문이 하나씩 있다.
##   거점 B는 건물 안, A와 C는 건물 양옆 마당이다.
## - 진영과 건물 사이를 벽돌 담(z = ±15)이 가로막고, 담의 틈 세 곳(왼쪽 끝, 가운데, 오른쪽 끝)으로 넘어간다.
## - 한쪽 절반만 정의하고 180도 돌려 복사하므로 두 팀의 조건이 같다.

const AMBIENCE := preload("res://game/audio/sfx/ambience_yard.ogg")
const AMBIENCE_VOLUME_DB := -24.0
const BOUNDARY_HEIGHT := 4.0
const WALL := "plaster"
const BRICK := "brick"
## 건물 벽 높이와 두께, 문 위 인방이 시작하는 높이.
const ROOM_HEIGHT := 3.7
const DOOR_HEIGHT := 2.4
const ROOF := [Vector3(0.0, 3.85, 0.0), Vector3(16.5, 0.3, 12.75)]
## 동서 문 위의 인방. 가운데 선 위에 있어 절반 목록에 넣지 않는다.
const SIDE_LINTELS := [
	[Vector3(-8.0, 3.05, 0.0), Vector3(0.5, 1.3, 2.3)],
	[Vector3(8.0, 3.05, 0.0), Vector3(0.5, 1.3, 2.3)],
]
## 경기장 밖의 집들(보이기만 하고 충돌은 없다). [중심, 크기].
const BACKDROP := [
	[Vector3(-33.0, 3.5, -14.0), Vector3(14.0, 7.0, 20.0)],
	[Vector3(-32.0, 2.5, 12.0), Vector3(12.0, 5.0, 16.0)],
	[Vector3(-34.0, 4.5, 30.0), Vector3(16.0, 9.0, 12.0)],
	[Vector3(33.0, 3.0, 18.0), Vector3(14.0, 6.0, 22.0)],
	[Vector3(32.0, 4.5, -10.0), Vector3(12.0, 9.0, 18.0)],
	[Vector3(34.0, 2.5, -30.0), Vector3(16.0, 5.0, 12.0)],
	[Vector3(-10.0, 3.0, -41.0), Vector3(22.0, 6.0, 14.0)],
	[Vector3(16.0, 4.5, -42.0), Vector3(18.0, 9.0, 16.0)],
	[Vector3(8.0, 3.0, 41.0), Vector3(24.0, 6.0, 14.0)],
	[Vector3(-18.0, 4.5, 42.0), Vector3(18.0, 9.0, 16.0)],
]

## 절반(z > 0)의 구조물. 각 항목은 [중심, 크기, 재질 종류].
const HALF_BOXES := [
	# 건물 남쪽 벽(z = 6): 벽, 문(x -5.2 ~ -2.8), 벽, 창(x 2 ~ 5), 벽
	[Vector3(-6.6, 1.85, 6.0), Vector3(2.8, 3.7, 0.5), WALL],
	[Vector3(-4.0, 3.05, 6.0), Vector3(2.4, 1.3, 0.5), WALL],
	[Vector3(-0.4, 1.85, 6.0), Vector3(4.8, 3.7, 0.5), WALL],
	[Vector3(3.5, 0.5, 6.0), Vector3(3.0, 1.0, 0.5), WALL],
	[Vector3(3.5, 2.95, 6.0), Vector3(3.0, 1.5, 0.5), WALL],
	[Vector3(6.5, 1.85, 6.0), Vector3(3.0, 3.7, 0.5), WALL],
	# 건물 동서 벽의 절반. 가운데(|z| < 1.15)는 문이다.
	[Vector3(-8.0, 1.85, 3.7), Vector3(0.5, 3.7, 5.1), WALL],
	[Vector3(8.0, 1.85, 3.7), Vector3(0.5, 3.7, 5.1), WALL],
	# 건물 안의 엄폐물
	[Vector3(4.0, 0.6, 3.2), Vector3(2.0, 1.2, 2.0), "crate"],
	# 진영과 건물 사이의 벽돌 담. 틈: x < -18, -10 < x < 4, x > 12.
	[Vector3(-14.0, 1.5, 15.0), Vector3(8.0, 3.0, 0.6), BRICK],
	[Vector3(8.0, 1.5, 15.0), Vector3(8.0, 3.0, 0.6), BRICK],
	# 진영 앞을 가리는 담
	[Vector3(0.0, 1.5, 21.0), Vector3(4.0, 3.0, 0.6), BRICK],
	# 왼쪽 마당(거점 A 쪽)
	[Vector3(-12.5, 1.25, 3.5), Vector3(2.0, 2.5, 3.0), "container"],
	[Vector3(-20.5, 0.6, 5.0), Vector3(2.0, 1.2, 2.0), "crate"],
	[Vector3(-21.5, 0.5, 10.5), Vector3(0.6, 1.0, 3.0), "barrier"],
	# 오른쪽 마당(거점 C 쪽)
	[Vector3(13.0, 0.6, 4.0), Vector3(2.0, 1.2, 2.0), "crate"],
	[Vector3(21.0, 1.25, 10.0), Vector3(2.0, 2.5, 4.0), "container"],
	[Vector3(20.5, 0.5, 3.0), Vector3(1.4, 1.0, 1.4), "barrels"],
	# 건물 앞마당
	[Vector3(10.5, 1.25, 10.0), Vector3(4.0, 2.5, 1.0), "container"],
	[Vector3(2.0, 0.6, 11.5), Vector3(3.0, 1.2, 1.2), "crate"],
	# 진영 앞
	[Vector3(-10.0, 0.5, 19.5), Vector3(3.0, 1.0, 0.6), "barrier"],
	[Vector3(12.0, 0.5, 19.5), Vector3(1.4, 1.0, 1.4), "barrels"],
]

const HALF_SPAWNS := [
	Vector3(0.0, 0.1, 27.5),
	Vector3(-5.0, 0.1, 28.5),
	Vector3(5.0, 0.1, 28.5),
	Vector3(-11.0, 0.1, 27.0),
	Vector3(11.0, 0.1, 27.0),
	Vector3(-17.0, 0.1, 28.0),
	Vector3(17.0, 0.1, 28.0),
]

const HALF_NODES := [
	Vector3(0.0, 0.0, 27.0),
	Vector3(-21.0, 0.0, 22.0),
	Vector3(18.0, 0.0, 22.0),
	Vector3(-21.0, 0.0, 15.0),
	Vector3(-3.0, 0.0, 15.0),
	Vector3(18.0, 0.0, 15.0),
	Vector3(-17.0, 0.0, 8.0),
	Vector3(-4.0, 0.0, 9.0),
	Vector3(17.0, 0.0, 8.0),
	# 남쪽 문 안
	Vector3(-4.0, 0.0, 3.5),
	Vector3(-6.0, 0.0, 22.0),
	Vector3(6.0, 0.0, 22.0),
]
const HALF_EDGES := [
	[0, 1], [0, 2], [0, 10], [0, 11], [10, 4], [11, 4], [1, 3], [2, 5],
	[3, 6], [4, 7], [4, 6], [5, 8], [6, 7], [7, 9],
]
## 거점 A(왼쪽 마당), B(건물 안), C(오른쪽 마당).
const CENTER_NODES := [
	Vector3(-17.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
	Vector3(17.0, 0.0, 0.0),
]
const HALF_TO_CENTER := [[6, 0], [9, 1], [8, 2]]

@onready var _sun: DirectionalLight3D = $Sun


func _init() -> void:
	half_boxes = HALF_BOXES
	half_spawns = HALF_SPAWNS
	half_nodes = HALF_NODES
	half_edges = HALF_EDGES
	center_nodes = CENTER_NODES
	half_to_center = HALF_TO_CENTER


func _ready() -> void:
	# 해가 낮게 비스듬히 들어 그림자가 길다.
	_sun.rotation_degrees = Vector3(-31.0, 118.0, 0.0)
	($Floor/Mesh as MeshInstance3D).material_override = Surfaces.material("ground")
	build_arena(Vector2(48.0, 64.0), BOUNDARY_HEIGHT, BRICK)
	add_box(ROOF[0], ROOF[1], "roof")
	for lintel: Array in SIDE_LINTELS:
		add_box(lintel[0], lintel[1], WALL)
	add_buildings(BACKDROP, "plaster_far")
	# 지붕 아래가 너무 어둡지 않게 실내등을 둔다. 그림자는 만들지 않는다(휴대폰 성능).
	for x: float in [-4.0, 4.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 3.0, 0.0)
		lamp.light_color = Color(1.0, 0.82, 0.6)
		lamp.light_energy = 1.4
		lamp.omni_range = 9.0
		add_child(lamp)
	play_ambience(AMBIENCE, AMBIENCE_VOLUME_DB)
