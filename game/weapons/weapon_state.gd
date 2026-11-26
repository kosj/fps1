extends RefCounted
## 무기 한 자루의 상태 기계. 노드와 무관하게 탄약, 연사 간격, 재장전, 반동 순서를 관리한다.
## 서버와 클라이언트가 같은 입력으로 같은 결과를 내도록 고정 틱에서만 갱신한다.

enum Phase { READY, RELOADING }

const WeaponData := preload("res://game/weapons/weapon_data.gd")

var data: WeaponData
var ammo := 0
var phase := Phase.READY
var cooldown := 0.0
var reload_left := 0.0
var shot_index := 0
var since_last_shot := 0.0
## 마지막으로 발사한 탄의 반동(도). x: 좌우, y: 상승.
var last_kick := Vector2.ZERO

var _rng := RandomNumberGenerator.new()


func _init(p_data: WeaponData, p_seed: int = 1) -> void:
	data = p_data
	ammo = data.magazine_size
	_rng.seed = p_seed


## 한 틱 진행한다. 이번 틱에 재장전이 끝났으면 true.
func update(delta: float) -> bool:
	# 틱 하나만큼의 여유를 남겨 연사 속도가 틱 간격에 맞춰 느려지지 않게 한다.
	cooldown = maxf(cooldown - delta, -delta)
	since_last_shot += delta
	if since_last_shot >= data.recoil_reset_time:
		shot_index = 0
	if phase != Phase.RELOADING:
		return false
	reload_left -= delta
	if reload_left > 0.0:
		return false
	ammo = data.magazine_size
	phase = Phase.READY
	return true


func can_fire() -> bool:
	return phase == Phase.READY and cooldown <= 0.0 and ammo > 0


## 발사를 시도한다. 성공하면 탄약, 쿨다운, last_kick을 갱신한다.
func try_fire() -> bool:
	if not can_fire():
		return false
	ammo -= 1
	cooldown += data.fire_interval
	last_kick = _kick_for(shot_index)
	shot_index += 1
	since_last_shot = 0.0
	return true


func start_reload() -> bool:
	if phase != Phase.READY or ammo >= data.magazine_size:
		return false
	phase = Phase.RELOADING
	reload_left = data.reload_time
	return true


## 원뿔 안에서 고르게 뽑은 편차(라디안). x: 좌우, y: 상하.
func roll_spread(spread_deg: float) -> Vector2:
	var radius := deg_to_rad(spread_deg) * sqrt(_rng.randf())
	var angle := _rng.randf() * TAU
	return Vector2(cos(angle), sin(angle)) * radius


## 거리와 부위에 따른 피해량.
static func damage_at(weapon: WeaponData, distance: float, headshot: bool) -> float:
	var span := maxf(weapon.falloff_end - weapon.falloff_start, 0.001)
	var falloff := clampf((distance - weapon.falloff_start) / span, 0.0, 1.0)
	var amount := lerpf(weapon.damage, weapon.min_damage, falloff)
	if headshot:
		amount *= weapon.headshot_multiplier
	return amount


func _kick_for(index: int) -> Vector2:
	var pattern := data.recoil_pattern
	if pattern.is_empty():
		return Vector2.ZERO
	return pattern[mini(index, pattern.size() - 1)]
