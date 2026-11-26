extends RefCounted
## 맵의 이동 그래프에서 길을 찾는다. 봇이 벽을 돌아 목적지로 가는 데 쓴다.

var _astar := AStar3D.new()


## graph는 {"points": 지점 목록, "edges": 연결된 지점 번호 쌍 목록}.
func _init(graph: Dictionary) -> void:
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
		var start := _astar.get_closest_point(from)
		var goal := _astar.get_closest_point(to)
		for point: Vector3 in _astar.get_point_path(start, goal):
			route.append(point)
	# 첫 지점이 진행 방향의 뒤쪽이면(다음 지점이 이미 더 가까우면) 되돌아가지 않고 건너뛴다.
	if route.size() >= 2:
		var first: Vector3 = route[0]
		var second: Vector3 = route[1]
		if from.distance_to(second) < first.distance_to(second):
			route.pop_front()
	route.append(to)
	return route
