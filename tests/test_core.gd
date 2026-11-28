extends RefCounted

const Spring := preload("res://game/core/spring.gd")
const Recoil := preload("res://game/weapons/recoil.gd")
const Settings := preload("res://game/core/settings.gd")
const Dressing := preload("res://maps/dressing.gd")
const AssetPack := preload("res://game/core/asset_pack.gd")


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


## 하늘 사진의 (u, v)를 Godot 하늘 셰이더와 같은 방향으로 읽어야 해와 조명이 맞는다.
func test_sky_direction_matches_godot_panorama() -> String:
	var cases := [
		[Vector2(0.0, 0.5), Vector3(0, 0, -1)],
		[Vector2(0.25, 0.5), Vector3(1, 0, 0)],
		[Vector2(0.5, 0.5), Vector3(0, 0, 1)],
		[Vector2(0.75, 0.5), Vector3(-1, 0, 0)],
		[Vector2(0.3, 0.0), Vector3(0, 1, 0)],
	]
	for item: Array in cases:
		var got := Dressing.sky_direction(item[0])
		if not got.is_equal_approx(item[1]):
			return "uv %s should point %s, got %s" % [item[0], item[1], got]
	var raised := Dressing.sky_direction(Vector2(0.25, 0.49), 30.0)
	if absf(raised.y - 0.5) > 0.001 or raised.x <= 0.0:
		return "elevation override should keep the azimuth and set 30 degrees, got %s" % raised
	return ""


## 접지 그림자는 바닥에 닿은 물체에만 깐다.
func test_contact_shadow_only_for_grounded_boxes() -> String:
	var parent := Node3D.new()
	Dressing.add_contact_shadow(parent, Vector3(0, 1, 0), Vector3(2, 2, 2))
	Dressing.add_contact_shadow(parent, Vector3(0, 3, 0), Vector3(2, 2, 2))
	var count := parent.get_child_count()
	parent.free()
	if count != 1:
		return "expected one shadow for the grounded box, got %d" % count
	return ""


## 웹 에셋 팩의 UID 목록: 모르는 UID만 등록하고, 이미 아는 것과 잘못된 줄은 건너뛴다.
func test_asset_pack_registers_unknown_uids() -> String:
	var known := ResourceUID.create_id()
	ResourceUID.add_id(known, "res://already.png")
	var fresh := ResourceUID.create_id()
	var text := "%s res://fresh.png\n%s res://other.png\nnot-a-line\n" % [
		ResourceUID.id_to_text(fresh), ResourceUID.id_to_text(known)
	]
	var added := AssetPack.register_uids(text)
	var path := ResourceUID.get_id_path(fresh) if ResourceUID.has_id(fresh) else ""
	var kept := ResourceUID.get_id_path(known)
	ResourceUID.remove_id(fresh)
	ResourceUID.remove_id(known)
	if added != 1 or path != "res://fresh.png":
		return "expected only the unknown uid to be added, added %d path %s" % [added, path]
	if kept != "res://already.png":
		return "a known uid must keep its path, got %s" % kept
	return ""
