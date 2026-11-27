extends Node
## 게임 한 판(팀 데스매치)을 진행한다. 실행 방식은 네 가지다.
## - LOCAL_MATCH: 서버 없이 봇과 대전한다(기본값). 서버와 같은 판정 코드를 한 프로세스에서 돌린다.
## - RANGE: 혼자 사격장에서 더미를 쏜다(--range).
## - SERVER: 권위 서버. 클라이언트 입력으로 플레이어를 움직이고, 판정하고, 스냅샷을 보낸다.
## - CLIENT: 자기 플레이어를 먼저 움직여 보이고(예측) 서버 결과와 다르면 되돌려 다시 계산한다(보정).
##   다른 플레이어는 조금 과거 시점으로 보간해 그린다.
##
## 서버는 탄 판정 때 쏜 사람이 화면에서 보던 시점으로 상대 위치를 되감는다(지연 보상).
##
## 명령줄 인자(godot ... -- 뒤에 붙인다):
##   --range                     사격 연습장
##   --mode=tdm|dom              경기 방식: 팀 데스매치(기본) 또는 점령전
##   --difficulty=easy|normal|hard 봇 난이도
##   --bots=5                    봇 수(로컬 대전 기본 5, 서버 기본 0)
##   --spectate                  로컬 대전을 사람 없이 봇끼리만 진행(자동 테스트)
##   --server --port=7777        서버로 실행
##   --connect=127.0.0.1:7777    서버에 접속 (wss://host/path 형식도 가능, 웹은 주소창에 ?connect=...)
##   --map=res://...tscn         맵 지정
##   --bot=strafer|shooter|runner 사람 대신 봇이 조작(자동 테스트)
##   --net-delay-ms=50           클라이언트 송수신에 인위적 지연 추가(자동 테스트)
##   --no-lagcomp                지연 보상 끄기(비교 테스트)
##   --exit-after=10             N초 뒤 통계를 출력하고 종료
##   --expect-...                종료 시 검증할 조건(자동 테스트)

enum Mode { RANGE, LOCAL_MATCH, SERVER, CLIENT }

const Protocol := preload("res://game/net/net_protocol.gd")
const InputCmd := preload("res://game/player/input_cmd.gd")
const HitMath := preload("res://game/combat/hit_math.gd")
const WeaponState := preload("res://game/weapons/weapon_state.gd")
const RemoteAvatar := preload("res://game/player/remote_avatar.gd")
const ScriptBot := preload("res://game/bots/script_bot.gd")
const CombatBot := preload("res://game/bots/combat_bot.gd")
const Domination := preload("res://game/match/domination.gd")
const ZoneMarker := preload("res://game/match/zone_marker.gd")
const Settings := preload("res://game/core/settings.gd")
const SessionReport := preload("res://game/net/session_report.gd")
const MainMenu := preload("res://game/ui/main_menu.gd")
const PauseMenu := preload("res://game/ui/pause_menu.gd")
## 이 인자가 하나라도 있으면 메뉴 없이 바로 시작한다(서버, 자동 테스트, 웹 주소창 접속).
const DIRECT_START_ARGS := ["server", "connect", "range", "spectate", "bots", "bot", "exit-after"]
const PLAYER_SCENE := preload("res://game/player/player.tscn")
const NavGraph := preload("res://game/bots/nav_graph.gd")
const DEFAULT_MAP := "res://maps/depot/depot.tscn"
const RANGE_MAP := "res://maps/graybox/graybox.tscn"
const HISTORY_SIZE := 64
const PENDING_LIMIT := 240
const SCORE_LIMIT := 30
const MATCH_TIME := 300.0
const INTERMISSION_TIME := 8.0
const LOCAL_ID := 1
const BOT_SIGHT_RANGE := 60.0
const BOT_NEAR_RANGE := 10.0
const MatchView := preload("res://game/net/match_view.gd")
const Vitals := preload("res://game/match/vitals.gd")
const SpawnPicker := preload("res://game/match/spawn_picker.gd")

var mode := Mode.LOCAL_MATCH
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
	"total_kills": 0,
	"matches_finished": 0,
	"zone_captures": 0,
}

