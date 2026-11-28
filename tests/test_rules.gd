extends RefCounted

const Vitals := preload("res://game/match/vitals.gd")
const AimAssist := preload("res://game/player/aim_assist.gd")
const CombatBot := preload("res://game/bots/combat_bot.gd")
const Grenades := preload("res://game/combat/grenades.gd")
const InputCmd := preload("res://game/player/input_cmd.gd")
const Armory := preload("res://game/weapons/armory.gd")
const Authority := preload("res://game/net/authority.gd")
const Progression := preload("res://game/core/progression.gd")
const XpTracker := preload("res://game/match/xp_tracker.gd")
const Names := preload("res://game/core/names.gd")
const MatchView := preload("res://game/net/match_view.gd")
const Announcer := preload("res://game/audio/announcer.gd")
const EYE := Vector3(0.0, 1.6, 0.0)


func test_health_waits_then_regenerates_to_full() -> String:
	if Vitals.regenerate(40.0, 100.0, Vitals.REGEN_DELAY - 0.1, 1.0) != 40.0:
		return "health regenerated before the delay passed"
	var after: float = Vitals.regenerate(40.0, 100.0, Vitals.REGEN_DELAY + 0.1, 1.0)
	if absf(after - (40.0 + Vitals.REGEN_RATE)) > 0.001:
		return "one second of regeneration gave %f" % after
	if Vitals.regenerate(95.0, 100.0, 60.0, 1.0) != 100.0:
		return "regeneration should stop at full health"
	if Vitals.regenerate(0.0, 100.0, 60.0, 1.0) != 0.0:
		return "dead players should not regenerate"
	return ""


func test_aim_assist_ignores_distant_and_off_screen_targets() -> String:
	var behind: Array = AimAssist.evaluate(EYE, 0.0, 0.0, [Vector3(0.0, 1.6, 20.0)])
	var far: Array = AimAssist.evaluate(EYE, 0.0, 0.0, [Vector3(0.0, 1.6, -200.0)])
	var none: Array = AimAssist.evaluate(EYE, 0.0, 0.0, [])
	for result: Array in [behind, far, none]:
		if result != [1.0, 0.0, 0.0]:
			return "assist should be off, got %s" % [result]
	return ""


func test_aim_assist_slows_and_pulls_toward_a_near_miss() -> String:
	# 적이 정면에서 오른쪽으로 약 3도 벗어나 있다.
	var target := Vector3(1.0, 1.6, -20.0)
	var result: Array = AimAssist.evaluate(EYE, 0.0, 0.0, [target])
	if float(result[0]) >= 1.0 or float(result[0]) < AimAssist.SLOWDOWN:
		return "look speed factor %f should be between the slowdown and 1" % float(result[0])
	# 오른쪽은 yaw가 줄어드는 방향이다.
	if float(result[1]) >= 0.0:
		return "assist should pull the view right (negative yaw), got %f" % float(result[1])
	if absf(float(result[1])) > AimAssist.PULL_SPEED:
		return "pull %f exceeds the maximum" % float(result[1])
	return ""


func test_aim_assist_stops_pulling_when_on_target() -> String:
	var result: Array = AimAssist.evaluate(EYE, 0.0, 0.0, [Vector3(0.0, 1.6, -20.0)])
	if float(result[1]) != 0.0 or float(result[2]) != 0.0:
		return "assist kept pulling while already on target: %s" % [result]
	if absf(float(result[0]) - AimAssist.SLOWDOWN) > 0.001:
		return "look speed should be fully slowed on target, got %f" % float(result[0])
	return ""


func test_aim_assist_converges_without_overshooting() -> String:
	var target := Vector3(1.5, 1.6, -20.0)
	var yaw := 0.0
	var wanted := atan2(-target.x, 20.0)
	for tick in 180:
		var result: Array = AimAssist.evaluate(EYE, yaw, 0.0, [target])
		yaw += float(result[1]) / 60.0
		if yaw < wanted - 0.001:
			return "assist overshot the target at tick %d" % tick
	if absf(yaw - wanted) > AimAssist.INNER + 0.002:
		return "after 3 s the view is still %f rad off" % absf(yaw - wanted)
	return ""


func test_bot_difficulty_levels_are_ordered() -> String:
	var easy := CombatBot.new(1)
	var normal := CombatBot.new(1)
	var hard := CombatBot.new(1)
	easy.set_difficulty("easy")
	normal.set_difficulty("normal")
	hard.set_difficulty("hard")
	if not (easy.reaction_time > normal.reaction_time and normal.reaction_time > hard.reaction_time):
		return "reaction time should shrink from easy to hard"
	if not (easy.aim_error_min > normal.aim_error_min and normal.aim_error_min > hard.aim_error_min):
		return "aim error should shrink from easy to hard"
	if not (easy.turn_speed < normal.turn_speed and normal.turn_speed < hard.turn_speed):
		return "turn speed should grow from easy to hard"
	return ""


