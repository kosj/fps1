extends Node
## 게임 한 판을 진행한다. 실행 방식은 세 가지다.
## - OFFLINE: 혼자 사격장을 돈다. 네트워크 없이 로컬 플레이어를 직접 시뮬레이션한다.
## - SERVER: 권위 서버. 클라이언트 입력으로 플레이어를 움직이고, 판정하고, 스냅샷을 보낸다.
## - CLIENT: 자기 플레이어를 먼저 움직여 보이고(예측) 서버 결과와 다르면 되돌려 다시 계산한다(보정).
##   다른 플레이어는 조금 과거 시점으로 보간해 그린다.
##
## 서버는 탄 판정 때 쏜 사람이 화면에서 보던 시점으로 상대 위치를 되감는다(지연 보상).
##
## 명령줄 인자(godot ... -- 뒤에 붙인다):
##   --server --port=7777        서버로 실행
##   --connect=127.0.0.1:7777    서버에 접속 (wss://host/path 형식도 가능, 웹은 주소창에 ?connect=...)
##   --map=res://...tscn         맵 지정
##   --bot=strafer|shooter|runner 사람 대신 봇이 조작(자동 테스트)
##   --net-delay-ms=50           클라이언트 송수신에 인위적 지연 추가(자동 테스트)
##   --no-lagcomp                지연 보상 끄기(비교 테스트)
##   --exit-after=10             N초 뒤 통계를 출력하고 종료
##   --expect-...                종료 시 검증할 조건(자동 테스트)

enum Mode { OFFLINE, SERVER, CLIENT }

const Protocol := preload("res://game/net/net_protocol.gd")
const InputCmd := preload("res://game/player/input_cmd.gd")
const HitMath := preload("res://game/combat/hit_math.gd")
const WeaponState := preload("res://game/weapons/weapon_state.gd")
const RemoteAvatar := preload("res://game/player/remote_avatar.gd")
const ScriptBot := preload("res://game/bots/script_bot.gd")
const PLAYER_SCENE := preload("res://game/player/player.tscn")
const DEFAULT_MAP := "res://maps/graybox/graybox.tscn"
const HISTORY_SIZE := 64
const PENDING_LIMIT := 240

var mode := Mode.OFFLINE
var stats := {
	"connected": false,
	"snapshots": 0,
	"corrections": 0,
	"max_error": 0.0,
	"shots": 0,
	"hits": 0,
	"kills": 0,
	"remote_travel": 0.0,
	"peak_players": 0,
	"server_shots": 0,
	"server_hits": 0,
	"rejected_inputs": 0,
}

var _args := {}
var _map: Node
var _tick := 0
var _elapsed := 0.0
var _exit_after := 0.0
var _bot: ScriptBot
var _local = null
var _lag_comp := true
# 서버 전용: 피어 id -> {player, queue, last_seq, queued_seq, history, respawn, spawn, kills, deaths}
var _peers := {}
var _next_spawn := 0
var _shot_view_tick := 0.0
# 클라이언트 전용
var _seq := 0
## 아직 서버 확인을 받지 못한 입력. 각 항목은 [seq, 입력, 그 입력을 적용한 뒤의 예측 상태].
var _pending: Array = []
var _avatars := {}
var _latest_tick := -1
var _render_tick := 0.0
var _delay_ticks := 0
var _out_queue: Array = []
var _in_queue: Array = []
var _remote_min_x := INF
var _remote_max_x := -INF


func _ready() -> void:
	_parse_args()
	_exit_after = float(_args.get("exit-after", "0"))
	_lag_comp = not _args.has("no-lagcomp")
	_delay_ticks = int(round(float(_args.get("net-delay-ms", "0")) * Protocol.TICK_RATE / 1000.0))
	if _args.has("bot"):
		_bot = ScriptBot.new(str(_args["bot"]))
	_map = load(str(_args.get("map", DEFAULT_MAP))).instantiate()
	add_child(_map)

	if _args.has("server") or OS.has_feature("dedicated_server"):
		_start_server(int(_args.get("port", str(Protocol.DEFAULT_PORT))))
	elif _args.has("connect"):
		_start_client(str(_args["connect"]))
	else:
		if _map.has_method("spawn_offline_targets"):
			_map.call("spawn_offline_targets")
		_local = _spawn_player(true, 0)


