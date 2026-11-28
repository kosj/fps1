extends RefCounted

const NavGraph := preload("res://game/bots/nav_graph.gd")
const CombatBot := preload("res://game/bots/combat_bot.gd")
const InputCmd := preload("res://game/player/input_cmd.gd")
const ArenaBase := preload("res://maps/arena_base.gd")
const Catalog := preload("res://maps/catalog.gd")
## ㄷ자 길: 0 -(동쪽)- 1 -(북쪽)- 2. 0과 2 사이에는 벽이 있다고 가정한다.
const GRAPH := {
	"points": [Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0), Vector3(10.0, 0.0, -10.0)],
	"edges": [[0, 1], [1, 2]],
}


func test_path_follows_edges_and_ends_at_goal() -> String:
	var graph := NavGraph.new(GRAPH)
	var goal := Vector3(11.0, 0.0, -11.0)
	var route: Array = graph.path(Vector3(-1.0, 0.0, 0.0), goal)
	var wanted := [GRAPH["points"][0], GRAPH["points"][1], GRAPH["points"][2], goal]
	if route != wanted:
		return "expected the route to pass every node, got %s" % [route]
	return ""


func test_path_skips_a_node_already_passed() -> String:
	var graph := NavGraph.new(GRAPH)
	# 0번 지점을 지나 1번 쪽으로 3 m 간 상태. 0번으로 되돌아가면 안 된다.
	var route: Array = graph.path(Vector3(3.0, 0.0, 0.0), Vector3(10.0, 0.0, -10.0))
	if route.is_empty() or route[0] != GRAPH["points"][1]:
		return "route should start at the next node, got %s" % [route]
	return ""


func test_bot_walks_the_route_instead_of_a_straight_line() -> String:
	var bot := CombatBot.new(2)
	bot.navigator = NavGraph.new(GRAPH)
	var goal: Vector3 = GRAPH["points"][2]
	var cmd: InputCmd
	for tick in 120:
		cmd = bot.make_cmd(1.0 / 60.0, Vector3(0.0, 1.6, 0.0), Vector3.ZERO, 5.0, [], [goal])
	# 목적지는 북동쪽이지만 길은 먼저 동쪽(+x)으로 난다. yaw -90도가 동쪽이다.
	if absf(angle_difference(cmd.yaw, -PI / 2.0)) > 0.05:
		return "bot should first head east along the graph, yaw was %f" % cmd.yaw
	return ""


## 가운데 선 위의 비(非)거점 지점은 180도 돌린 짝과 이어져야 양쪽 골목이 한 길이 된다.
func test_line_nodes_join_both_halves() -> String:
	var arena: Node3D = ArenaBase.new()
	arena.half_nodes = [Vector3(-5.0, 0.0, 3.0)]
	arena.center_nodes = [Vector3(-2.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)]
	arena.line_nodes = [Vector3(-5.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0)]
	arena.half_to_line = [[0, 0]]
	var graph: Dictionary = arena.nav_graph()
	arena.free()
	var points: Array = graph["points"]
	var linked := {}
	for edge: Array in graph["edges"]:
		linked[[points[edge[0]], points[edge[1]]]] = true
	if not linked.has([Vector3(-5.0, 0.0, 3.0), Vector3(-5.0, 0.0, 0.0)]):
		return "half node should link to its line node"
	if not linked.has([Vector3(5.0, 0.0, -3.0), Vector3(5.0, 0.0, 0.0)]):
		return "mirrored half node should link to the mirrored line node, edges %s" % [graph["edges"]]
	return ""


## 판마다 맵이 차례로 바뀌고 마지막 다음은 처음으로 돌아온다.
func test_map_rotation_visits_every_map() -> String:
	var names := Catalog.names()
	var current: String = names[0]
	var seen := [current]
	for i in names.size():
		current = Catalog.next(current)
		seen.append(current)
	if seen.slice(0, names.size()) != names or current != names[0]:
		return "rotation should visit %s in order, got %s" % [names, seen]
	if not names.has("outpost"):
		return "outpost should be in the catalog"
	return ""