var _args := {}
var _started := false
var _menu: MainMenu
var _pause: PauseMenu
var _map: Node
var _tick := 0
var _elapsed := 0.0
var _exit_after := 0.0
var _bot: ScriptBot
var _local = null
var _lag_comp := true
# 판정 권한이 있는 쪽(서버, 로컬 대전)의 참가자 목록.
# id -> {kind("peer"|"bot"|"local"), player, team, bot, avatar, queue, last_seq, queued_seq,
#        history, respawn, kills, deaths}
var _peers := {}
var _shot_view_tick := 0.0
var _team_scores := [0, 0]
var _time_left := MATCH_TIME
var _intermission_left := 0.0
var _nav_points: Array = []
var _navigator: NavGraph
var _last_local_health := Protocol.MAX_HEALTH
## 점령전일 때만 있다. 판정 권한이 있는 쪽이 갱신한다.
var _domination: Domination
var _view := MatchView.new()
var _difficulty := "normal"
var _capture_check_left := 0.0
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
	get_tree().root.content_scale_factor = Settings.ui_scale()
	_parse_args()
	_exit_after = float(_args.get("exit-after", "0"))
	_lag_comp = not _args.has("no-lagcomp")
	_delay_ticks = int(round(float(_args.get("net-delay-ms", "0")) * Protocol.TICK_RATE / 1000.0))
	if _args.has("bot"):
		_bot = ScriptBot.new(str(_args["bot"]))
	_load_map(str(_args.get("map", RANGE_MAP if _args.has("range") else DEFAULT_MAP)))

	var direct := OS.has_feature("dedicated_server")
	for key: String in DIRECT_START_ARGS:
		direct = direct or _args.has(key)
	if direct:
		_start_from_args()
	else:
		_menu = MainMenu.new()
		_menu.start_requested.connect(_on_start_requested)
		add_child(_menu)


func _load_map(path: String) -> void:
	if _map != null:
		remove_child(_map)
		_map.queue_free()
	_map = load(path).instantiate()
	add_child(_map)
	_nav_points = _map.call("nav_points")
	_navigator = null
	if _map.has_method("nav_graph"):
		_navigator = NavGraph.new(_map.call("nav_graph"))


func is_started() -> bool:
	return _started


func local_player():
	return _local


func participant_count() -> int:
	return _peers.size()


func menu() -> MainMenu:
	return _menu


func pause_menu() -> PauseMenu:
	return _pause


func _start_from_args() -> void:
	_started = true
	_difficulty = str(_args.get("difficulty", "normal"))
	_set_game_mode(str(_args.get("mode", "tdm")))
	if _args.has("server") or OS.has_feature("dedicated_server"):
		_start_server(int(_args.get("port", str(Protocol.DEFAULT_PORT))))
		_add_bots(int(_args.get("bots", "0")))
	elif _args.has("connect"):
		_start_client(str(_args["connect"]))
	elif _args.has("range"):
		mode = Mode.RANGE
		if _map.has_method("spawn_offline_targets"):
			_map.call("spawn_offline_targets")
		_local = _spawn_player(true, 0)
	else:
		mode = Mode.LOCAL_MATCH
		if not _args.has("spectate"):
			_local = _add_participant(LOCAL_ID, "local")["player"]
		_add_bots(int(_args.get("bots", "5")))


func _on_start_requested(kind: String, options: Dictionary) -> void:
	_menu.queue_free()
	_menu = null
	_started = true
	match kind:
		"join":
			_start_client(str(options["address"]))
		"range":
			mode = Mode.RANGE
			_load_map(RANGE_MAP)
			if _map.has_method("spawn_offline_targets"):
				_map.call("spawn_offline_targets")
			_local = _spawn_player(true, 0)
		_:
			mode = Mode.LOCAL_MATCH
			_difficulty = str(options.get("difficulty", Settings.difficulty()))
			_set_game_mode(str(options.get("mode", "tdm")))
			_local = _add_participant(LOCAL_ID, "local")["player"]
			_add_bots(int(options.get("bots", 5)))
	_apply_quality()
	_pause = PauseMenu.new()
	_pause.visible = false
	_pause.resume_requested.connect(_resume)
	_pause.menu_requested.connect(_return_to_menu)
	_pause.sensitivity_changed.connect(_on_sensitivity_changed)
	_pause.touch_toggled.connect(_on_touch_toggled)
	add_child(_pause)