func _physics_process(delta: float) -> void:
	_tick += 1
	_elapsed += delta
	match mode:
		Mode.SERVER:
			_tick_server(delta)
		Mode.CLIENT:
			_tick_client(delta)
		_:
			if _local != null:
				_local.simulate(_next_local_cmd(delta), delta)
	if _exit_after > 0.0 and _elapsed >= _exit_after:
		_finish()


func _process(_delta: float) -> void:
	if mode != Mode.CLIENT:
		return
	var render_tick := _render_tick + Engine.get_physics_interpolation_fraction()
	for id: int in _avatars:
		var avatar: RemoteAvatar = _avatars[id]
		avatar.sample(render_tick)
		if avatar.alive:
			_remote_min_x = minf(_remote_min_x, avatar.position.x)
			_remote_max_x = maxf(_remote_max_x, avatar.position.x)


# ---------------------------------------------------------------- 공통


func _parse_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var parts := argument.substr(2).split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else ""
	# 웹 빌드에는 명령줄이 없으므로 주소창의 ?connect=호스트:포트 를 읽는다.
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		for pair in query.trim_prefix("?").split("&", false):
			var parts := pair.split("=", true, 1)
			if parts.size() == 2 and parts[0] in ["connect", "map"]:
				_args[parts[0]] = parts[1].uri_decode()


func _spawn_player(local: bool, spawn_index: int):
	var player = PLAYER_SCENE.instantiate()
	player.is_local = local
	player.auto_simulate = false
	if not local or _bot != null:
		player.view_from_cmd = true
		player.require_mouse_capture = false
	add_child(player)
	_place_at_spawn(player, spawn_index)
	return player


func _place_at_spawn(player, spawn_index: int) -> void:
	var spawn: Transform3D = _map.call("spawn_point", spawn_index)
	player.global_position = spawn.origin
	player.rotation.y = spawn.basis.get_euler().y
	player.velocity = Vector3.ZERO


func _next_local_cmd(delta: float) -> InputCmd:
	if _bot == null:
		return _local.gather_cmd()
	var targets: Array = []
	for id: int in _avatars:
		var avatar: RemoteAvatar = _avatars[id]
		if avatar.alive:
			targets.append(avatar.position)
	return _bot.make_cmd(delta, _local.eye_position(), targets)


# ---------------------------------------------------------------- 서버


func _start_server(port: int) -> void:
	var peer := WebSocketMultiplayerPeer.new()
	var error := peer.create_server(port)
	if error != OK:
		printerr("could not listen on port %d (error %d)" % [port, error])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	mode = Mode.SERVER
	print("server listening on port %d" % port)


func _on_peer_connected(id: int) -> void:
	var spawn_index := _next_spawn
	_next_spawn += 1
	var player = _spawn_player(false, spawn_index)
	player.weapon.resolve_shot = _server_resolve_shot.bind(id)
	_peers[id] = {
		"player": player,
		"queue": [],
		"last_seq": 0,
		"queued_seq": 0,
		"history": [],
		"respawn": 0.0,
		"spawn": spawn_index,
		"kills": 0,
		"deaths": 0,
	}
	stats["peak_players"] = maxi(stats["peak_players"], _peers.size())
	print("peer %d joined (%d players)" % [id, _peers.size()])


func _on_peer_disconnected(id: int) -> void:
	if not _peers.has(id):
		return
	_peers[id]["player"].queue_free()
	_peers.erase(id)
	print("peer %d left (%d players)" % [id, _peers.size()])


## 클라이언트가 보낸 입력을 받는다. 보낸 쪽을 믿지 않고 형식, 순서, 양을 모두 검사한다.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_input(data: Array) -> void:
	if mode != Mode.SERVER:
		return
	var id := multiplayer.get_remote_sender_id()
	if not _peers.has(id):
		return
	var entry: Dictionary = _peers[id]
	var cmd: InputCmd = InputCmd.from_array(data)
	var queue: Array = entry["queue"]
	if cmd == null or cmd.seq <= int(entry["queued_seq"]) or queue.size() >= Protocol.MAX_QUEUE:
		stats["rejected_inputs"] += 1
		return
	entry["queued_seq"] = cmd.seq
	queue.append(cmd)