func test_grenade_damage_falls_off_to_zero_at_the_radius() -> String:
	if Grenades.damage_at(0.0) != Grenades.MAX_DAMAGE:
		return "a grenade at point blank should deal full damage"
	if Grenades.damage_at(Grenades.RADIUS) != 0.0 or Grenades.damage_at(Grenades.RADIUS + 5.0) != 0.0:
		return "no damage at or beyond the radius"
	var previous := Grenades.MAX_DAMAGE
	for step in range(1, 14):
		var amount := Grenades.damage_at(step * 0.5)
		if amount > previous:
			return "damage went up with distance at %.1f m" % (step * 0.5)
		previous = amount
	if Grenades.damage_at(3.0) < 60.0 or Grenades.damage_at(3.0) >= 100.0 + 20.0:
		return "damage at 3 m is %f" % Grenades.damage_at(3.0)
	return ""


func test_grenade_button_survives_the_network_format() -> String:
	var cmd := InputCmd.new()
	cmd.buttons = InputCmd.GRENADE | InputCmd.FIRE
	var back: InputCmd = InputCmd.from_array(cmd.to_array())
	if back == null or not back.has(InputCmd.GRENADE) or not back.has(InputCmd.FIRE):
		return "the grenade button was lost in to_array / from_array"
	return ""


func test_loadout_is_a_primary_and_the_pistol() -> String:
	for id: int in Armory.PRIMARIES:
		var weapons: Array = Armory.loadout(id)
		if weapons != [Armory.WEAPONS[id], Armory.WEAPONS[Armory.SIDEARM]]:
			return "loadout for %d is %s" % [id, weapons]
	# 설정이나 네트워크에서 온 엉뚱한 번호(권총, 범위 밖)는 기본 주무기가 된다.
	for wrong: int in [Armory.SIDEARM, -1, 99]:
		if Armory.loadout(wrong)[0] != Armory.WEAPONS[Armory.DEFAULT_PRIMARY]:
			return "invalid primary %d was accepted" % wrong
	for id in Armory.WEAPONS.size():
		if Armory.id_of(Armory.WEAPONS[id]) != id or Armory.ICONS[id] == null:
			return "weapon %d has no id or icon" % id
		for value: float in Armory.stats(id):
			if value <= 0.0 or value > 1.0:
				return "stat %f of weapon %d is outside 0..1" % [value, id]
	return ""


func test_primary_swaps_now_only_right_after_spawning() -> String:
	var player := FakePlayer.new()
	var entry := {"player": player, "swap_left": 2.0, "primary": 0}
	if not Authority.choose_primary(entry, 3) or player.primary != 3:
		return "a fresh spawn should switch weapons at once"
	entry["swap_left"] = 0.0
	if Authority.choose_primary(entry, 1) or player.primary != 3 or entry["primary"] != 1:
		return "after the swap window the choice should wait for the next spawn"
	player.alive = false
	entry["swap_left"] = 2.0
	if Authority.choose_primary(entry, 2) or player.primary != 3:
		return "a dead player should not switch until he respawns"
	return ""


## choose_primary가 쓰는 부분만 흉내 낸 플레이어.
class FakePlayer:
	var alive := true
	var primary := 0

	func set_primary(id: int) -> void:
		primary = id


func test_levels_follow_the_xp_curve() -> String:
	if Progression.level_for(0) != 1 or Progression.level_start(1) != 0:
		return "a new player should be level 1"
	if Progression.level_for(Progression.FIRST_SPAN - 1) != 1:
		return "levelled up before reaching the first threshold"
	if Progression.level_for(Progression.FIRST_SPAN) != 2:
		return "did not reach level 2 at %d xp" % Progression.FIRST_SPAN
	var previous_span := 0
	for level in range(1, Progression.MAX_LEVEL):
		var span := Progression.level_start(level + 1) - Progression.level_start(level)
		if span <= previous_span:
			return "level %d is not harder than the one before" % level
		previous_span = span
		if Progression.level_for(Progression.level_start(level)) != level:
			return "level_for disagrees with level_start at %d" % level
	return ""


func test_level_cap_and_progress_within_a_level() -> String:
	if Progression.level_for(10000000) != Progression.MAX_LEVEL:
		return "level is not capped"
	if Progression.progress_in_level(10000000) != [0, 0]:
		return "the top level should have no progress bar"
	var progress := Progression.progress_in_level(Progression.level_start(3) + 50)
	if progress != [50, 1200]:
		return "progress in level 3 is %s" % [progress]
	return ""