## 점령전은 맵에 거점이 있을 때만 켠다. 없으면 팀 데스매치로 진행한다.
func _set_game_mode(game_mode: String) -> void:
	if game_mode != "dom" or not _map.has_method("capture_zones"):
		return
	_domination = Domination.new(_map.call("capture_zones"))


func _score_limit() -> int:
	return Domination.SCORE_LIMIT if _domination != null else SCORE_LIMIT


func _apply_quality() -> void:
	Settings.apply_quality(_map, get_viewport())


## 터치 조작의 조준 보조에 쓸, 지금 보이는 적들의 가슴 위치.
func _update_assist_targets() -> void:
	var targets: Array = []
	var eye: Vector3 = _local.eye_position()
	var candidates: Array = []
	if mode == Mode.CLIENT:
		for id: int in _avatars:
			var avatar: RemoteAvatar = _avatars[id]
			if avatar.alive and int(avatar.get_meta("team", -1)) != _view.own_team:
				candidates.append([avatar.position, avatar.low])
	else:
		for id: int in _peers:
			var other = _peers[id]["player"]
			if int(_peers[id]["team"]) != _view.own_team and other.alive:
				candidates.append([other.global_position, other.is_low()])
	for candidate: Array in candidates:
		var chest: Vector3 = candidate[0] + Vector3.UP * (0.7 if candidate[1] else 1.1)
		var offset := chest - eye
		var wall: Dictionary = _local.weapon.world_ray(eye, offset.normalized(), 1)
		if wall.is_empty() or eye.distance_to(wall["position"]) >= offset.length():
			targets.append(chest)
	_local.assist_targets = targets


func _resume() -> void:
	if _local != null and _local.touch != null:
		_local.set_paused(false)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_capture_check_left = 0.4


func _on_touch_toggled(enabled: bool) -> void:
	if _local == null:
		return
	if enabled:
		_local.set_touch(true)
		_local.set_paused(true)
	else:
		_local.set_touch(false)


## 계속하기를 눌렀는데도 포인터 잠금이 되지 않고 터치 화면이 있으면, 휴대폰으로 보고 터치 조작을 켠다.
## 기기 판단이 틀렸을 때 일시 정지 화면에 갇히지 않게 하는 안전장치다.
func _check_capture_fallback(delta: float) -> void:
	if _capture_check_left <= 0.0:
		return
	_capture_check_left -= delta
	if _capture_check_left > 0.0 or _local == null or _local.touch != null:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not captured and DisplayServer.is_touchscreen_available():
		_local.set_touch(true)
		_local.set_paused(false)


func _on_sensitivity_changed(value: float) -> void:
	if _local != null:
		_local.set_sensitivity(value)


func _return_to_menu() -> void:
	multiplayer.multiplayer_peer = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if not _started:
		return
	# 혼자 하는 봇 대전은 일시 정지하면 실제로 멈춘다. 네트워크 대전은 멈출 수 없다.
	if mode == Mode.LOCAL_MATCH and _pause != null and _pause.visible:
		return
	_tick += 1
	_elapsed += delta
	match mode:
		Mode.SERVER, Mode.LOCAL_MATCH:
			_tick_authority(delta)
		Mode.CLIENT:
			_tick_client(delta)
		_:
			if _local != null:
				_local.simulate(_next_local_cmd(delta), delta)
	if _local != null and _local.touch != null:
		_update_assist_targets()
	if _exit_after > 0.0 and _elapsed >= _exit_after:
		_finish()


func _process(delta: float) -> void:
	_check_capture_fallback(delta)
	if _pause != null:
		# 접속이 끝나기 전(_local 없음)에도 메뉴로 돌아갈 수 있게 보여 준다.
		_pause.visible = _local == null or not _local.input_active()
	if not _started or mode != Mode.CLIENT:
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
	_add_participant(id, "peer")
	print("peer %d joined (%d players)" % [id, _peers.size()])


func _on_peer_disconnected(id: int) -> void:
	if not _peers.has(id):
		return
	_peers[id]["player"].queue_free()
	_peers.erase(id)
	print("peer %d left (%d players)" % [id, _peers.size()])


