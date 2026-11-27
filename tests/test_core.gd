extends RefCounted

const Spring := preload("res://game/core/spring.gd")
const Recoil := preload("res://game/weapons/recoil.gd")
const Settings := preload("res://game/core/settings.gd")


func test_spring_returns_to_target() -> String:
	var spring := Spring.new(170.0, 17.0)
	spring.add_impulse(Vector3(0.0, 0.0, 1.0))
	var peak := 0.0
	for i in 180:
		spring.update(Vector3.ZERO, 1.0 / 60.0)
		peak = maxf(peak, spring.value.length())
	if peak < 0.01:
		return "impulse did not move the spring"
	if spring.value.length() > 0.001:
		return "spring did not settle, still at %s" % spring.value
	return ""


func test_spring_is_stable_with_long_frames() -> String:
	var spring := Spring.new(170.0, 17.0)
	spring.add_impulse(Vector3(0.0, 0.0, 1.0))
	for i in 20:
		spring.update(Vector3.ZERO, 0.2)
	if not is_finite(spring.value.length()) or spring.value.length() > 0.01:
		return "spring diverged with long frames: %s" % spring.value
	return ""


func test_recoil_kicks_up_then_recovers() -> String:
	var recoil := Recoil.new()
	recoil.add_kick(Vector2(0.0, 1.0))
	var peak := 0.0
	for i in 120:
		recoil.update(1.0 / 60.0, 9.0)
		peak = maxf(peak, recoil.offset.y)
	if peak < 0.3:
		return "recoil peak %f is too small" % peak
	if recoil.offset.length() > 0.01:
		return "recoil did not recover, still at %s" % recoil.offset
	return ""


func test_ui_scale_grows_in_portrait() -> String:
	# 가로 화면은 저장된 배율 그대로.
	if not is_equal_approx(Settings.scale_for(Vector2(844.0, 390.0), 1.5), 1.5):
		return "landscape scale should stay at the saved value"
	# 세로 화면(390x844): 엔진 배율 390/1280에 곱해져 UI 폭이 780/1.5 = 520이 되어야 한다.
	var factor := Settings.scale_for(Vector2(390.0, 844.0), 1.5)
	var ui_width := 390.0 / ((390.0 / 1280.0) * factor)
	if absf(ui_width - 520.0) > 1.0:
		return "portrait UI width should be 520, got %.1f" % ui_width
	return ""
