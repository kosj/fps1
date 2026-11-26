extends RefCounted

const MoveMath := preload("res://game/movement/move_math.gd")


func test_forward_input_moves_along_negative_z() -> String:
	var velocity: Vector3 = MoveMath.wish_velocity(Vector2(0.0, -1.0), 0.0, false)
	return _expect_vector(velocity, Vector3(0.0, 0.0, -MoveMath.WALK_SPEED))


func test_diagonal_input_is_not_faster() -> String:
	var velocity: Vector3 = MoveMath.wish_velocity(Vector2(1.0, -1.0), 0.0, false)
	return _expect_float(velocity.length(), MoveMath.WALK_SPEED)


func test_sprint_applies_only_when_moving_forward() -> String:
	var forward: Vector3 = MoveMath.wish_velocity(Vector2(0.0, -1.0), 0.0, true)
	var backward: Vector3 = MoveMath.wish_velocity(Vector2(0.0, 1.0), 0.0, true)
	var message := _expect_float(forward.length(), MoveMath.SPRINT_SPEED)
	if not message.is_empty():
		return message
	return _expect_float(backward.length(), MoveMath.WALK_SPEED)


func test_yaw_rotates_wish_direction() -> String:
	# 왼쪽으로 90도 돌면 전진 입력은 -x 방향이 된다.
	var velocity: Vector3 = MoveMath.wish_velocity(Vector2(0.0, -1.0), PI / 2.0, false)
	return _expect_vector(velocity, Vector3(-MoveMath.WALK_SPEED, 0.0, 0.0))


func test_accelerate_keeps_vertical_velocity() -> String:
	var falling := Vector3(0.0, -3.0, 0.0)
	var result: Vector3 = MoveMath.accelerate(falling, Vector3(5.0, 0.0, 0.0), true, 0.016)
	return _expect_float(result.y, -3.0)


func test_accelerate_step_is_limited_by_acceleration() -> String:
	var delta := 0.01
	var result: Vector3 = MoveMath.accelerate(Vector3.ZERO, Vector3(5.0, 0.0, 0.0), true, delta)
	return _expect_float(result.x, MoveMath.GROUND_ACCEL * delta)


func test_air_acceleration_is_slower_than_ground() -> String:
	var target := Vector3(5.0, 0.0, 0.0)
	var ground: Vector3 = MoveMath.accelerate(Vector3.ZERO, target, true, 0.01)
	var air: Vector3 = MoveMath.accelerate(Vector3.ZERO, target, false, 0.01)
	if air.x >= ground.x:
		return "air step %f should be smaller than ground step %f" % [air.x, ground.x]
	return ""


func _expect_vector(actual: Vector3, expected: Vector3) -> String:
	if actual.distance_to(expected) > 0.001:
		return "expected %s, got %s" % [expected, actual]
	return ""


func _expect_float(actual: float, expected: float) -> String:
	if absf(actual - expected) > 0.001:
		return "expected %f, got %f" % [expected, actual]
	return ""
