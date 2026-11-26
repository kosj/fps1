extends RefCounted
## 물리 엔진을 거치지 않는 탄 판정 계산.
## 서버가 지연 보상으로 과거 위치를 되감아 판정할 때 쓴다. 순수 계산이라 결과가 항상 같고 테스트하기 쉽다.

const STAND_HEIGHT := 1.8
const LOW_HEIGHT := 1.1
const BODY_HALF_WIDTH := 0.3
const HEAD_HALF := 0.14


## 광선과 축 정렬 상자의 교차 거리. 맞지 않으면 -1.
static func ray_box(origin: Vector3, direction: Vector3, center: Vector3, half: Vector3) -> float:
	var near := 0.0
	var far := INF
	for axis in 3:
		var offset: float = origin[axis] - center[axis]
		var slope: float = direction[axis]
		var extent: float = half[axis]
		if absf(slope) < 0.0000001:
			if absf(offset) > extent:
				return -1.0
			continue
		var first := (-extent - offset) / slope
		var second := (extent - offset) / slope
		near = maxf(near, minf(first, second))
		far = minf(far, maxf(first, second))
		if near > far:
			return -1.0
	return near


## 발 위치가 feet인 플레이어에 대한 판정. [거리, 헤드샷 여부]를 돌려주고 빗나가면 거리가 -1.
## 머리와 몸통을 모두 지나면 먼저 닿는 쪽을 택한다.
static func player_hit(origin: Vector3, direction: Vector3, feet: Vector3, low: bool) -> Array:
	var height := LOW_HEIGHT if low else STAND_HEIGHT
	var head_bottom := height - HEAD_HALF * 2.0
	var body_center := feet + Vector3(0.0, head_bottom / 2.0, 0.0)
	var body_half := Vector3(BODY_HALF_WIDTH, head_bottom / 2.0, BODY_HALF_WIDTH)
	var head_center := feet + Vector3(0.0, height - HEAD_HALF, 0.0)
	var head_half := Vector3(HEAD_HALF, HEAD_HALF, HEAD_HALF)
	var body := ray_box(origin, direction, body_center, body_half)
	var head := ray_box(origin, direction, head_center, head_half)
	if head >= 0.0 and (body < 0.0 or head <= body):
		return [head, true]
	return [body, false]
