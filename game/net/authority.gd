extends RefCounted
## 권한 쪽(서버, 서버 없는 경기) 판정에서 참가자 목록만으로 계산되는 부분을 모았다.
## game_session.gd가 한 파일 줄 수 한도에 가까워 떼어 낸 순수 계산이다.
## peers는 game_session의 참가자 사전: id -> {player, team, kind, history, protected, kills, deaths, ...}.

const HitMath := preload("res://game/combat/hit_math.gd")
const Protocol := preload("res://game/net/net_protocol.gd")


## 봇 id가 볼 수 있는 적의 위치 목록. 시야각(가까우면 무시), 거리, 벽 가림을 따진다.
static func visible_enemies(peers: Dictionary, id: int, sight: float, near: float) -> Array:
	var entry: Dictionary = peers[id]
	var player = entry["player"]
	var eye: Vector3 = player.eye_position()
	var forward := Vector3(-sin(player.rotation.y), 0.0, -cos(player.rotation.y))
	var visible: Array = []
	for other: int in peers:
		var target_entry: Dictionary = peers[other]
		var target = target_entry["player"]
		if other == id or int(target_entry["team"]) == int(entry["team"]) or not target.alive:
			continue
		var chest: Vector3 = target.global_position + Vector3.UP * 1.0
		var offset := chest - eye
		var distance := offset.length()
		if distance > sight or distance < 0.01:
			continue
		if distance > near and forward.dot(offset / distance) < 0.5:
			continue
		var wall: Dictionary = player.weapon.world_ray(eye, offset / distance, 1)
		if not wall.is_empty() and eye.distance_to(wall["position"]) < distance:
			continue
		visible.append(target.global_position)
	return visible


## 총알이 reach 안에서 가장 먼저 맞는 상대를 찾는다. 상대 위치는 rewind_tick 시점으로 되감는다.
## 돌려주는 값은 [맞은 id(없으면 0), 거리, 헤드샷 여부].
static func find_target(
	peers: Dictionary, shooter_id: int, origin: Vector3, direction: Vector3, reach: float,
	rewind_tick: float
) -> Array:
	var best_id := 0
	var best_distance := reach
	var best_headshot := false
	var shooter_team := int(peers[shooter_id]["team"])
	for id: int in peers:
		var entry: Dictionary = peers[id]
		if id == shooter_id or not entry["player"].alive:
			continue
		# 같은 팀과 방금 리스폰한 상대는 맞지 않는다.
		if int(entry["team"]) == shooter_team or float(entry["protected"]) > 0.0:
			continue
		var past: Array = HitMath.history_at(entry["history"], rewind_tick)
		if past.is_empty():
			continue
		var hit := HitMath.player_hit(origin, direction, past[0], past[1])
		var distance: float = hit[0]
		if distance >= 0.0 and distance < best_distance:
			best_id = id
			best_distance = distance
			best_headshot = hit[1]
	return [best_id, best_distance, best_headshot]


## 점수판 줄. 각 항목은 [id, 팀, 킬, 데스, 봇 여부]이고 킬이 많은 순이다.
static func score_rows(peers: Dictionary) -> Array:
	var rows: Array = []
	for id: int in peers:
		var entry: Dictionary = peers[id]
		rows.append([
			id, int(entry["team"]), int(entry["kills"]), int(entry["deaths"]),
			str(entry["kind"]) == "bot",
		])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2]))
	return rows


## 스냅샷에 싣는 참가자 줄: [id, 위치, 방향, 플래그, 팀]. 발사 표시는 읽으면서 지운다.
static func snapshot_rows(peers: Dictionary) -> Array:
	var rows: Array = []
	for id: int in peers:
		var player = peers[id]["player"]
		var flags := 0
		if player.is_low():
			flags |= Protocol.FLAG_LOW
		if player.alive:
			flags |= Protocol.FLAG_ALIVE
		if peers[id]["fired"]:
			flags |= Protocol.FLAG_FIRED
			peers[id]["fired"] = false
		flags |= (int(player.weapon.slot) & Protocol.SLOT_MASK) << Protocol.SLOT_SHIFT
		rows.append([id, player.global_position, player.rotation.y, flags, peers[id]["team"]])
	return rows


## 터치 조작의 조준 보조에 쓸, 지금 보이는 적들의 가슴 위치.
## others는 클라이언트에서는 아바타 목록(id -> RemoteAvatar), 그 밖에는 참가자 목록이다.
static func assist_targets(local, others: Dictionary, avatars: bool, own_team: int) -> Array:
	var candidates: Array = []
	for id: int in others:
		if avatars:
			var avatar = others[id]
			if avatar.alive and int(avatar.get_meta("team", -1)) != own_team:
				candidates.append([avatar.position, avatar.low])
		else:
			var other = others[id]["player"]
			if int(others[id]["team"]) != own_team and other.alive:
				candidates.append([other.global_position, other.is_low()])
	var targets: Array = []
	var eye: Vector3 = local.eye_position()
	for candidate: Array in candidates:
		var chest: Vector3 = candidate[0] + Vector3.UP * (0.7 if candidate[1] else 1.1)
		var offset := chest - eye
		var wall: Dictionary = local.weapon.world_ray(eye, offset.normalized(), 1)
		if wall.is_empty() or eye.distance_to(wall["position"]) >= offset.length():
			targets.append(chest)
	return targets
