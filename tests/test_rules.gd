extends RefCounted

const Vitals := preload("res://game/match/vitals.gd")
const AimAssist := preload("res://game/player/aim_assist.gd")
const CombatBot := preload("res://game/bots/combat_bot.gd")
const Grenades := preload("res://game/combat/grenades.gd")
const InputCmd := preload("res://game/player/input_cmd.gd")
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
