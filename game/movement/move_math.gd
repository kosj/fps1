extends RefCounted
## 렌더링과 분리된 이동 계산.
## 서버, 클라이언트 예측, 봇, 단위 테스트가 같은 코드를 쓰도록 노드에 의존하지 않는다.

const WALK_SPEED := 5.0
const SPRINT_SPEED := 7.5
const CROUCH_SPEED := 2.8
const JUMP_VELOCITY := 4.5
const GROUND_ACCEL := 60.0
const AIR_ACCEL := 12.0

const SLIDE_MIN_ENTRY_SPEED := 6.0
const SLIDE_START_SPEED := 9.5
const SLIDE_FRICTION := 7.0
const SLIDE_END_SPEED := 3.2
const SLIDE_MAX_TIME := 0.9

const MANTLE_MIN_HEIGHT := 0.4
const MANTLE_MAX_HEIGHT := 1.5
const MANTLE_TIME := 0.3


## 입력 방향(x: 좌우, y: 전후, 전진이 -1)과 시선 yaw로 목표 수평 속도를 구한다.
## 달리기는 전진 중일 때만 적용하고, 앉은 상태가 달리기보다 우선한다.
static func wish_velocity(
	input_dir: Vector2, yaw: float, sprinting: bool, crouching: bool = false
) -> Vector3:
	var dir := Vector3(input_dir.x, 0.0, input_dir.y)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting and input_dir.y < 0.0:
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


static func can_start_slide(horizontal_speed: float) -> bool:
	return horizontal_speed >= SLIDE_MIN_ENTRY_SPEED


## 슬라이딩 시작 속도. 진행 방향은 유지하고 속력만 끌어올린다.
static func slide_start_velocity(current: Vector3) -> Vector3:
	var horizontal := Vector3(current.x, 0.0, current.z)
	var speed := maxf(horizontal.length(), SLIDE_START_SPEED)
	horizontal = horizontal.normalized() * speed
	return Vector3(horizontal.x, current.y, horizontal.z)


## 슬라이딩 중 마찰로 감속한다.
static func slide_step(current: Vector3, delta: float) -> Vector3:
	var horizontal := Vector3(current.x, 0.0, current.z)
	horizontal = horizontal.move_toward(Vector3.ZERO, SLIDE_FRICTION * delta)
	return Vector3(horizontal.x, current.y, horizontal.z)


static func slide_finished(horizontal_speed: float, elapsed: float) -> bool:
	return horizontal_speed <= SLIDE_END_SPEED or elapsed >= SLIDE_MAX_TIME


## 발 기준 난간 높이가 넘을 수 있는 범위인지.
static func can_mantle(ledge_height: float) -> bool:
	return ledge_height >= MANTLE_MIN_HEIGHT and ledge_height <= MANTLE_MAX_HEIGHT


## 난간 넘기 경로. 먼저 위로 오르고 뒤이어 앞으로 넘어간다. progress는 0~1.
static func mantle_position(from: Vector3, to: Vector3, progress: float) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	var rise := minf(t * 1.5, 1.0)
	var advance := smoothstep(0.3, 1.0, t)
	var x := lerpf(from.x, to.x, advance)
	var y := lerpf(from.y, to.y, rise)
	var z := lerpf(from.z, to.z, advance)
	return Vector3(x, y, z)
