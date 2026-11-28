extends RefCounted
## 경기 정보를 화면에 그리는 부분(점수판, 거점 표시, 킬 로그, 팀 색).
## 경기 진행(game_session.gd)과 분리해, 로컬 대전과 네트워크 클라이언트가 함께 쓴다.

const ZoneMarker := preload("res://game/match/zone_marker.gd")
const RemoteAvatar := preload("res://game/player/remote_avatar.gd")
const Protocol := preload("res://game/net/net_protocol.gd")
const XpTracker := preload("res://game/match/xp_tracker.gd")
const Announcer := preload("res://game/audio/announcer.gd")
const Domination := preload("res://game/match/domination.gd")
const UiStyle := preload("res://game/ui/ui_style.gd")
## 팀 데스매치 목표 점수. game_session.gd의 SCORE_LIMIT와 같아야 한다(테스트가 확인한다).
const TDM_SCORE_LIMIT := 30
## 판이 막 시작한 것으로 보는 남은 시간(초). 판 길이는 game_session.gd의 MATCH_TIME(300초).
const FRESH_MATCH_TIME := 295.0
## 이 시간(초)이 남았을 때 "1분 남았다"고 알린다.
const LAST_MINUTE := 60.0
const ALLY_COLOR := Color(0.25, 0.45, 0.9)
const ENEMY_COLOR := Color(0.85, 0.25, 0.2)
const NEUTRAL_COLOR := Color(0.75, 0.75, 0.75)

## 화면 주인의 팀. 색은 항상 이 팀을 기준으로 아군은 파랑, 적군은 빨강이다.
var own_team := 0
## 화면 주인의 경험치. 사람이 하는 경기에서만 있다(테스트 봇, 연습장, 서버는 null).
var xp: XpTracker
## 참가자 이름(id -> 이름). 점수판 줄에서 배운다.
var names := {}
## 아나운서. 사람이 화면을 보는 경기에서만 있다.
var announcer: Announcer

var _markers: Array = []
## 나를 마지막으로 죽인 사람. 리스폰을 기다리는 동안 보여 준다.
var _killed_by := ""
## 지난번에 본 판 상태(아나운서가 바뀐 순간을 알아채는 데 쓴다). 남은 시간이 음수면 아직 못 봤다.
var _was_over := false
var _last_time := -1.0
var _zone_owners: Array = []
## 점령전인지(거점 상태를 한 번이라도 받았으면).
var _domination := false


func relative_color(team: int) -> Color:
	if team < 0:
		return NEUTRAL_COLOR
	return ALLY_COLOR if team == own_team else ENEMY_COLOR


## HUD 글자와 막대에 쓰는 팀 색(어두운 배경에서 잘 읽히는 밝은 색).
func hud_color(team: int) -> Color:
	if team < 0:
		return UiStyle.NEUTRAL
	return UiStyle.ALLY if team == own_team else UiStyle.ENEMY


## 킬 알림에 쓰는 이름. 나는 YOU, 모르는 사람은 번호.
func name_of(id: int, own_id: int) -> String:
	if id == own_id:
		return "YOU"
	if names.has(id):
		return str(names[id])
	if id >= 1000:
		return "BOT-%d" % (id - 999)
	return "P-%d" % (id % 1000)


## 점수판 줄([id, 팀, 킬, 데스, 봇 여부, 이름])에서 이름을 배운다.
func learn_names(rows: Array) -> void:
	for row: Array in rows:
		if row.size() > 5:
			names[int(row[0])] = str(row[5])


## 거점 표시와 HUD를 갱신한다. zones는 맵의 거점 목록([이름, 중심]),
## states의 각 항목은 [소유 팀, 진행도, 점령 중인 팀]. hud는 없을 수 있다.
## 판의 흐름에 맞춰 아나운서에게 말을 시킨다: 시작, 1분 남음, 결과.
func _announce(over: bool, time_left: float, own: int, other: int) -> void:
	var first := _last_time < 0.0
	if not over and (first or _was_over) and time_left >= FRESH_MATCH_TIME:
		announcer.announce("start")
	elif not over and _last_time > LAST_MINUTE and time_left <= LAST_MINUTE:
		announcer.announce("one_minute")
	if over and not _was_over and not first:
		var result := "draw"
		if own != other:
			result = "victory" if own > other else "defeat"
		announcer.announce(result)


## 거점의 주인이 바뀌면 알린다. 판이 막 시작했거나 끝났을 때(초기화)는 말하지 않는다.
func _announce_zones(states: Array) -> void:
	announcer.domination = true
	var owners: Array = states.map(func(row: Array) -> int: return int(row[0]))
	var settled := not _was_over and _last_time >= 0.0 and _last_time < FRESH_MATCH_TIME
	if settled and owners.size() == _zone_owners.size():
		for index in owners.size():
			if owners[index] == _zone_owners[index]:
				continue
			if int(owners[index]) == own_team:
				announcer.announce("zone_taken")
			elif int(_zone_owners[index]) == own_team:
				announcer.announce("zone_lost")
	_zone_owners = owners


## 맵이 바뀌면 거점 표시를 지운다. 다음 show_zones가 새 맵의 거점으로 다시 만든다.
func clear_zones() -> void:
	_zone_owners.clear()
	for marker: Node in _markers:
		marker.queue_free()
	_markers.clear()


