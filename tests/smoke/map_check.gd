extends Node3D
## 맵 검사. 눈으로 확인할 수 없는 배치 실수를 물리 광선으로 찾아낸다.
## - 스폰과 이동 지점이 바닥 위에 있고 구조물 속이 아닌지
## - 이동 그래프의 모든 연결이 사람 폭만큼 비어 있는지
## - 양 팀 진영이 그래프로 이어져 있는지, 팀 스폰이 자기 진영에 있는지
## - 스폰에서 상대 스폰이 바로 보이지 않는지
## 실행: godot --headless --fixed-fps 60 res://tests/smoke/map_check.tscn [-- --map=compound]

const Catalog := preload("res://maps/catalog.gd")
const LaunchArgs := preload("res://game/core/launch_args.gd")
const NavGraph := preload("res://game/bots/nav_graph.gd")
const BODY_HALF_WIDTH := 0.45
const CHECK_HEIGHTS := [0.3, 1.2]

var _map: Node3D
var _tick := 0
var _failures := PackedStringArray()


func _ready() -> void:
	var map_name := str(LaunchArgs.parse().get("map", "depot"))
	_map = (load(Catalog.path(map_name)) as PackedScene).instantiate()
	add_child(_map)


func _physics_process(_delta: float) -> void:
	_tick += 1
	if _tick != 3:
		return
	var graph: Dictionary = _map.call("nav_graph")
	var points: Array = graph["points"]
	var edges: Array = graph["edges"]
	for index in points.size():
		_check_on_floor(points[index], "nav point %d" % index)
	for index: int in _map.call("spawn_count"):
		var spawn: Transform3D = _map.call("spawn_point", index)
		_check_on_floor(spawn.origin, "spawn %d" % index)
	for zone: Array in _map.call("capture_zones"):
		_check_on_floor(zone[1], "zone %s" % zone[0])
	for edge: Array in edges:
		_check_edge(points[edge[0]], points[edge[1]], "link %d-%d" % [edge[0], edge[1]])
	_check_teams(graph)
	for failure in _failures:
		printerr("MAP CHECK FAIL ", failure)
	var summary := [points.size(), edges.size(), _failures.size()]
	print("map check: %d points, %d links, %d failures" % summary)
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _check_on_floor(point: Vector3, what: String) -> void:
	var from := Vector3(point.x, 3.6, point.z)
	var hit := _ray(from, Vector3(point.x, -1.0, point.z))
	if hit.is_empty():
		_failures.append("%s at %s has no floor under it" % [what, point])
		return
	var height: float = (hit["position"] as Vector3).y
	if absf(height) > 0.05:
		var detail := [what, point, height]
		_failures.append("%s at %s is on or inside a structure (surface at %.2f m)" % detail)


func _check_edge(from: Vector3, to: Vector3, what: String) -> void:
	var along := (to - from).normalized()
	var side := along.cross(Vector3.UP).normalized() * BODY_HALF_WIDTH
	for height: float in CHECK_HEIGHTS:
		for shift: float in [-1.0, 0.0, 1.0]:
			var offset := side * shift + Vector3.UP * height
			var hit := _ray(from + offset, to + offset)
			if not hit.is_empty():
				_failures.append("%s is blocked at %s" % [what, hit["position"]])
				return


func _check_teams(graph: Dictionary) -> void:
	var navigator := NavGraph.new(graph)
	var team_a: Array = _map.call("spawn_indices_for", 0)
	var team_b: Array = _map.call("spawn_indices_for", 1)
	if team_a.size() < 6 or team_b.size() < 6:
		_failures.append("each team needs at least 6 spawns")
	for index: int in team_a:
		if team_b.has(index):
			_failures.append("spawn %d belongs to both teams" % index)
		var spawn: Transform3D = _map.call("spawn_point", index)
		if spawn.origin.z < 20.0:
			_failures.append("team 0 spawn %d is outside its base" % index)
	for index: int in team_b:
		var spawn: Transform3D = _map.call("spawn_point", index)
		if spawn.origin.z > -20.0:
			_failures.append("team 1 spawn %d is outside its base" % index)
	var home: Transform3D = _map.call("spawn_point", team_a[0])
	var away: Transform3D = _map.call("spawn_point", team_b[0])
	var route: Array = navigator.path(home.origin, away.origin)
	if route.size() < 5:
		_failures.append("no route through the graph between the two bases")
	var eye := Vector3.UP * 1.6
	if _ray(home.origin + eye, away.origin + eye).is_empty():
		_failures.append("the first spawns of both teams can see each other")


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return get_world_3d().direct_space_state.intersect_ray(query)
