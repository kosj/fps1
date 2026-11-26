extends RefCounted
## 정해진 동작을 반복하는 단순 봇. 자동 테스트에서 사람 대신 입력을 만든다.
## M4에서 전술 판단을 하는 봇으로 확장한다.

const InputCmd := preload("res://game/player/input_cmd.gd")
const STRAFE_PERIOD := 3.0
const AIM_HEIGHT := 1.0
const FIRE_DELAY := 1.0

## "idle", "strafer"(좌우 왕복), "shooter"(가장 가까운 적을 조준 사격),
## "runner"(달리기, 슬라이딩, 점프, 앉기를 섞어 이동 예측을 시험).
var kind := "idle"

var _time := 0.0
var _tracking_time := 0.0


func _init(p_kind: String = "idle") -> void:
	kind = p_kind


## eye는 자기 눈 위치, targets는 화면에 보이는 적들의 발 위치.
func make_cmd(delta: float, eye: Vector3, targets: Array) -> InputCmd:
	_time += delta
	var cmd := InputCmd.new()
	match kind:
		"strafer":
			cmd.move.x = 1.0 if fmod(_time, STRAFE_PERIOD) < STRAFE_PERIOD / 2.0 else -1.0
		"shooter":
			_aim_and_fire(cmd, delta, eye, targets)
		"runner":
			_run_course(cmd)
	return cmd


## 6초 주기로 달리기 → 슬라이딩 → 점프 → 시선을 돌리며 옆걸음 → 앉아서 후진을 반복한다.
func _run_course(cmd: InputCmd) -> void:
	var phase := fmod(_time, 6.0)
	if phase < 1.5:
		cmd.move = Vector2(0.0, -1.0)
		cmd.buttons = InputCmd.SPRINT
	elif phase < 1.7:
		cmd.move = Vector2(0.0, -1.0)
		cmd.buttons = InputCmd.SPRINT | InputCmd.CROUCH
	elif phase < 3.0:
		cmd.move = Vector2(0.0, -1.0)
	elif phase < 3.2:
		cmd.move = Vector2(0.0, -1.0)
		cmd.buttons = InputCmd.JUMP
	elif phase < 4.5:
		cmd.move = Vector2(1.0, 0.0)
		cmd.yaw = 0.8 * sin(_time * 2.0)
	else:
		cmd.move = Vector2(0.0, 1.0)
		cmd.buttons = InputCmd.CROUCH


func _aim_and_fire(cmd: InputCmd, delta: float, eye: Vector3, targets: Array) -> void:
	var best_distance := INF
	var best := Vector3.ZERO
	for target: Vector3 in targets:
		var distance := eye.distance_to(target)
		if distance < best_distance:
			best_distance = distance
			best = target
	if best_distance == INF:
		_tracking_time = 0.0
		return
	var to_target := best + Vector3.UP * AIM_HEIGHT - eye
	cmd.yaw = atan2(-to_target.x, -to_target.z)
	cmd.pitch = atan2(to_target.y, Vector2(to_target.x, to_target.z).length())
	cmd.buttons = InputCmd.AIM
	_tracking_time += delta
	# 정조준이 끝난 뒤부터 쏜다.
	if _tracking_time >= FIRE_DELAY:
		cmd.buttons |= InputCmd.FIRE
