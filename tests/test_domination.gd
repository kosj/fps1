extends RefCounted

const Domination := preload("res://game/match/domination.gd")
const TICK := 1.0 / 60.0
const ZONES := [["A", Vector3(0.0, 0.0, 0.0)], ["B", Vector3(30.0, 0.0, 0.0)]]
const AT_A := Vector3(1.0, 0.0, 1.0)
const AT_B := Vector3(30.0, 0.0, 2.0)
const NOWHERE := Vector3(15.0, 0.0, 0.0)


func test_zone_lookup_uses_radius_and_height() -> String:
	var match_rules := Domination.new(ZONES)
	if match_rules.zone_at(AT_A) != 0 or match_rules.zone_at(AT_B) != 1:
		return "positions inside zones were not recognised"
	if match_rules.zone_at(NOWHERE) != -1:
		return "a position between zones was placed in a zone"
	if match_rules.zone_at(Vector3(0.0, 8.0, 0.0)) != -1:
		return "a position far above the zone counted as inside"
	return ""


func test_single_player_captures_in_capture_time() -> String:
	var match_rules := Domination.new(ZONES)
	var seconds := _run_until_owned(match_rules, 0, [[AT_A], []], 20.0)
	if absf(seconds - Domination.CAPTURE_TIME) > 0.1:
		return "one player captured in %.2f s, expected %.1f s" % [seconds, Domination.CAPTURE_TIME]
	if int(match_rules.owners[0]) != 0 or int(match_rules.owners[1]) != Domination.NEUTRAL:
		return "wrong owners after capture: %s" % [match_rules.owners]
	return ""


func test_more_players_capture_faster_up_to_double() -> String:
	var pair := Domination.new(ZONES)
	var two := _run_until_owned(pair, 0, [[AT_A, AT_A], []], 20.0)
	var crowd := Domination.new(ZONES)
	var five := _run_until_owned(crowd, 0, [[AT_A, AT_A, AT_A, AT_A, AT_A], []], 20.0)
	if absf(two - Domination.CAPTURE_TIME / 1.5) > 0.1:
		return "two players captured in %.2f s" % two
	if absf(five - Domination.CAPTURE_TIME / 2.0) > 0.1:
		return "five players captured in %.2f s, the speed-up should cap at double" % five
	return ""


func test_contested_zone_does_not_progress() -> String:
	var match_rules := Domination.new(ZONES)
	for tick in 120:
		match_rules.update(TICK, [[AT_A], []])
	var before: float = match_rules.progress[0]
	for tick in 300:
		match_rules.update(TICK, [[AT_A], [AT_A]])
	if absf(float(match_rules.progress[0]) - before) > 0.0001:
		return "progress changed while both teams stood in the zone"
	if int(match_rules.owners[0]) != Domination.NEUTRAL:
		return "a contested zone changed owner"
	return ""


func test_progress_decays_when_zone_is_left() -> String:
	var match_rules := Domination.new(ZONES)
	for tick in 180:
		match_rules.update(TICK, [[AT_A], []])
	for tick in 600:
		match_rules.update(TICK, [[], []])
	if float(match_rules.progress[0]) > 0.0 or int(match_rules.capturing[0]) != Domination.NEUTRAL:
		return "abandoned capture did not decay to nothing"
	return ""


func test_enemy_must_undo_progress_before_capturing() -> String:
	var match_rules := Domination.new(ZONES)
	for tick in 180:
		match_rules.update(TICK, [[AT_A], []])
	# 0팀이 절반 진행한 거점에 1팀이 들어오면, 먼저 그 진행도를 지운 뒤에야 자기 점령이 시작된다.
	var seconds := _run_until_owned(match_rules, 0, [[], [AT_A]], 30.0)
	if int(match_rules.owners[0]) != 1:
		return "team 1 never captured the zone"
	if seconds <= Domination.CAPTURE_TIME:
		return "team 1 captured in %.2f s without first undoing team 0's progress" % seconds
	return ""


func test_owner_can_be_displaced() -> String:
	var match_rules := Domination.new(ZONES)
	_run_until_owned(match_rules, 0, [[AT_A], []], 20.0)
	for tick in 60 * 8:
		match_rules.update(TICK, [[], [AT_A]])
	if int(match_rules.owners[0]) != 1:
		return "an owned zone could not be taken by the other team"
	if match_rules.captures != 2:
		return "expected 2 captures in total, counted %d" % match_rules.captures
	return ""


func test_score_is_one_point_per_zone_per_second() -> String:
	var match_rules := Domination.new(ZONES)
	_run_until_owned(match_rules, 0, [[AT_A], []], 20.0)
	_run_until_owned(match_rules, 1, [[AT_A, AT_B], []], 20.0)
	var before: float = match_rules.scores[0]
	for tick in 600:
		match_rules.update(TICK, [[], []])
	var gained: float = float(match_rules.scores[0]) - before
	if absf(gained - 20.0) > 0.1:
		return "two zones for 10 s gave %.2f points, expected 20" % gained
	if float(match_rules.scores[1]) != 0.0:
		return "the team without zones scored"
	return ""


func test_bot_objectives() -> String:
	var match_rules := Domination.new(ZONES)
	# 아무도 차지하지 않은 거점 안에 있으면 그 자리를 지킨다.
	var holding: Array = match_rules.objectives_for(0, AT_A)
	if holding.size() != 1 or holding[0] != ZONES[0][1]:
		return "bot inside a neutral zone should hold it, got %s" % [holding]
	_run_until_owned(match_rules, 0, [[AT_A], []], 20.0)
	# 우리 거점 안에서는 아직 못 가진 거점으로 향한다.
	var next: Array = match_rules.objectives_for(0, AT_A)
	if next.size() != 1 or next[0] != ZONES[1][1]:
		return "bot should head for the uncaptured zone, got %s" % [next]
	_run_until_owned(match_rules, 1, [[AT_B], []], 20.0)
	if match_rules.objectives_for(0, NOWHERE).size() != 2:
		return "with every zone owned the bot should patrol all of them"
	return ""


## zone이 어느 팀 것이 될 때까지 진행하고 걸린 시간을 돌려준다.
func _run_until_owned(match_rules: Domination, zone: int, positions: Array, limit: float) -> float:
	var start_owner: int = match_rules.owners[zone]
	var elapsed := 0.0
	while elapsed < limit and int(match_rules.owners[zone]) == start_owner:
		match_rules.update(TICK, positions)
		elapsed += TICK
	return elapsed