func _tick_server(delta: float) -> void:
	for id: int in _peers:
		var entry: Dictionary = _peers[id]
		var player = entry["player"]
		if not player.alive:
			entry["respawn"] = float(entry["respawn"]) - delta
			if float(entry["respawn"]) <= 0.0:
				_respawn(entry)
		# 입력이 도착한 만큼만 시뮬레이션한다. 그래야 서버 상태가 항상 "last_seq까지 적용한 결과"가 되어
		# 클라이언트가 자기 예측과 정확히 비교할 수 있다. 밀렸으면 한 틱에 두 개까지 따라잡는다.
		var queue: Array = entry["queue"]
		var steps := 2 if queue.size() > 2 else 1
		for step in steps:
			if queue.is_empty():
				break
			var cmd: InputCmd = queue.pop_front()
			entry["last_seq"] = cmd.seq
			_shot_view_tick = cmd.view_tick
			player.simulate(cmd, delta)
		var history: Array = entry["history"]
		history.append([_tick, player.global_position, player.is_low()])
		if history.size() > HISTORY_SIZE:
			history.pop_front()
	if _tick % Protocol.SNAPSHOT_INTERVAL == 0:
		_send_snapshots()


func _respawn(entry: Dictionary) -> void:
	var player = entry["player"]
	_place_at_spawn(player, int(entry["spawn"]))
	player.health = Protocol.MAX_HEALTH
	player.alive = true
	player.move_state = 0
	player.crouching = false
	player.weapon.reset()
	(entry["history"] as Array).clear()


func _send_snapshots() -> void:
	var rows: Array = []
	for id: int in _peers:
		var player = _peers[id]["player"]
		var flags := 0
		if player.is_low():
			flags |= Protocol.FLAG_LOW
		if player.alive:
			flags |= Protocol.FLAG_ALIVE
		rows.append([id, player.global_position, player.rotation.y, flags])
	for id: int in _peers:
		var entry: Dictionary = _peers[id]
		var player = entry["player"]
		var others := rows.filter(func(row: Array) -> bool: return int(row[0]) != id)
		var status := [
			player.health, player.alive, player.weapon.state.ammo, entry["kills"], entry["deaths"],
		]
		_rpc_snapshot.rpc_id(id, _tick, entry["last_seq"], player.capture_state(), status, others)


## 서버 판정. 쏜 사람이 화면에서 보던 시점(view_tick)으로 상대 위치를 되감아 맞았는지 계산한다.
## 되감는 양에는 상한을 두어, 지연이 큰 사용자가 한참 전 위치를 맞히지 못하게 한다.
func _server_resolve_shot(origin: Vector3, direction: Vector3, shooter_id: int) -> void:
	if not _peers.has(shooter_id):
		return
	stats["server_shots"] += 1
	var shooter_entry: Dictionary = _peers[shooter_id]
	var shooter = shooter_entry["player"]
	var reach: float = shooter.weapon.data.max_range
	var wall: Dictionary = shooter.weapon.world_ray(origin, direction, 1)
	if not wall.is_empty():
		reach = origin.distance_to(wall["position"])

	var oldest := float(_tick - Protocol.MAX_REWIND_TICKS)
	var rewind_tick := clampf(_shot_view_tick, oldest, float(_tick))
	if not _lag_comp:
		rewind_tick = float(_tick)

	var best_id := 0
	var best_distance := reach
	var best_headshot := false
	for id: int in _peers:
		if id == shooter_id or not _peers[id]["player"].alive:
			continue
		var past := _history_at(_peers[id]["history"], rewind_tick)
		if past.is_empty():
			continue
		var hit := HitMath.player_hit(origin, direction, past[0], past[1])
		var distance: float = hit[0]
		if distance >= 0.0 and distance < best_distance:
			best_id = id
			best_distance = distance
			best_headshot = hit[1]
	if best_id == 0:
		return

	stats["server_hits"] += 1
	var target_entry: Dictionary = _peers[best_id]
	var target = target_entry["player"]
	var amount: float = WeaponState.damage_at(shooter.weapon.data, best_distance, best_headshot)
	target.health = maxf(target.health - amount, 0.0)
	var killed: bool = target.health <= 0.0
	if killed:
		target.alive = false
		target_entry["respawn"] = Protocol.RESPAWN_TIME
		target_entry["deaths"] = int(target_entry["deaths"]) + 1
		shooter_entry["kills"] = int(shooter_entry["kills"]) + 1
	_rpc_hit.rpc_id(shooter_id, best_headshot, killed)