func test_weapons_unlock_by_level() -> String:
	if not Progression.is_unlocked(Armory.DEFAULT_PRIMARY, 1):
		return "the default rifle must be usable at level 1"
	if not Progression.is_unlocked(Armory.SIDEARM, 1):
		return "the pistol must be usable at level 1"
	for weapon_id: int in Progression.UNLOCKS:
		var level := Progression.unlock_level(weapon_id)
		if Progression.is_unlocked(weapon_id, level - 1) or not Progression.is_unlocked(weapon_id, level):
			return "weapon %d does not unlock exactly at level %d" % [weapon_id, level]
		if not Progression.unlocked_at(level).has(weapon_id):
			return "unlocked_at(%d) misses weapon %d" % [level, weapon_id]
	return ""


func test_xp_tracker_awards_kills_and_one_match_result() -> String:
	var tracker := XpTracker.new(null, false)
	tracker.on_kill(false)
	tracker.on_kill(true)
	var kills := Progression.KILL_XP * 2 + Progression.HEADSHOT_XP
	if tracker.earned != kills:
		return "two kills (one headshot) gave %d xp" % tracker.earned
	# 판이 끝난 동안 상태가 여러 번 와도 결과 경험치는 한 번만 준다.
	for _repeat in 3:
		tracker.on_match_state(true, 30, 12)
	if tracker.earned != kills + Progression.WIN_XP:
		return "a won match gave %d xp in total" % tracker.earned
	tracker.on_match_state(false, 0, 0)
	tracker.on_match_state(true, 5, 30)
	if tracker.earned_this_match != Progression.LOSS_XP:
		return "the next lost match counted %d xp" % tracker.earned_this_match
	return ""


func test_names_are_cleaned() -> String:
	if Names.sanitize("  Ace   of <b>Spades</b>!!  ") != "Ace of bSpadesb":
		return "sanitize gave '%s'" % Names.sanitize("  Ace   of <b>Spades</b>!!  ")
	if Names.sanitize("한글이름") != "" or Names.sanitize("   ") != "":
		return "names without allowed letters should become empty"
	if Names.sanitize("x".repeat(40)).length() != Names.MAX_LENGTH:
		return "long names are not cut"
	return ""


func test_server_renames_keep_names_unique() -> String:
	var peers := {1: {"name": "Viper"}, 2: {"name": "P-2"}}
	if not Names.rename(peers, 2, "Viper") or peers[2]["name"] != "Viper2":
		return "a taken name was not made unique: %s" % peers[2]["name"]
	if Names.rename(peers, 2, "###") or peers[2]["name"] != "Viper2":
		return "an empty name should be refused"
	if Names.rename(peers, 9, "Ghost"):
		return "renaming someone who is not there should fail"
	return ""


## 판 상태 줄: [내 팀, 파랑 점수, 빨강 점수, 남은 시간, 끝남, 킬, 데스, 살아 있음].
func _status(blue: int, red: int, left: float, over: bool) -> Array:
	return [0, blue, red, left, over, 0, 0, true]


func test_announcer_follows_the_match() -> String:
	var view := MatchView.new()
	var voice := Announcer.new()
	view.announcer = voice
	view.show_match(null, _status(0, 0, 299.0, false))
	view.show_match(null, _status(3, 1, 200.0, false))
	view.show_match(null, _status(20, 12, 61.0, false))
	view.show_match(null, _status(21, 12, 59.5, false))
	view.show_match(null, _status(30, 12, 0.0, true))
	view.show_match(null, _status(30, 12, 0.0, true))
	view.show_match(null, _status(0, 0, 300.0, false))
	var heard := voice.pending()
	voice.free()
	if heard != ["start", "one_minute", "victory", "start"]:
		return "the announcer queued %s" % [heard]
	return ""


func test_announcer_reports_zone_changes_but_not_resets() -> String:
	var view := MatchView.new()
	var voice := Announcer.new()
	view.announcer = voice
	view.own_team = 0
	view.show_match(null, _status(0, 0, 250.0, false))
	view._announce_zones([[-1, 0.0, -1], [-1, 0.0, -1], [-1, 0.0, -1]])
	view._announce_zones([[0, 0.0, -1], [-1, 0.0, -1], [-1, 0.0, -1]])
	view._announce_zones([[1, 0.0, -1], [-1, 0.0, -1], [1, 0.0, -1]])
	# 판이 끝나 거점이 초기화되는 동안에는 말하지 않는다.
	view.show_match(null, _status(100, 150, 0.0, true))
	view._announce_zones([[-1, 0.0, -1], [-1, 0.0, -1], [-1, 0.0, -1]])
	var heard := voice.pending()
	var flagged := voice.domination
	voice.free()
	if heard != ["zone_taken", "zone_lost", "defeat"]:
		return "zone announcements were %s" % [heard]
	if not flagged:
		return "seeing zones should switch the start line to domination"
	return ""
