extends RefCounted
## 리스폰 위치 선택.


## 후보 스폰 중 살아 있는 적에게서 가장 먼 곳의 번호를 돌려준다.
## 팀별 스폰이 정해진 맵에서는 자기 진영에서만 고른다.
## 적이 없을 때의 자리는, 팀 스폰이 없는 맵(테스트용 평지)에서는 팀 번호로 정해져 결과가 매번 같다.
static func pick(map: Node, team: int, self_id: int, enemy_positions: Array) -> int:
	var candidates: Array = range(int(map.call("spawn_count")))
	var best: int = candidates[team % candidates.size()]
	if map.has_method("spawn_indices_for"):
		candidates = map.call("spawn_indices_for", team)
		best = candidates[self_id % candidates.size()]
	var best_distance := -1.0
	for index: int in candidates:
		var spot: Transform3D = map.call("spawn_point", index)
		var nearest := INF
		for enemy: Vector3 in enemy_positions:
			nearest = minf(nearest, spot.origin.distance_to(enemy))
		if nearest != INF and nearest > best_distance:
			best_distance = nearest
			best = index
	return best
