extends RefCounted
## 성장 규칙: 경험치(XP)로 레벨이 오르고, 레벨에 따라 주무기가 풀린다.
## 계정이 없으므로 기기마다 따로 쌓이고 설정 파일에 저장한다. 서버는 검사하지 않는다.

const Settings := preload("res://game/core/settings.gd")
const XP_KEY := "progress/xp"
const KILL_XP := 100
const HEADSHOT_XP := 50
const WIN_XP := 500
const DRAW_XP := 300
const LOSS_XP := 200
const MAX_LEVEL := 30
## 레벨 1에서 2로 가는 데 드는 경험치와, 레벨마다 늘어나는 양.
const FIRST_SPAN := 800
const SPAN_STEP := 200
## 주무기가 풀리는 레벨(game/weapons/armory.gd 번호 -> 레벨). 목록에 없으면 처음부터 쓸 수 있다.
const UNLOCKS := {1: 2, 2: 3, 3: 4}


## level에 처음 도달하는 누적 경험치.
static func level_start(level: int) -> int:
	var steps := clampi(level, 1, MAX_LEVEL) - 1
	return FIRST_SPAN * steps + SPAN_STEP * steps * (steps - 1) / 2


static func level_for(xp: int) -> int:
	var level := 1
	while level < MAX_LEVEL and xp >= level_start(level + 1):
		level += 1
	return level


## 지금 레벨 안에서의 진행: [쌓은 양, 다음 레벨까지 필요한 양]. 최고 레벨이면 [0, 0].
static func progress_in_level(xp: int) -> Array:
	var level := level_for(xp)
	if level >= MAX_LEVEL:
		return [0, 0]
	return [xp - level_start(level), level_start(level + 1) - level_start(level)]


static func unlock_level(weapon_id: int) -> int:
	return int(UNLOCKS.get(weapon_id, 1))


static func is_unlocked(weapon_id: int, level: int) -> bool:
	return level >= unlock_level(weapon_id)


## 정확히 이 레벨에서 풀리는 무기 번호들.
static func unlocked_at(level: int) -> Array:
	var found: Array = []
	for weapon_id: int in UNLOCKS:
		if int(UNLOCKS[weapon_id]) == level:
			found.append(weapon_id)
	return found


## 판 결과에 따른 경험치.
static func match_xp(own_score: int, other_score: int) -> int:
	if own_score > other_score:
		return WIN_XP
	return DRAW_XP if own_score == other_score else LOSS_XP


static func saved_xp() -> int:
	return maxi(int(Settings.read(XP_KEY, 0)), 0)


static func saved_level() -> int:
	return level_for(saved_xp())


## 저장된 주무기가 아직 잠겨 있으면 처음부터 쓸 수 있는 총으로 바꾼다.
static func allowed_primary(weapon_id: int, fallback: int) -> int:
	return weapon_id if is_unlocked(weapon_id, saved_level()) else fallback
