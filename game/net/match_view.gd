extends RefCounted
## 경기 정보를 화면에 그리는 부분(점수판, 거점 표시, 킬 로그, 팀 색).
## 경기 진행(game_session.gd)과 분리해, 로컬 대전과 네트워크 클라이언트가 함께 쓴다.

const ZoneMarker := preload("res://game/match/zone_marker.gd")
const TEAM_NAMES := ["BLUE", "RED"]
const ALLY_COLOR := Color(0.25, 0.45, 0.9)
const ENEMY_COLOR := Color(0.85, 0.25, 0.2)
const NEUTRAL_COLOR := Color(0.75, 0.75, 0.75)

## 화면 주인의 팀. 색은 항상 이 팀을 기준으로 아군은 파랑, 적군은 빨강이다.
var own_team := 0

var _markers: Array = []


func relative_color(team: int) -> Color:
	if team < 0:
		return NEUTRAL_COLOR
	return ALLY_COLOR if team == own_team else ENEMY_COLOR


static func name_of(id: int, own_id: int) -> String:
	if id == own_id:
		return "YOU"
	if id >= 1000:
		return "BOT-%d" % (id - 999)
	return "P-%d" % (id % 1000)


## 거점 표시와 HUD를 갱신한다. zones는 맵의 거점 목록([이름, 중심]),
## states의 각 항목은 [소유 팀, 진행도, 점령 중인 팀]. hud는 없을 수 있다.
## 맵이 바뀌면 거점 표시를 지운다. 다음 show_zones가 새 맵의 거점으로 다시 만든다.
func clear_zones() -> void:
	for marker: Node in _markers:
		marker.queue_free()
	_markers.clear()


func show_zones(parent: Node, hud, zones: Array, states: Array) -> void:
	if states.is_empty():
		return
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
		var text := str(zones[index][0])
		if float(row[1]) > 0.0:
			text += " %d%%" % int(float(row[1]) * 100.0)
			_markers[index].set_state(relative_color(int(row[2])), float(row[1]))
		else:
			_markers[index].set_state(color, 0.0)
		items.append([text, color])
	if hud != null:
		hud.set_zones(items)


func show_kill(
	hud, killer: int, victim: int, killer_team: int, headshot: bool, own_id: int
) -> void:
	if hud == null:
		return
	var text := "%s  >  %s" % [name_of(killer, own_id), name_of(victim, own_id)]
	if headshot:
		text += "  (HS)"
	hud.add_feed_line(text, relative_color(killer_team))


## 점수판과 가운데 안내 문구. status는 [팀, 0팀 점수, 1팀 점수, 남은 시간, 종료 여부, 킬, 데스, 생존].
func show_match(hud, status: Array) -> void:
	if hud == null:
		return
	var team: int = status[0]
	var score_a: int = status[1]
	var score_b: int = status[2]
	var seconds := int(ceilf(float(status[3])))
	var clock := "%d:%02d" % [seconds / 60, seconds % 60]
	if hud.is_narrow():
		# 세로로 든 휴대폰: 일시 정지 버튼과 탄약 표시 사이에 들어가도록 내 팀 점수를 앞에 두고 짧게 쓴다.
		var mine := score_a if team == 0 else score_b
		var theirs := score_b if team == 0 else score_a
		hud.set_score("%d - %d   %s" % [mine, theirs, clock])
	else:
		hud.set_score(
			"%s %d  -  %d %s    %s    K %d  D %d  [%s]"
			% [
				TEAM_NAMES[0], score_a, score_b, TEAM_NAMES[1], clock,
				int(status[5]), int(status[6]), TEAM_NAMES[team],
			]
		)
	var message := ""
	if bool(status[4]):
		var own := score_a if team == 0 else score_b
		var other := score_b if team == 0 else score_a
		var title := "DRAW"
		var color := Color(0.9, 0.9, 0.9)
		if own > other:
			title = "VICTORY"
			color = Color(0.45, 0.75, 1.0)
		elif own < other:
			title = "DEFEAT"
			color = Color(1.0, 0.4, 0.35)
		# 개인 킬/데스는 아래 점수판에 나온다.
		var detail := "%s %d  -  %d %s    Next match starting soon" % [
			TEAM_NAMES[0], score_a, score_b, TEAM_NAMES[1],
		]
		hud.set_result(title, color, detail)
	else:
		hud.set_result("", Color.WHITE, "")
		if not bool(status[7]):
			message = "RESPAWNING"
	hud.set_message(message)


## 점수판. rows는 [id, 팀, 킬, 데스, 봇 여부]. 죽었거나 판이 끝났을 때(force), 또는 Tab을 누르는 동안 보인다.
func show_scores(hud: Node, rows: Array, own_id: int, force: bool) -> void:
	var shown := force or Input.is_action_pressed("scoreboard")
	var lines: Array = []
	if shown:
		for row: Array in rows:
			var id := int(row[0])
			var player_name := "YOU" if id == own_id else _name_of(id, bool(row[4]))
			lines.append([int(row[1]), player_name, int(row[2]), int(row[3]), id == own_id])
	hud.set_scoreboard(shown, lines, own_team)


func _name_of(id: int, is_bot: bool) -> String:
	return "BOT %d" % (id % 100) if is_bot else "PLAYER %d" % (id % 1000)
