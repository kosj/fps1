extends RefCounted
## 정해진 동작을 반복하는 단순 봇. 자동 테스트에서 사람 대신 입력을 만든다.
## M4에서 전술 판단을 하는 봇으로 확장한다.

const InputCmd := preload("res://game/player/input_cmd.gd")
const STRAFE_PERIOD := 3.0
const AIM_HEIGHT := 1.0
const FIRE_DELAY := 1.0

## "idle", "strafer"(좌우 왕복), "shooter"(가장 가까운 적을 조준 사격).
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
	return cmd


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
