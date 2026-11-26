extends RefCounted
## 감쇠 스프링. 뷰모델 반동과 흔들림처럼 목표값으로 부드럽게 돌아가는 움직임에 쓴다.

const MAX_STEP := 1.0 / 120.0

var value := Vector3.ZERO
var velocity := Vector3.ZERO
var stiffness := 120.0
var damping := 18.0


func _init(p_stiffness: float = 120.0, p_damping: float = 18.0) -> void:
	stiffness = p_stiffness
	damping = p_damping


func add_impulse(impulse: Vector3) -> void:
	velocity += impulse


## 프레임 시간이 길어도 발산하지 않도록 작은 단계로 나눠 적분한다.
func update(target: Vector3, delta: float) -> Vector3:
	var remaining := minf(delta, 0.25)
	while remaining > 0.0:
		var step := minf(remaining, MAX_STEP)
		var accel := (target - value) * stiffness - velocity * damping
		velocity += accel * step
		value += velocity * step
		remaining -= step
	return value