## 기록에서 특정 틱의 [위치, low]를 보간해 구한다. 기록이 없으면 빈 배열.
func _history_at(history: Array, tick: float) -> Array:
	if history.is_empty():
		return []
	var newer: Array = history.back()
	var older: Array = history.front()
	for index in range(history.size() - 1, -1, -1):
		var entry: Array = history[index]
		if float(entry[0]) <= tick:
			older = entry
			newer = history[mini(index + 1, history.size() - 1)]
			break
		newer = entry
	var span := float(newer[0]) - float(older[0])
	var weight := 0.0
	if span > 0.0:
		weight = clampf((tick - float(older[0])) / span, 0.0, 1.0)
	var from: Vector3 = older[1]
	var to: Vector3 = newer[1]
	return [from.lerp(to, weight), older[2]]


# ---------------------------------------------------------------- 클라이언트


func _start_client(address: String) -> void:
	var peer := WebSocketMultiplayerPeer.new()
	# https 페이지에서는 브라우저가 wss://만 허용하므로 전체 주소도 받는다.
	var url := address if address.contains("://") else "ws://" + address
	var error := peer.create_client(url)
	if error != OK:
		printerr("could not start connecting to %s (error %d)" % [address, error])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_lost.bind("connection failed"))
	multiplayer.server_disconnected.connect(_on_connection_lost.bind("server closed the connection"))
	mode = Mode.CLIENT
	print("connecting to %s" % address)


func _on_connected() -> void:
	stats["connected"] = true
	_local = _spawn_player(true, 0)
	_local.weapon.resolve_shot = _client_resolve_shot
	print("connected as peer %d" % multiplayer.get_unique_id())


func _on_connection_lost(reason: String) -> void:
	printerr("network: %s" % reason)
	if _exit_after > 0.0:
		_finish()


func _client_resolve_shot(origin: Vector3, direction: Vector3) -> void:
	stats["shots"] += 1
	_local.weapon.resolve_visual_only(origin, direction)


func _tick_client(delta: float) -> void:
	# 인위적 지연이 있으면 정해진 틱이 될 때까지 송수신을 미룬다.
	while not _in_queue.is_empty() and int(_in_queue[0][0]) <= _tick:
		var packet: Array = _in_queue.pop_front()
		_apply_snapshot(packet[1], packet[2], packet[3], packet[4], packet[5], delta)
	if _local == null:
		return
	_advance_render_tick()

	var cmd := _next_local_cmd(delta)
	_seq += 1
	cmd.seq = _seq
	cmd.view_tick = _render_tick
	_local.simulate(cmd, delta)
	_pending.append([_seq, cmd, _local.capture_state()])
	if _pending.size() > PENDING_LIMIT:
		_pending.pop_front()

	_out_queue.append([_tick + _delay_ticks, cmd.to_array()])
	while not _out_queue.is_empty() and int(_out_queue[0][0]) <= _tick:
		var outgoing: Array = _out_queue.pop_front()
		_rpc_input.rpc_id(1, outgoing[1])


## 다른 플레이어를 그릴 시점을 "최신 스냅샷보다 INTERP_TICKS 과거"로 부드럽게 맞춘다.
func _advance_render_tick() -> void:
	if _latest_tick < 0:
		return
	var target := float(_latest_tick - Protocol.INTERP_TICKS)
	_render_tick += 1.0
	var drift := target - _render_tick
	if absf(drift) > 6.0:
		_render_tick = target
	else:
		_render_tick += drift * 0.1


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_snapshot(tick: int, last_seq: int, own: Array, status: Array, others: Array) -> void:
	if mode != Mode.CLIENT:
		return
	_in_queue.append([_tick + _delay_ticks, tick, last_seq, own, status, others])


@rpc("authority", "call_remote", "reliable")
func _rpc_hit(headshot: bool, killed: bool) -> void:
	if mode != Mode.CLIENT or _local == null:
		return
	stats["hits"] += 1
	if killed:
		stats["kills"] += 1
	_local.show_hit(headshot, killed)


