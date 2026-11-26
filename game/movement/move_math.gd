extends RefCounted
## 렌더링과 분리된 이동 계산.
## 서버, 클라이언트 예측, 봇, 단위 테스트가 같은 코드를 쓰도록 노드에 의존하지 않는다.

const WALK_SPEED := 5.0
const SPRINT_SPEED := 7.5
const JUMP_VELOCITY := 4.5
const GROUND_ACCEL := 60.0
const AIR_ACCEL := 12.0


## 입력 방향(x: 좌우, y: 전후, 전진이 -1)과 시선 yaw로 목표 수평 속도를 구한다.
## 달리기는 전진 중일 때만 적용한다.
static func wish_velocity(input_dir: Vector2, yaw: float, sprinting: bool) -> Vector3:
	var dir := Vector3(input_dir.x, 0.0, input_dir.y)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	var speed := WALK_SPEED
	if sprinting and input_dir.y < 0.0:
		speed = SPRINT_SPEED
	return dir.rotated(Vector3.UP, yaw) * speed


## 현재 속도의 수평 성분을 목표 속도 쪽으로 가속한다. 수직 성분은 건드리지 않는다.
static func accelerate(current: Vector3, target: Vector3, on_floor: bool, delta: float) -> Vector3:
	var accel := AIR_ACCEL
	if on_floor:
		accel = GROUND_ACCEL
	var horizontal := Vector3(current.x, 0.0, current.z)
	horizontal = horizontal.move_toward(Vector3(target.x, 0.0, target.z), accel * delta)
	return Vector3(horizontal.x, current.y, horizontal.z)
