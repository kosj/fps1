extends RefCounted

const InputCmd := preload("res://game/player/input_cmd.gd")
const HitMath := preload("res://game/combat/hit_math.gd")
const RemoteAvatar := preload("res://game/player/remote_avatar.gd")
const ScriptBot := preload("res://game/bots/script_bot.gd")


func test_input_round_trip() -> String:
	var cmd := InputCmd.new()
	cmd.seq = 42
	cmd.move = Vector2(0.5, -1.0).limit_length(1.0)
	cmd.yaw = 1.2
	cmd.pitch = -0.4
	cmd.buttons = InputCmd.FIRE | InputCmd.AIM
	cmd.view_tick = 1234.5
	cmd.weapon = 2
	var copy: InputCmd = InputCmd.from_array(cmd.to_array())
	if copy == null:
		return "valid input was rejected"
	if copy.weapon != 2:
		return "round trip changed the weapon slot"
	if copy.seq != 42 or copy.buttons != cmd.buttons or not copy.move.is_equal_approx(cmd.move):
		return "round trip changed the input"
	if absf(copy.yaw - 1.2) > 0.0001 or absf(copy.pitch + 0.4) > 0.0001:
		return "round trip changed the view angles"
	return ""


func test_input_rejects_malformed_data() -> String:
	var bad_inputs := [
		[],
		[1, Vector2.ZERO, 0.0, 0.0, 0, 0.0],
		["1", Vector2.ZERO, 0.0, 0.0, 0, 0.0, 0],
		[1, "move", 0.0, 0.0, 0, 0.0, 0],
		[1, Vector2.ZERO, NAN, 0.0, 0, 0.0, 0],
		[1, Vector2(INF, 0.0), 0.0, 0.0, 0, 0.0, 0],
		[1, Vector2.ZERO, 0.0, 0.0, 0.5, 0.0, 0],
		[1, Vector2.ZERO, 0.0, 0.0, 0, 0.0, "rifle"],
	]
	for index in bad_inputs.size():
		if InputCmd.from_array(bad_inputs[index]) != null:
			return "malformed input %d was accepted" % index
	return ""


func test_input_clamps_cheating_values() -> String:
	# 속도를 올리려고 이동 벡터를 키우거나, 없는 버튼 비트를 넣거나, 시선을 뒤집는 값을 잘라 낸다.
	var cmd: InputCmd = InputCmd.from_array([7, Vector2(50.0, 0.0), 100.0, 9.0, 4095, 0.0, 99])
	if cmd == null:
		return "input was rejected instead of clamped"
	if cmd.move.length() > 1.0001:
		return "move length %f was not limited to 1" % cmd.move.length()
	if absf(cmd.pitch) > InputCmd.PITCH_LIMIT + 0.0001:
		return "pitch %f was not clamped" % cmd.pitch
	if absf(cmd.yaw) > PI + 0.0001:
		return "yaw %f was not wrapped" % cmd.yaw
	if cmd.buttons != InputCmd.ALL_BUTTONS:
		return "unknown button bits were kept"
	if cmd.weapon != InputCmd.MAX_WEAPON_SLOT:
		return "weapon slot %d was not clamped" % cmd.weapon
	return ""


func test_ray_box_hit_and_miss() -> String:
	var center := Vector3(0.0, 1.0, -10.0)
	var half := Vector3(0.5, 0.5, 0.5)
	var hit: float = HitMath.ray_box(Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, center, half)
	if absf(hit - 9.5) > 0.001:
		return "expected a hit at 9.5 m, got %f" % hit
	var miss: float = HitMath.ray_box(Vector3(2.0, 1.0, 0.0), Vector3.FORWARD, center, half)
	if miss >= 0.0:
		return "ray 2 m to the side should miss"
	var behind: float = HitMath.ray_box(Vector3(0.0, 1.0, 0.0), Vector3.BACK, center, half)
	if behind >= 0.0:
		return "box behind the ray should not be hit"
	return ""