func _apply_snapshot(
	tick: int, last_seq: int, own: Array, status: Array, others: Array, delta: float
) -> void:
	stats["snapshots"] += 1
	_latest_tick = maxi(_latest_tick, tick)

	var seen := {}
	for row: Array in others:
		var id: int = row[0]
		seen[id] = true
		if not _avatars.has(id):
			var created := RemoteAvatar.new()
			add_child(created)
			_avatars[id] = created
		var avatar: RemoteAvatar = _avatars[id]
		var flags: int = row[3]
		var is_low := (flags & Protocol.FLAG_LOW) != 0
		var is_alive := (flags & Protocol.FLAG_ALIVE) != 0
		avatar.push(tick, row[1], row[2], is_low, is_alive)
	for id: int in _avatars.keys():
		if not seen.has(id):
			_avatars[id].queue_free()
			_avatars.erase(id)

	if _local == null:
		return
	_local.apply_net_status(float(status[0]), bool(status[1]), int(status[2]))
	if _local.hud != null:
		_local.hud.set_score("K %d  D %d" % [int(status[3]), int(status[4])])
	_reconcile(last_seq, own, delta)


## 서버가 last_seq까지 적용한 결과(own)를 그 시점의 내 예측과 비교한다.
## 다르면 서버 상태로 되돌리고, 그 뒤에 보낸 입력을 다시 돌려 현재 상태를 새로 계산한다.
func _reconcile(last_seq: int, own: Array, delta: float) -> void:
	while not _pending.is_empty() and int(_pending[0][0]) < last_seq:
		_pending.pop_front()
	if _pending.is_empty() or int(_pending[0][0]) != last_seq:
		# 비교할 예측이 없으면(접속 직후) 서버 상태를 그대로 따른다.
		if last_seq == 0:
			_local.restore_state(own)
		return
	var predicted: Array = _pending[0][2]
	var predicted_position: Vector3 = predicted[0]
	var server_position: Vector3 = own[0]
	var error := predicted_position.distance_to(server_position)
	stats["max_error"] = maxf(stats["max_error"], error)
	if error <= Protocol.RECONCILE_TOLERANCE and int(predicted[2]) == int(own[2]):
		return
	stats["corrections"] += 1
	_local.restore_state(own)
	for index in range(1, _pending.size()):
		_local.simulate(_pending[index][1], delta, true)
		_pending[index][2] = _local.capture_state()


# ---------------------------------------------------------------- 종료와 검증


## 통계를 출력하고, --expect 조건을 검사해 종료 코드로 결과를 알린다.
func _finish() -> void:
	_exit_after = 0.0
	if _remote_max_x > _remote_min_x:
		stats["remote_travel"] = _remote_max_x - _remote_min_x
	var failures := PackedStringArray()
	if mode == Mode.CLIENT:
		if not stats["connected"]:
			failures.append("never connected")
		if int(stats["snapshots"]) < 30:
			failures.append("received only %d snapshots" % int(stats["snapshots"]))
	if _args.has("expect-players"):
		var wanted := int(_args["expect-players"])
		if int(stats["peak_players"]) < wanted:
			failures.append("expected %d players, saw %d" % [wanted, int(stats["peak_players"])])
	if _args.has("max-corrections"):
		var allowed := int(_args["max-corrections"])
		if int(stats["corrections"]) > allowed:
			failures.append("%d prediction corrections (limit %d)" % [stats["corrections"], allowed])
	if _args.has("expect-hit-ratio"):
		var wanted_ratio := float(_args["expect-hit-ratio"])
		var shots := int(stats["shots"])
		var ratio := float(stats["hits"]) / maxf(float(shots), 1.0)
		if shots < 10 or ratio < wanted_ratio:
			failures.append("hit ratio %.2f over %d shots (wanted %.2f)" % [ratio, shots, wanted_ratio])
	if _args.has("max-hit-ratio"):
		var limit := float(_args["max-hit-ratio"])
		var ratio := float(stats["hits"]) / maxf(float(stats["shots"]), 1.0)
		if ratio > limit:
			failures.append("hit ratio %.2f is above %.2f" % [ratio, limit])
	if _args.has("expect-remote-moving") and float(stats["remote_travel"]) < 2.0:
		failures.append("remote player moved only %.2f m on screen" % float(stats["remote_travel"]))

	var role := "offline"
	if mode == Mode.SERVER:
		role = "server"
	elif mode == Mode.CLIENT:
		role = "client:%s" % str(_args.get("bot", "human"))
	print("NETSTATS %s %s" % [role, JSON.stringify(stats)])
	for failure in failures:
		printerr("NETTEST FAIL %s: %s" % [role, failure])
	print("NETTEST %s %s" % [role, "ok" if failures.is_empty() else "failed"])
	get_tree().quit(0 if failures.is_empty() else 1)
