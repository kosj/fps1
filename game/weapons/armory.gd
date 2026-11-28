extends RefCounted
## 무기 목록과 로드아웃(주무기 하나 + 권총).
## 무기 번호(id)는 네트워크로 주고받고 설정에 저장하므로 순서를 바꾸지 말고 뒤에만 붙인다.

const WEAPONS := [
	preload("res://game/weapons/data/rifle_vk7.tres"),
	preload("res://game/weapons/data/smg_kestrel.tres"),
	preload("res://game/weapons/data/shotgun_m90.tres"),
	preload("res://game/weapons/data/sniper_lr12.tres"),
	preload("res://game/weapons/data/pistol_p9.tres"),
]
## 선택 화면의 아이콘(옆모습). tools/asset_pipeline/build_weapons.py --icons로 만든다.
const ICONS := [
	preload("res://game/ui/icons/rifle_vk7.png"),
	preload("res://game/ui/icons/smg_kestrel.png"),
	preload("res://game/ui/icons/shotgun_m90.png"),
	preload("res://game/ui/icons/sniper_lr12.png"),
	preload("res://game/ui/icons/pistol_p9.png"),
]
const ROLES := ["Assault rifle", "Submachine gun", "Shotgun", "Sniper rifle", "Pistol"]
const PRIMARIES := [0, 1, 2, 3]
const SIDEARM := 4
const DEFAULT_PRIMARY := 0
## 능력치 막대의 최댓값. 피해는 한 발(산탄은 전부 맞혔을 때), 연사는 분당 발수,
## 사거리는 피해가 줄기 시작하는 거리(m), 조작은 정조준에 걸리는 시간(초, 짧을수록 좋다).
const MAX_SHOT_DAMAGE := 100.0
const MAX_RPM := 950.0
const MAX_RANGE := 70.0
const SLOWEST_ADS := 0.4


static func is_primary(id: int) -> bool:
	return PRIMARIES.has(id)


## 잘못된 번호면 기본 주무기로 바꾼다. 네트워크와 설정에서 온 값은 이걸 거쳐 쓴다.
static func valid_primary(id: int) -> int:
	return id if is_primary(id) else DEFAULT_PRIMARY


## 로드아웃의 무기 데이터: [주무기, 권총]. 무기 칸 0이 주무기, 1이 권총이다.
static func loadout(primary: int) -> Array:
	return [WEAPONS[valid_primary(primary)], WEAPONS[SIDEARM]]


static func id_of(data: Resource) -> int:
	return WEAPONS.find(data)


static func title(id: int) -> String:
	return str(WEAPONS[id].get("display_name"))


## 선택 화면에 보여 줄 능력치(0~1): [피해, 연사, 사거리, 조작].
static func stats(id: int) -> Array:
	var data: Resource = WEAPONS[id]
	var shot := float(data.get("damage")) * int(data.get("pellets"))
	var rpm := 60.0 / float(data.get("fire_interval"))
	var reach := float(data.get("falloff_start"))
	var handling := 1.0 - float(data.get("ads_time")) / SLOWEST_ADS
	return [
		clampf(shot / MAX_SHOT_DAMAGE, 0.05, 1.0),
		clampf(rpm / MAX_RPM, 0.05, 1.0),
		clampf(reach / MAX_RANGE, 0.05, 1.0),
		clampf(handling, 0.05, 1.0),
	]
