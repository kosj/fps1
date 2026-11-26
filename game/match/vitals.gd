extends RefCounted
## 체력 회복과 리스폰 보호 규칙. 순수 계산이라 서버와 로컬 대전이 함께 쓴다.

## 마지막으로 맞은 뒤 이 시간(초)이 지나면 체력이 차오른다.
const REGEN_DELAY := 5.0
## 초당 회복량.
const REGEN_RATE := 25.0
## 리스폰 직후 피해를 받지 않는 시간(초). 먼저 쏘면 바로 풀린다.
const SPAWN_PROTECTION := 1.5


static func regenerate(
	health: float, max_health: float, since_damage: float, delta: float
) -> float:
	if health <= 0.0 or since_damage < REGEN_DELAY:
		return health
	return minf(health + REGEN_RATE * delta, max_health)
