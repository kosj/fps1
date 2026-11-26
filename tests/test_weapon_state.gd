extends RefCounted

const WeaponData := preload("res://game/weapons/weapon_data.gd")
const WeaponState := preload("res://game/weapons/weapon_state.gd")
const TICK := 1.0 / 60.0


func test_starts_with_full_magazine() -> String:
	var state := WeaponState.new(_rifle())
	return _expect_int(state.ammo, 30)


func test_fire_consumes_ammo_and_respects_interval() -> String:
	var state := WeaponState.new(_rifle())
	state.update(TICK)
	if not state.try_fire():
		return "first shot should fire"
	if state.try_fire():
		return "second shot in the same tick should be blocked by the fire interval"
	return _expect_int(state.ammo, 29)


func test_sustained_fire_rate_matches_interval() -> String:
	# 0.085초 간격이면 1초에 11~12발. 틱 간격(1/60초)으로 반올림되어 10발로 떨어지면 안 된다.
	var state := WeaponState.new(_rifle())
	var shots := 0
	for i in 60:
		state.update(TICK)
		if state.try_fire():
			shots += 1
	if shots < 11 or shots > 13:
		return "expected 11-13 shots in one second, got %d" % shots
	return ""


func test_cannot_fire_when_empty() -> String:
	var data := _rifle()
	data.magazine_size = 1
	var state := WeaponState.new(data)
	state.update(TICK)
	state.try_fire()
	for i in 30:
		state.update(TICK)
	if state.try_fire():
		return "fired with an empty magazine"
	return ""


func test_reload_refills_after_reload_time() -> String:
	var state := WeaponState.new(_rifle())
	state.update(TICK)
	state.try_fire()
	if not state.start_reload():
		return "reload should start when the magazine is not full"
	if state.can_fire():
		return "should not fire while reloading"
	var finished := false
	var ticks := 0
	while not finished and ticks < 600:
		finished = state.update(TICK)
		ticks += 1
	var message := _expect_int(state.ammo, 30)
	if not message.is_empty():
		return message
	var seconds := ticks * TICK
	if absf(seconds - state.data.reload_time) > 0.05:
		return "reload took %f s" % seconds
	return ""


func test_reload_refused_when_full() -> String:
	var state := WeaponState.new(_rifle())
	if state.start_reload():
		return "reload should be refused with a full magazine"
	return ""


func test_recoil_follows_pattern_then_resets() -> String:
	var data := _rifle()
	data.recoil_pattern = PackedVector2Array([Vector2(0.0, 1.0), Vector2(0.5, 0.8)])
	var state := WeaponState.new(data)
	state.update(TICK)
	state.try_fire()
	if not state.last_kick.is_equal_approx(Vector2(0.0, 1.0)):
		return "first kick was %s" % state.last_kick
	for i in 6:
		state.update(TICK)
	state.try_fire()
	if not state.last_kick.is_equal_approx(Vector2(0.5, 0.8)):
		return "second kick was %s" % state.last_kick
	# 쉬었다 쏘면 패턴이 처음으로 돌아간다.
	for i in 40:
		state.update(TICK)
	state.try_fire()
	if not state.last_kick.is_equal_approx(Vector2(0.0, 1.0)):
		return "kick after pause was %s" % state.last_kick
	return ""


func test_damage_falloff_and_headshot() -> String:
	var data := _rifle()
	var near: float = WeaponState.damage_at(data, 5.0, false)
	var mid: float = WeaponState.damage_at(data, 42.5, false)
	var far: float = WeaponState.damage_at(data, 100.0, false)
	var head: float = WeaponState.damage_at(data, 5.0, true)
	if absf(near - 28.0) > 0.001:
		return "near damage %f" % near
	if absf(mid - 23.0) > 0.001:
		return "mid damage %f" % mid
	if absf(far - 18.0) > 0.001:
		return "far damage %f" % far
	if absf(head - 42.0) > 0.001:
		return "headshot damage %f" % head
	return ""


func test_spread_stays_inside_cone_and_is_deterministic() -> String:
	var first := WeaponState.new(_rifle(), 42)
	var second := WeaponState.new(_rifle(), 42)
	var limit := deg_to_rad(2.0) + 0.0001
	for i in 200:
		var a := first.roll_spread(2.0)
		var b := second.roll_spread(2.0)
		if a.length() > limit:
			return "spread %f rad is outside the cone" % a.length()
		if not a.is_equal_approx(b):
			return "same seed produced different spread"
	return ""


func _rifle() -> WeaponData:
	var data := WeaponData.new()
	data.damage = 28.0
	data.min_damage = 18.0
	data.headshot_multiplier = 1.5
	data.falloff_start = 25.0
	data.falloff_end = 60.0
	data.fire_interval = 0.085
	data.magazine_size = 30
	data.reload_time = 1.9
	data.recoil_reset_time = 0.35
	return data


func _expect_int(actual: int, expected: int) -> String:
	if actual != expected:
		return "expected %d, got %d" % [expected, actual]
	return ""
