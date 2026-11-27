extends RefCounted
## 권한 쪽(서버, 서버 없는 경기) 판정에서 참가자 목록만으로 계산되는 부분을 모았다.
## game_session.gd가 한 파일 줄 수 한도에 가까워 떼어 낸 순수 계산이다.
## peers는 game_session의 참가자 사전: id -> {player, team, kind, history, protected, kills, deaths, ...}.

const HitMath := preload("res://game/combat/hit_math.gd")
const Protocol := preload("res://game/net/net_protocol.gd")
const Grenades := preload("res://game/combat/grenades.gd")
const BOT_SIGHT_RANGE := 60.0
const BOT_NEAR_RANGE := 10.0


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


## 폭발에 맞는 참가자와 피해. 각 항목은 [id, 피해, 맞은 자리(가슴)].
## 던진 사람 자신과 적만 맞고, 같은 팀은 맞지 않는다. 벽 뒤와 리스폰 보호 중인 사람은 제외한다.
static func blast_hits(peers: Dictionary, owner_id: int, at: Vector3) -> Array:
	var hits: Array = []
	var owner_entry: Dictionary = peers[owner_id]
	for id: int in peers:
		var entry: Dictionary = peers[id]
		var player = entry["player"]
		if not player.alive or float(entry["protected"]) > 0.0:
			continue
		if id != owner_id and int(entry["team"]) == int(owner_entry["team"]):
			continue
		var chest: Vector3 = player.global_position + Vector3.UP * (0.7 if player.is_low() else 1.1)
		var amount := Grenades.damage_at(at.distance_to(chest))
		if amount <= 0.0:
			continue
		# 폭발 지점을 바닥에서 조금 띄워, 바닥의 수류탄이 낮은 턱에 가려지지 않게 한다.
		var from := at + Vector3.UP * 0.3
		var wall: Dictionary = player.weapon.world_ray(from, (chest - from).normalized(), 1)
		if wall.is_empty() or from.distance_to(wall["position"]) >= from.distance_to(chest) - 0.3:
			hits.append([id, amount, chest])
	return hits


## 봇의 이번 틱 입력. 보이는 적을 고르고(가까운 적은 방향과 무관하게, 먼 적은 시야각 안에서만),
## 점령전이면 노릴 거점과 지킬 자리를 정해 준다. domination은 점령전이 아니면 null.
static func bot_cmd(peers: Dictionary, id: int, domination, nav_points: Array, delta: float):
	var entry: Dictionary = peers[id]
	var player = entry["player"]
	var visible := visible_enemies(peers, id, BOT_SIGHT_RANGE, BOT_NEAR_RANGE)
	var bot = entry["bot"]
	var goals := nav_points
	bot.has_hold = false
	if domination != null:
		var team := int(entry["team"])
		goals = domination.objectives_for(team, player.global_position)
		var hold: int = domination.hold_zone_for(team, player.global_position)
		if hold >= 0:
			bot.has_hold = true
			bot.hold_point = domination.centers[hold]
	return bot.make_cmd(
		delta, player.eye_position(), player.global_position, player.horizontal_speed(),
		visible, goals
	)
