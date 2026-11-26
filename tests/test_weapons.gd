extends RefCounted
## 무기 밸런스 데이터가 의도한 역할을 지키는지 확인한다. 수치를 고치다 역할이 뒤바뀌면 여기서 걸린다.

const WeaponData := preload("res://game/weapons/weapon_data.gd")
const WeaponState := preload("res://game/weapons/weapon_state.gd")
const RIFLE: WeaponData = preload("res://game/weapons/data/rifle_vk7.tres")
const SMG: WeaponData = preload("res://game/weapons/data/smg_kestrel.tres")
const SHOTGUN: WeaponData = preload("res://game/weapons/data/shotgun_m90.tres")
const SNIPER: WeaponData = preload("res://game/weapons/data/sniper_lr12.tres")
const HEALTH := 100.0


func test_all_weapons_have_sane_values() -> String:
	for weapon: WeaponData in [RIFLE, SMG, SHOTGUN, SNIPER]:
		var name := weapon.display_name
		if weapon.damage <= 0.0 or weapon.min_damage <= 0.0 or weapon.min_damage > weapon.damage:
			return "%s has invalid damage values" % name
		if weapon.fire_interval <= 0.0 or weapon.magazine_size <= 0 or weapon.reload_time <= 0.0:
			return "%s has invalid handling values" % name
		if weapon.falloff_end <= weapon.falloff_start or weapon.max_range < weapon.falloff_end:
			return "%s has invalid range values" % name
		if weapon.pellets < 1 or weapon.recoil_pattern.is_empty():
			return "%s has no pellets or no recoil pattern" % name
		if weapon.ads_spread_deg > weapon.hip_spread_deg:
			return "%s is less accurate when aiming than from the hip" % name
	return ""


func test_time_to_kill_fits_each_role() -> String:
	# 근거리(5 m) 몸통 기준 처치 시간. 기관단총이 소총보다 빠르고, 둘 다 0.2~0.5초 사이여야 한다.
	var rifle := _time_to_kill(RIFLE, 5.0)
	var smg := _time_to_kill(SMG, 5.0)
	if smg >= rifle:
		return "SMG (%.2f s) should kill faster than the rifle (%.2f s) up close" % [smg, rifle]
	if rifle < 0.2 or rifle > 0.5:
		return "rifle time to kill %.2f s is outside 0.2-0.5 s" % rifle
	# 중거리(40 m)에서는 소총이 앞선다.
	var rifle_far := _time_to_kill(RIFLE, 40.0)
	var smg_far := _time_to_kill(SMG, 40.0)
	if rifle_far >= smg_far:
		return "rifle (%.2f s) should beat the SMG (%.2f s) at 40 m" % [rifle_far, smg_far]
	return ""


func test_shotgun_kills_close_but_not_far() -> String:
	var close: float = WeaponState.damage_at(SHOTGUN, 3.0, false) * SHOTGUN.pellets
	var far: float = WeaponState.damage_at(SHOTGUN, 25.0, false) * SHOTGUN.pellets
	if close < HEALTH:
		return "all pellets at 3 m deal %.0f, not enough for a one-shot kill" % close
	if far >= HEALTH / 2.0:
		return "all pellets at 25 m deal %.0f, the shotgun reaches too far" % far
	return ""


func test_sniper_one_shots_only_with_a_headshot() -> String:
	var body: float = WeaponState.damage_at(SNIPER, 50.0, false)
	var head: float = WeaponState.damage_at(SNIPER, 50.0, true)
	if body >= HEALTH:
		return "sniper body shot deals %.0f and kills in one hit" % body
	if head < HEALTH:
		return "sniper headshot deals %.0f and does not kill" % head
	if body * 2.0 < HEALTH:
		return "sniper needs more than two body shots"
	return ""


## 몸통에 모두 맞혔을 때 처치까지 걸리는 시간(첫 발은 0초에 나간다).
func _time_to_kill(weapon: WeaponData, distance: float) -> float:
	var per_shot: float = WeaponState.damage_at(weapon, distance, false) * weapon.pellets
	var shots := int(ceilf(HEALTH / per_shot))
	return (shots - 1) * weapon.fire_interval