func _add_bots(count: int) -> void:
	for index in count:
		var id := 1000 + index
		var entry := _add_participant(id, "bot")
		var bot := CombatBot.new(id * 7919, entry["player"].rotation.y)
		# 봇은 소총, 기관단총, 산탄총을 번갈아 든다. 저격총은 봇의 조준 방식과 맞지 않아 뺀다.
		bot.weapon_slot = index % 3
		bot.navigator = _navigator
		bot.set_difficulty(_difficulty)
		entry["bot"] = bot


## 참가자를 만들어 인원이 적은 팀에 넣는다.
func _add_participant(id: int, kind: String) -> Dictionary:
	var counts := [0, 0]
	for other: int in _peers:
		counts[int(_peers[other]["team"])] += 1
	var team := 0 if counts[0] <= counts[1] else 1
	var player = _spawn_player(kind == "local", 0)
	if kind != "local":
		player.view_from_cmd = true
		player.require_mouse_capture = false
	player.weapon.resolve_shot = _resolve_shot.bind(id)
	player.weapon.fired.connect(_on_participant_fired.bind(id))
	var entry := {
		"fired": false,
		"since_damage": 999.0,
		"protected": 0.0,
		"kind": kind,
		"player": player,
		"team": team,
		"bot": null,
		"avatar": null,
		"queue": [],
		"last_seq": 0,
		"queued_seq": 0,
		"history": [],
		"respawn": 0.0,
		"kills": 0,
		"deaths": 0,
	}
	# 같은 프로세스에서 화면에 보여야 하는 다른 참가자에게는 임시 몸체를 붙인다.
	if mode == Mode.LOCAL_MATCH and kind != "local":
		var avatar := RemoteAvatar.new()
		player.add_child(avatar)
		entry["avatar"] = avatar
	_peers[id] = entry
	_place_at_spawn(player, _pick_spawn(team, id))
	_recolor_avatars()
	stats["peak_players"] = maxi(stats["peak_players"], _peers.size())
	return entry


## 참가자가 발사했을 때: 다른 사람에게 총소리를 들려주고, 리스폰 보호를 푼다.
func _on_participant_fired(_kick: Vector2, id: int) -> void:
	if not _peers.has(id):
		return
	var entry: Dictionary = _peers[id]
	entry["fired"] = true
	entry["protected"] = 0.0
	if entry["avatar"] != null:
		entry["avatar"].play_shot()


## 팀 스폰 중 살아 있는 적에게서 가장 먼 곳을 고른다.
func _pick_spawn(team: int, self_id: int) -> int:
	var enemies: Array = []
	for other: int in _peers:
		var entry: Dictionary = _peers[other]
		if other != self_id and int(entry["team"]) != team and entry["player"].alive:
			enemies.append(entry["player"].global_position)
	return SpawnPicker.pick(_map, team, self_id, enemies)


func _recolor_avatars() -> void:
	if _peers.has(LOCAL_ID):
		_view.own_team = int(_peers[LOCAL_ID]["team"])
	for id: int in _peers:
		var avatar: RemoteAvatar = _peers[id]["avatar"]
		if avatar != null:
			avatar.set_color(_view.relative_color(int(_peers[id]["team"])))


## 클라이언트가 보낸 입력을 받는다. 보낸 쪽을 믿지 않고 형식, 순서, 양을 모두 검사한다.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_input(data: Array) -> void:
	if mode != Mode.SERVER:
		return
	var id := multiplayer.get_remote_sender_id()
	if not _peers.has(id) or str(_peers[id]["kind"]) != "peer":
		return
	var entry: Dictionary = _peers[id]
	var cmd: InputCmd = InputCmd.from_array(data)
	var queue: Array = entry["queue"]
	if cmd == null or cmd.seq <= int(entry["queued_seq"]) or queue.size() >= Protocol.MAX_QUEUE:
		stats["rejected_inputs"] += 1
		return
	entry["queued_seq"] = cmd.seq
	queue.append(cmd)


