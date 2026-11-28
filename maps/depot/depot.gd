extends "res://maps/arena_base.gd"
## 첫 실전 맵 "Depot". 벽으로 나뉜 세 통로(왼쪽, 가운데, 오른쪽)가 양 팀 진영을 잇는다.
##
## - 크기 60 x 80 m. 0팀은 +z 끝, 1팀은 -z 끝에서 시작한다.
## - 통로 사이 벽은 가운데(|z| < 6)와 진영 앞(|z| > 22)에서 끊겨 옆 통로로 넘어갈 수 있다.
## - 거점 A, B, C는 각 통로의 한가운데에 있다.
## - 한쪽 절반만 정의하고 180도 돌려 복사하므로 두 팀의 조건이 같다.
## - 봇이 벽을 돌아갈 수 있도록 이동 그래프(지점과 연결)를 함께 제공한다.
##   tests/smoke/map_check가 모든 연결이 실제로 막혀 있지 않은지 검사한다.

const WALL_HEIGHT := 4.0
## 하늘 사진(maps/sky/README.md)과 그 속의 해 자리(u, v).
const SKY := preload("res://maps/sky/depot_sky.jpg")
const SKY_SUN := Vector2(0.5947, 0.2334)
const SKY_ENERGY := 1.0
const AMBIENCE := preload("res://game/audio/sfx/ambience_yard.ogg")
const AMBIENCE_VOLUME_DB := -22.0
## 구조물 종류. game/world/surfaces.gd의 재질 이름이다.
const WALL_COLOR := "wall"
const TALL_COLOR := "container"
const LOW_COLOR := "crate"

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


func _init() -> void:
	half_boxes = HALF_BOXES
	half_spawns = HALF_SPAWNS
	half_nodes = HALF_NODES
	half_edges = HALF_EDGES
	center_nodes = CENTER_NODES
	half_to_center = HALF_TO_CENTER


func _ready() -> void:
	var environment: Environment = ($WorldEnvironment as WorldEnvironment).environment
	# 맑은 날 뭉게구름(해 고도 48도). 사진 속 해의 방위로 조명을 돌린다.
	Dressing.use_sky(environment, SKY, SKY_SUN, SKY_ENERGY, _sun)
	Dressing.add_far_ground(self, "floor")
	($Floor/Mesh as MeshInstance3D).material_override = Surfaces.material("floor")
	build_arena(Vector2(60.0, 80.0), WALL_HEIGHT, WALL_COLOR)
	_add_backdrop()
	# 야적장의 바람과 먼 기계음. 끝과 처음을 겹쳐 만든 반복 음원이다.
	play_ambience(AMBIENCE, AMBIENCE_VOLUME_DB)


## 경기장 밖 건물과 바닥 차선. 플레이에는 영향이 없는 꾸밈이다.
func _add_backdrop() -> void:
	add_buildings(BACKDROP, "warehouse")
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