func show_zones(parent: Node, hud, zones: Array, states: Array) -> void:
	if states.is_empty():
		return
	_domination = true
	if announcer != null:
		_announce_zones(states)
	while _markers.size() < zones.size():
		var zone: Array = zones[_markers.size()]
		var marker := ZoneMarker.new(str(zone[0]))
		marker.position = zone[1]
		parent.add_child(marker)
		_markers.append(marker)
	var items: Array = []
	for index in states.size():
		var row: Array = states[index]
		var color := relative_color(int(row[0]))
		if float(row[1]) > 0.0:
			_markers[index].set_state(relative_color(int(row[2])), float(row[1]))
		else:
			_markers[index].set_state(color, 0.0)
		var owner := int(row[0])
		items.append([str(zones[index][0]), hud_color(owner), owner >= 0,
			hud_color(int(row[2])), float(row[1])])
	if hud != null:
		hud.set_zones(items)


func show_kill(
	hud, killer: int, victim: int, killer_team: int, headshot: bool, own_id: int
) -> void:
	if xp != null and killer == own_id and victim != own_id:
		xp.on_kill(headshot)
	if victim == own_id:
		_killed_by = "" if killer == own_id else name_of(killer, own_id)
	if hud == null:
		return
	# 아군 사격이 없으니 죽은 쪽은 상대 팀이다(자폭은 같은 팀).
	var victim_team := killer_team if killer == victim else 1 - killer_team
	hud.add_kill(
		name_of(killer, own_id), hud_color(killer_team), name_of(victim, own_id),
		hud_color(victim_team), headshot, killer == own_id or victim == own_id
	)


## 점수판과 가운데 안내 문구. status는 [팀, 0팀 점수, 1팀 점수, 남은 시간, 종료 여부, 킬, 데스, 생존].
func show_match(hud, status: Array) -> void:
	var team: int = status[0]
	var score_a: int = status[1]
	var score_b: int = status[2]
	var own := score_a if team == 0 else score_b
	var other := score_b if team == 0 else score_a
	# 경험치와 아나운서는 화면이 없어도(테스트) 판의 흐름을 따라간다.
	if xp != null:
		xp.on_match_state(bool(status[4]), own, other)
	if announcer != null:
		_announce(bool(status[4]), float(status[3]), own, other)
	_was_over = bool(status[4])
	_last_time = float(status[3])
	if hud == null:
		return
	var seconds := int(ceilf(float(status[3])))
	var limit := Domination.SCORE_LIMIT if _domination else TDM_SCORE_LIMIT
	var title := "DOMINATION" if _domination else "TEAM DEATHMATCH"
	hud.set_match_score(own, other, seconds, limit, "%s  ·  FIRST TO %d" % [title, limit])
	if bool(status[4]):
		var outcome := "draw"
		if own != other:
			outcome = "victory" if own > other else "defeat"
		hud.set_result(outcome, own, other, xp.summary() if xp != null else "")
	else:
		hud.set_result("", 0, 0, "")
	hud.set_death(not bool(status[4]) and not bool(status[7]), _killed_by)


## 점수판. rows는 [id, 팀, 킬, 데스, 봇 여부, 이름]. 죽었거나 판이 끝났을 때(force), 또는 Tab을 누르는 동안 보인다.
func show_scores(hud: Node, rows: Array, own_id: int, force: bool) -> void:
	learn_names(rows)
	var shown := force or Input.is_action_pressed("scoreboard")
	var lines: Array = []
	if shown:
		for row: Array in rows:
			var id := int(row[0])
			var player_name := str(names.get(id, name_of(id, -1)))
			lines.append([int(row[1]), player_name, int(row[2]), int(row[3]), id == own_id,
				bool(row[4])])
	hud.set_scoreboard(shown, lines, own_team)


## 서버 스냅샷의 다른 참가자 줄로 아바타를 만들고, 움직이고, 떠난 사람은 지운다.
## avatars는 id -> RemoteAvatar 사전이고 이 함수가 내용을 바꾼다.
func update_avatars(parent: Node, avatars: Dictionary, tick: int, others: Array) -> void:
	var seen := {}
	for row: Array in others:
		var id: int = row[0]
		seen[id] = true
		if not avatars.has(id):
			var created := RemoteAvatar.new()
			parent.add_child(created)
			avatars[id] = created
		var avatar: RemoteAvatar = avatars[id]
		var flags: int = row[3]
		var is_low := (flags & Protocol.FLAG_LOW) != 0
		var is_alive := (flags & Protocol.FLAG_ALIVE) != 0
		avatar.push(tick, row[1], row[2], is_low, is_alive)
		avatar.set_color(relative_color(int(row[4])))
		avatar.set_meta("team", int(row[4]))
		avatar.set_tag(str(names.get(id, "")), int(row[4]) == own_team)
		avatar.set_weapon((flags >> Protocol.SLOT_SHIFT) & Protocol.SLOT_MASK)
		if (flags & Protocol.FLAG_FIRED) != 0:
			avatar.play_shot()
	for id: int in avatars.keys():
		if not seen.has(id):
			avatars[id].queue_free()
			avatars.erase(id)