## 판정 권한이 있는 쪽의 한 틱. 서버와 로컬 대전이 함께 쓴다.
func _tick_authority(delta: float) -> void:
	_update_match(delta)
	var frozen := _intermission_left > 0.0
	for id: int in _peers:
		var entry: Dictionary = _peers[id]
		var player = entry["player"]
		if not player.alive and not frozen:
			entry["respawn"] = float(entry["respawn"]) - delta
			if float(entry["respawn"]) <= 0.0:
				_respawn(id, entry)
		entry["since_damage"] = float(entry["since_damage"]) + delta
		entry["protected"] = maxf(float(entry["protected"]) - delta, 0.0)
		player.health = Vitals.regenerate(
			player.health, Protocol.MAX_HEALTH, float(entry["since_damage"]), delta
		)
		match str(entry["kind"]):
			"peer":
				_simulate_peer(entry, delta, frozen)
			"bot":
				_shot_view_tick = float(_tick)
				var cmd := InputCmd.new()
				if not frozen and player.alive:
					cmd = _bot_cmd(id, entry, delta)
				player.simulate(cmd, delta)
			_:
				_shot_view_tick = float(_tick)
				var cmd: InputCmd = player.gather_cmd()
				if frozen:
					cmd.move = Vector2.ZERO
					cmd.buttons = 0
				player.simulate(cmd, delta)
		var history: Array = entry["history"]
		history.append([_tick, player.global_position, player.is_low()])
		if history.size() > HISTORY_SIZE:
			history.pop_front()
		if entry["avatar"] != null:
			entry["avatar"].set_pose(player.is_low(), player.alive)
	if mode == Mode.SERVER and _tick % Protocol.SNAPSHOT_INTERVAL == 0:
		_send_snapshots()
	if mode == Mode.LOCAL_MATCH and _local != null:
		_update_local_hud()


## 입력이 도착한 만큼만 시뮬레이션한다. 그래야 서버 상태가 항상 "last_seq까지 적용한 결과"가 되어
## 클라이언트가 자기 예측과 정확히 비교할 수 있다. 밀렸으면 한 틱에 두 개까지 따라잡는다.
func _simulate_peer(entry: Dictionary, delta: float, frozen: bool) -> void:
	var queue: Array = entry["queue"]
	var steps := 2 if queue.size() > 2 else 1
	for step in steps:
		if queue.is_empty():
			break
		var cmd: InputCmd = queue.pop_front()
		entry["last_seq"] = cmd.seq
		_shot_view_tick = cmd.view_tick
		if frozen:
			cmd.move = Vector2.ZERO
			cmd.buttons = 0
		entry["player"].simulate(cmd, delta)


## 봇에게 보이는 적을 골라 입력을 만든다. 가까운 적은 방향과 무관하게, 먼 적은 시야각 안에서만 본다.
func _bot_cmd(id: int, entry: Dictionary, delta: float) -> InputCmd:
	var player = entry["player"]
	var eye: Vector3 = player.eye_position()
	var forward := Vector3(-sin(player.rotation.y), 0.0, -cos(player.rotation.y))
	var visible: Array = []
	for other: int in _peers:
		var target_entry: Dictionary = _peers[other]
		var target = target_entry["player"]
		if other == id or int(target_entry["team"]) == int(entry["team"]) or not target.alive:
			continue
		var chest: Vector3 = target.global_position + Vector3.UP * 1.0
		var offset := chest - eye
		var distance := offset.length()
		if distance > BOT_SIGHT_RANGE or distance < 0.01:
			continue
		if distance > BOT_NEAR_RANGE and forward.dot(offset / distance) < 0.5:
			continue
		var wall: Dictionary = player.weapon.world_ray(eye, offset / distance, 1)
		if not wall.is_empty() and eye.distance_to(wall["position"]) < distance:
			continue
		visible.append(target.global_position)
	var bot: CombatBot = entry["bot"]
	var goals := _nav_points
	bot.has_hold = false
	if _domination != null:
		var team := int(entry["team"])
		goals = _domination.objectives_for(team, player.global_position)
		var hold := _domination.hold_zone_for(team, player.global_position)
		if hold >= 0:
			bot.has_hold = true
			bot.hold_point = _domination.centers[hold]
	return bot.make_cmd(
		delta, eye, player.global_position, player.horizontal_speed(), visible, goals
	)


