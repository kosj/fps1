extends RefCounted
## 한 틱의 플레이어 입력. 클라이언트가 만들어 서버로 보내고, 양쪽이 같은 입력으로 시뮬레이션한다.

const JUMP := 1
const SPRINT := 2
const CROUCH := 4
const FIRE := 8
const AIM := 16
const RELOAD := 32
const ALL_BUTTONS := 63
const PITCH_LIMIT := 1.55

var seq := 0
## x: 좌우, y: 전후(전진이 -1).
var move := Vector2.ZERO
var yaw := 0.0
var pitch := 0.0
var buttons := 0
## 이 입력을 만들 때 클라이언트가 다른 플레이어를 그리던 서버 틱. 지연 보상에 쓴다.
var view_tick := 0.0


func has(flag: int) -> bool:
	return (buttons & flag) != 0


func to_array() -> Array:
	return [seq, move, yaw, pitch, buttons, view_tick]


## 네트워크로 받은 배열을 검증해 입력으로 바꾼다. 형식이 틀리면 null.
## 클라이언트는 신뢰할 수 없으므로 범위를 벗어난 값은 잘라 낸다.
static func from_array(data: Array) -> RefCounted:
	if data.size() != 6:
		return null
	if typeof(data[0]) != TYPE_INT or typeof(data[4]) != TYPE_INT:
		return null
	if typeof(data[1]) != TYPE_VECTOR2:
		return null
	for index: int in [2, 3, 5]:
		var kind := typeof(data[index])
		if kind != TYPE_FLOAT and kind != TYPE_INT:
			return null
		if not is_finite(float(data[index])):
			return null
	var raw_move: Vector2 = data[1]
	if not raw_move.is_finite():
		return null
	var cmd = new()
	cmd.seq = data[0]
	cmd.move = raw_move.limit_length(1.0)
	cmd.yaw = wrapf(float(data[2]), -PI, PI)
	cmd.pitch = clampf(float(data[3]), -PITCH_LIMIT, PITCH_LIMIT)
	cmd.buttons = int(data[4]) & ALL_BUTTONS
	cmd.view_tick = float(data[5])
	return cmd
