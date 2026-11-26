extends CharacterBody3D
## 1인칭 플레이어 컨트롤러.
## 입력을 읽어 MoveMath에 넘기고 결과 속도를 적용한다. 계산 자체는 MoveMath에 둔다.

const MoveMath := preload("res://game/movement/move_math.gd")
const MOUSE_SENSITIVITY := 0.002
const PITCH_LIMIT := 1.55

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _head: Node3D = $Head


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.is_pressed() and not captured:
		# 브라우저는 사용자 클릭이 있어야 포인터 잠금을 허용한다.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and captured:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		var pitch := _head.rotation.x - motion.relative.y * MOUSE_SENSITIVITY
		_head.rotation.x = clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT)


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = MoveMath.JUMP_VELOCITY
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := Input.is_action_pressed("sprint")
	var target: Vector3 = MoveMath.wish_velocity(input_dir, rotation.y, sprinting)
	velocity = MoveMath.accelerate(velocity, target, on_floor, delta)
	move_and_slide()