## 제한 시간과 점수를 확인해 판을 끝내고, 잠시 뒤 새 판을 시작한다.
func _update_match(delta: float) -> void:
	if _intermission_left > 0.0:
		_intermission_left -= delta
		if _intermission_left <= 0.0:
			_start_new_match()
		return
	_time_left -= delta
	if _domination != null:
		var positions := [[], []]
		for id: int in _peers:
			var player = _peers[id]["player"]
			if player.alive:
				positions[int(_peers[id]["team"])].append(player.global_position)
		_domination.update(delta, positions)
		_team_scores = [int(_domination.scores[0]), int(_domination.scores[1])]
		stats["zone_captures"] = _domination.captures
	var limit_reached: bool = maxi(_team_scores[0], _team_scores[1]) >= _score_limit()
	if _time_left <= 0.0 or limit_reached:
		_time_left = 0.0
		_intermission_left = INTERMISSION_TIME
		stats["matches_finished"] += 1
		print("match over: %d - %d" % [_team_scores[0], _team_scores[1]])


func _start_new_match() -> void:
	_team_scores = [0, 0]
	_time_left = MATCH_TIME
	if _domination != null:
		_domination.reset()
	for id: int in _peers:
		var entry: Dictionary = _peers[id]
		entry["kills"] = 0
		entry["deaths"] = 0
		_respawn(id, entry)


func _respawn(id: int, entry: Dictionary) -> void:
	var player = entry["player"]
	_place_at_spawn(player, _pick_spawn(int(entry["team"]), id))
	player.health = Protocol.MAX_HEALTH
	player.alive = true
	player.move_state = 0
	player.crouching = false
	player.weapon.reset()
	entry["protected"] = Vitals.SPAWN_PROTECTION
	entry["since_damage"] = 999.0
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
		if _peers[id]["fired"]:
			flags |= Protocol.FLAG_FIRED
			_peers[id]["fired"] = false
		rows.append([id, player.global_position, player.rotation.y, flags, _peers[id]["team"]])
	for id: int in _peers:
		var entry: Dictionary = _peers[id]
		if str(entry["kind"]) != "peer":
			continue
		var player = entry["player"]
		var others := rows.filter(func(row: Array) -> bool: return int(row[0]) != id)
		var status := [
			player.health, player.alive, player.weapon.state.ammo, entry["kills"], entry["deaths"],
			entry["team"], _team_scores[0], _team_scores[1], _time_left, _intermission_left > 0.0,
			player.weapon.slot, _domination.state() if _domination != null else [],
		]
		_rpc_snapshot.rpc_id(id, _tick, entry["last_seq"], player.capture_state(), status, others)


## 로컬 대전에서 내 HUD를 갱신한다.
func _update_local_hud() -> void:
	var entry: Dictionary = _peers[LOCAL_ID]
	_view.own_team = int(entry["team"])
	if _domination != null:
		_view.show_zones(self, _local.hud, _map.call("capture_zones"), _domination.state())
	if _local.health < _last_local_health:
		_local.hud.flash_damage()
	_last_local_health = _local.health
	_local.hud.set_health(_local.health, Protocol.MAX_HEALTH)
	_view.show_match(
		_local.hud,
		[
			entry["team"], _team_scores[0], _team_scores[1], _time_left,
			_intermission_left > 0.0, entry["kills"], entry["deaths"], _local.alive,
		]
	)


