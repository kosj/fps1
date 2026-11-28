extends RefCounted
## 맵의 이동 그래프에서 길을 찾는다. 봇이 벽을 돌아 목적지로 가는 데 쓴다.

## 출발 지점 후보로 살펴볼 가까운 지점 수.
const START_CANDIDATES := 6
## 걸어갈 수 있는지 볼 광선 높이(무릎, 가슴)와 구조물 충돌층.
const WALK_HEIGHTS := [0.4, 1.1]
const WORLD_MASK := 1

var _astar := AStar3D.new()
## 맵의 물리 세계. 있으면 벽 너머의 지점에서 출발하지 않는다(테스트처럼 없으면 가장 가까운 지점).
var _world: World3D


## graph는 {"points": 지점 목록, "edges": 연결된 지점 번호 쌍 목록}.
func _init(graph: Dictionary, world: World3D = null) -> void:
	_world = world
	var points: Array = graph["points"]
	for index in points.size():
		_astar.add_point(index, points[index])
	for edge: Array in graph["edges"]:
		_astar.connect_points(edge[0], edge[1])


func point_count() -> int:
	return _astar.get_point_count()


## from에서 to까지 차례로 거쳐 갈 지점들. 마지막 항목은 항상 to다.
func path(from: Vector3, to: Vector3) -> Array:
	var route: Array = []
	if _astar.get_point_count() > 0:
		var start := _start_point(from)
		var goal := _astar.get_closest_point(to)
		for point: Vector3 in _astar.get_point_path(start, goal):
			route.append(point)
	# 첫 지점이 진행 방향의 뒤쪽이면(다음 지점이 이미 더 가까우면) 되돌아가지 않고 건너뛴다.
	if route.size() >= 2:
		var first: Vector3 = route[0]
		var second: Vector3 = route[1]
		var ahead := from.distance_to(second) < first.distance_to(second)
		if ahead and (_world == null or _walkable(from, second)):
			route.pop_front()
	route.append(to)
	return route


## 출발 지점: 가까운 지점 중 벽에 막히지 않고 곧장 걸어갈 수 있는 것.
## 가장 가까운 지점이 벽 너머(건물 안팎)에 있으면 봇이 벽에 붙어 멈추던 문제를 막는다.
func _start_point(from: Vector3) -> int:
	var nearest := _astar.get_closest_point(from)
	if _world == null:
		return nearest
	var ids := Array(_astar.get_point_ids())
	ids.sort_custom(
		func(a: int, b: int) -> bool:
			var to_a := from.distance_squared_to(_astar.get_point_position(a))
			return to_a < from.distance_squared_to(_astar.get_point_position(b))
	)
	for id: int in ids.slice(0, START_CANDIDATES):
		if _walkable(from, _astar.get_point_position(id)):
			return id
	return nearest


func _walkable(from: Vector3, to: Vector3) -> bool:
	var space := _world.direct_space_state
	for height: float in WALK_HEIGHTS:
		var lift := Vector3.UP * height
		var query := PhysicsRayQueryParameters3D.create(from + lift, to + lift, WORLD_MASK)
		if not space.intersect_ray(query).is_empty():
			return false
	return true
