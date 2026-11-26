extends RefCounted
## 터치 조작용 조준 보조. 마우스보다 정밀도가 낮은 엄지 조작을 보완한다.
## - 감속: 조준선이 적 근처에 있으면 시선 이동이 느려져 지나치지 않게 한다.
## - 당김: 적이 조준선 가까이에 있으면 시선이 적 쪽으로 천천히 끌린다. 정확히 맞추면 멈춘다.
## 벽 너머의 적에게는 작동하지 않도록, 보이는 적만 넘겨받는다.

## 이 각도(라디안) 안에 들어온 적에게만 작동한다. 0.105는 약 6도.
const CONE := 0.105
## 이 각도 안이면 이미 조준된 것으로 보고 더 당기지 않는다.
const INNER := 0.012
const MAX_RANGE := 45.0
const SLOWDOWN := 0.5
const PULL_SPEED := 0.9


## [시선 감도 배율, yaw 당김 속도(rad/s), pitch 당김 속도(rad/s)]를 돌려준다.
## targets는 보이는 적들의 가슴 위치.
static func evaluate(eye: Vector3, yaw: float, pitch: float, targets: Array) -> Array:
	var best := CONE
	var best_yaw := 0.0
	var best_pitch := 0.0
	var found := false
	for target: Vector3 in targets:
		var offset := target - eye
		var distance := offset.length()
		if distance > MAX_RANGE or distance < 0.5:
			continue
		var yaw_error := angle_difference(yaw, atan2(-offset.x, -offset.z))
		var pitch_error := atan2(offset.y, Vector2(offset.x, offset.z).length()) - pitch
		var miss := sqrt(yaw_error * yaw_error + pitch_error * pitch_error)
		if miss < best:
			best = miss
			best_yaw = yaw_error
			best_pitch = pitch_error
			found = true
	if not found:
		return [1.0, 0.0, 0.0]
	var closeness := 1.0 - best / CONE
	var slow := lerpf(1.0, SLOWDOWN, closeness)
	if best <= INNER:
		return [slow, 0.0, 0.0]
	var pull := PULL_SPEED * closeness
	return [slow, clampf(best_yaw * 4.0, -pull, pull), clampf(best_pitch * 4.0, -pull, pull)]