## 서버 판정. 쏜 사람이 화면에서 보던 시점(view_tick)으로 상대 위치를 되감아 맞았는지 계산한다.
## 되감는 양에는 상한을 두어, 지연이 큰 사용자가 한참 전 위치를 맞히지 못하게 한다.
func _resolve_shot(origin: Vector3, direction: Vector3, shooter_id: int) -> void:
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
		# 같은 팀과 방금 리스폰한 상대는 맞지 않는다.
		if int(_peers[id]["team"]) == int(shooter_entry["team"]):
			continue
		if float(_peers[id]["protected"]) > 0.0:
			continue
		var past: Array = HitMath.history_at(_peers[id]["history"], rewind_tick)
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
	target_entry["since_damage"] = 0.0
	var killed: bool = target.health <= 0.0
	if killed:
		target.alive = false
		target_entry["respawn"] = Protocol.RESPAWN_TIME
		target_entry["deaths"] = int(target_entry["deaths"]) + 1
		shooter_entry["kills"] = int(shooter_entry["kills"]) + 1
		stats["total_kills"] += 1
		if _intermission_left <= 0.0 and _domination == null:
			_team_scores[int(shooter_entry["team"])] += 1
		_announce_kill(shooter_id, best_id, int(shooter_entry["team"]), best_headshot)
	if str(target_entry["kind"]) == "peer":
		_rpc_damaged.rpc_id(best_id, shooter.global_position)
	elif str(target_entry["kind"]) == "local":
		target.show_damage_from(shooter.global_position)
	if str(shooter_entry["kind"]) == "peer":
		_rpc_hit.rpc_id(shooter_id, best_headshot, killed)
	elif str(shooter_entry["kind"]) == "local":
		shooter.show_hit(best_headshot, killed)


func _announce_kill(killer: int, victim: int, killer_team: int, headshot: bool) -> void:
	if mode == Mode.LOCAL_MATCH:
		var hud = _local.hud if _local != null else null
		_view.show_kill(hud, killer, victim, killer_team, headshot, LOCAL_ID)
		return
	for id: int in _peers:
		if str(_peers[id]["kind"]) == "peer":
			_rpc_kill.rpc_id(id, killer, victim, killer_team, headshot)


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


@rpc("authority", "call_remote", "reliable")
func _rpc_damaged(from: Vector3) -> void:
	if mode == Mode.CLIENT and _local != null:
		_local.show_damage_from(from)


@rpc("authority", "call_remote", "reliable")
func _rpc_kill(killer: int, victim: int, killer_team: int, headshot: bool) -> void:
	if mode == Mode.CLIENT and _local != null:
		var own_id := multiplayer.get_unique_id()
		_view.show_kill(_local.hud, killer, victim, killer_team, headshot, own_id)


func _apply_snapshot(
	tick: int, last_seq: int, own: Array, status: Array, others: Array, delta: float
) -> void:
	stats["snapshots"] += 1
	_latest_tick = maxi(_latest_tick, tick)
	_view.own_team = int(status[5])

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
		avatar.set_color(_view.relative_color(int(row[4])))
		avatar.set_meta("team", int(row[4]))
		if (flags & Protocol.FLAG_FIRED) != 0:
			avatar.play_shot()
	for id: int in _avatars.keys():
		if not seen.has(id):
			_avatars[id].queue_free()
			_avatars.erase(id)

	if _local == null:
		return
	_local.apply_net_status(float(status[0]), bool(status[1]), int(status[2]), int(status[10]))
	_view.show_match(
		_local.hud,
		[status[5], status[6], status[7], status[8], status[9], status[3], status[4], status[1]]
	)
	if not (status[11] as Array).is_empty():
		_view.show_zones(self, _local.hud, _map.call("capture_zones"), status[11])
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
	var before: Vector3 = _local.global_position
	_local.restore_state(own)
	for index in range(1, _pending.size()):
		_local.simulate(_pending[index][1], delta, true)
		_pending[index][2] = _local.capture_state()
	_local.add_visual_offset(before - _local.global_position)


# ---------------------------------------------------------------- 종료와 검증


## 통계를 출력하고, --expect 조건을 검사해 종료 코드로 결과를 알린다.
func _finish() -> void:
	_exit_after = 0.0
	if _remote_max_x > _remote_min_x:
		stats["remote_travel"] = _remote_max_x - _remote_min_x
	var role := "local"
	if mode == Mode.SERVER:
		role = "server"
	elif mode == Mode.CLIENT:
		role = "client:%s" % str(_args.get("bot", "human"))
	var failures := SessionReport.check(mode == Mode.CLIENT, _args, stats)
	print("NETSTATS %s %s" % [role, JSON.stringify(stats)])
	for failure in failures:
		printerr("NETTEST FAIL %s: %s" % [role, failure])
	print("NETTEST %s %s" % [role, "ok" if failures.is_empty() else "failed"])
	get_tree().quit(0 if failures.is_empty() else 1)
