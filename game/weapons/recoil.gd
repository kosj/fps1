extends RefCounted
## 시점 반동. 발사마다 킥을 누적하고 시간이 지나면 0으로 돌아온다.
## 사용하는 쪽은 프레임마다 offset의 변화량만 시점에 더한다.
## 그래야 플레이어가 마우스로 눌러 준 보정이 반동 회복 뒤에도 남는다.

const FOLLOW_SPEED := 25.0

## 현재 시점 오프셋(도). x: 좌우, y: 상승.
var offset := Vector2.ZERO

var _target := Vector2.ZERO


func add_kick(kick_deg: Vector2) -> void:
	_target += kick_deg


## 목표 킥은 서서히 풀리고, 실제 오프셋은 목표를 빠르게 따라간다.
func update(delta: float, recovery: float) -> Vector2:
	_target = _target.lerp(Vector2.ZERO, clampf(recovery * delta, 0.0, 1.0))
	offset = offset.lerp(_target, clampf(FOLLOW_SPEED * delta, 0.0, 1.0))
	return offset
