extends RefCounted

const InputCmd := preload("res://game/player/input_cmd.gd")
const CombatBot := preload("res://game/bots/combat_bot.gd")
const TICK := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)
const FEET := Vector3.ZERO


func test_bot_waits_for_reaction_time_then_fires() -> String:
	var bot := CombatBot.new(5)
	var enemies := [Vector3(0.0, 0.0, -10.0)]
	var first_fire := -1.0
	for tick in 180:
		var cmd: InputCmd = bot.make_cmd(TICK, EYE, FEET, 0.0, enemies, [])
		if cmd.has(InputCmd.FIRE) and first_fire < 0.0:
			first_fire = tick * TICK
	if first_fire < 0.0:
		return "bot never fired at an enemy 10 m straight ahead"
	if first_fire < bot.reaction_time - TICK:
		return "bot fired after %f s, before its reaction time" % first_fire
	return ""


func test_bot_turn_rate_is_limited() -> String:
	var bot := CombatBot.new(5)
	# 적이 정확히 뒤에 있어도 한 틱에 돌 수 있는 각도는 정해져 있다.
	var cmd: InputCmd = bot.make_cmd(TICK, EYE, FEET, 0.0, [Vector3(0.0, 0.0, 10.0)], [])
	var limit := bot.turn_speed * TICK + 0.0001
	if absf(cmd.yaw) > limit:
		return "bot turned %f rad in one tick (limit %f)" % [absf(cmd.yaw), limit]
	if cmd.has(InputCmd.FIRE):
		return "bot fired while facing away from the enemy"
	return ""


func test_bot_aim_converges_on_target() -> String:
	var bot := CombatBot.new(9)
	var enemy := Vector3(8.0, 0.0, -8.0)
	var cmd: InputCmd
	for tick in 240:
		cmd = bot.make_cmd(TICK, EYE, FEET, 0.0, [enemy], [])
	var to_target := enemy + Vector3.UP * CombatBot.AIM_HEIGHT - EYE
	var wanted_yaw := atan2(-to_target.x, -to_target.z)
	var miss := absf(angle_difference(cmd.yaw, wanted_yaw))
	if miss > bot.aim_error_min + 0.01:
		return "after 4 s the bot is still %f rad off target" % miss
	return ""


func test_bot_roams_toward_a_nav_point() -> String:
	var bot := CombatBot.new(3)
	var nav_points := [Vector3(-20.0, 0.0, 0.0)]
	var cmd: InputCmd
	for tick in 120:
		cmd = bot.make_cmd(TICK, EYE, FEET, 5.0, [], nav_points)
	if cmd.move.y > -0.5:
		return "roaming bot is not walking forward"
	# 목표가 왼쪽(-x)이므로 yaw는 +90도 쪽으로 돌아야 한다.
	if absf(angle_difference(cmd.yaw, PI / 2.0)) > 0.05:
		return "roaming bot faces yaw %f, wanted %f" % [cmd.yaw, PI / 2.0]
	if cmd.has(InputCmd.FIRE):
		return "roaming bot is firing at nothing"
	return ""


func test_stuck_bot_tries_to_jump() -> String:
	var bot := CombatBot.new(3)
	var nav_points := [Vector3(0.0, 0.0, -30.0)]
	var jumped := false
	for tick in 90:
		# 속력 0: 벽에 막힌 상황.
		var cmd: InputCmd = bot.make_cmd(TICK, EYE, FEET, 0.0, [], nav_points)
		jumped = jumped or cmd.has(InputCmd.JUMP)
	if not jumped:
		return "bot blocked for 1.5 s never tried to jump over the obstacle"
	return ""


func test_same_seed_gives_same_decisions() -> String:
	var first := CombatBot.new(77)
	var second := CombatBot.new(77)
	var enemies := [Vector3(5.0, 0.0, -12.0)]
	for tick in 120:
		var a: InputCmd = first.make_cmd(TICK, EYE, FEET, 0.0, enemies, [])
		var b: InputCmd = second.make_cmd(TICK, EYE, FEET, 0.0, enemies, [])
		if a.to_array() != b.to_array():
			return "bots with the same seed diverged at tick %d" % tick
	return ""