func test_player_hit_distinguishes_head_and_body() -> String:
	var feet := Vector3(0.0, 0.0, -10.0)
	var body: Array = HitMath.player_hit(Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, feet, false)
	if float(body[0]) < 0.0 or bool(body[1]):
		return "chest-height shot should be a body hit, got %s" % [body]
	var head: Array = HitMath.player_hit(Vector3(0.0, 1.7, 0.0), Vector3.FORWARD, feet, false)
	if float(head[0]) < 0.0 or not bool(head[1]):
		return "head-height shot should be a headshot, got %s" % [head]
	var over: Array = HitMath.player_hit(Vector3(0.0, 1.9, 0.0), Vector3.FORWARD, feet, false)
	if float(over[0]) >= 0.0:
		return "shot above the head should miss"
	return ""


func test_crouching_lowers_the_hitbox() -> String:
	var feet := Vector3(0.0, 0.0, -10.0)
	var origin := Vector3(0.0, 1.5, 0.0)
	var standing: Array = HitMath.player_hit(origin, Vector3.FORWARD, feet, false)
	var low: Array = HitMath.player_hit(origin, Vector3.FORWARD, feet, true)
	if float(standing[0]) < 0.0:
		return "1.5 m shot should hit a standing player"
	if float(low[0]) >= 0.0:
		return "1.5 m shot should pass over a crouching player"
	return ""


func test_avatar_interpolates_between_snapshots() -> String:
	var avatar := RemoteAvatar.new()
	avatar.build()
	avatar.push(100, Vector3(0.0, 0.0, 0.0), 0.0, false, true)
	avatar.push(102, Vector3(2.0, 0.0, 0.0), 0.0, false, true)
	avatar.push(104, Vector3(4.0, 0.0, 0.0), 0.0, false, true)
	avatar.sample(101.0)
	var message := _expect_x(avatar.position.x, 1.0, "midway between first two snapshots")
	if message.is_empty():
		avatar.sample(103.5)
		message = _expect_x(avatar.position.x, 3.5, "between last two snapshots")
	if message.is_empty():
		# 최신 스냅샷보다 앞선 시점은 예측하지 않고 최신 위치에 머문다.
		avatar.sample(110.0)
		message = _expect_x(avatar.position.x, 4.0, "past the newest snapshot")
	if message.is_empty():
		avatar.sample(50.0)
		message = _expect_x(avatar.position.x, 0.0, "before the oldest snapshot")
	avatar.free()
	return message


func test_avatar_ignores_out_of_order_snapshots() -> String:
	var avatar := RemoteAvatar.new()
	avatar.build()
	avatar.push(100, Vector3(1.0, 0.0, 0.0), 0.0, false, true)
	avatar.push(98, Vector3(9.0, 0.0, 0.0), 0.0, false, true)
	avatar.sample(100.0)
	var message := _expect_x(avatar.position.x, 1.0, "after a stale snapshot")
	avatar.free()
	return message


func test_shooter_bot_aims_at_target() -> String:
	var bot := ScriptBot.new("shooter")
	var eye := Vector3(0.0, 1.6, 0.0)
	var cmd: InputCmd = bot.make_cmd(1.0 / 60.0, eye, [Vector3(10.0, 0.0, -10.0)])
	var view := Basis.from_euler(Vector3(cmd.pitch, cmd.yaw, 0.0))
	var aim_point := Vector3(10.0, 1.0, -10.0)
	var wanted := (aim_point - eye).normalized()
	if (-view.z).distance_to(wanted) > 0.001:
		return "bot looks along %s, wanted %s" % [-view.z, wanted]
	if cmd.has(InputCmd.FIRE):
		return "bot should not fire before it has aimed for a moment"
	return ""


func _expect_x(actual: float, expected: float, where: String) -> String:
	if absf(actual - expected) > 0.001:
		return "%s: expected x=%f, got %f" % [where, expected, actual]
	return ""
