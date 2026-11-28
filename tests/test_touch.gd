extends RefCounted
## 터치 조작의 입력 해석. 화면 크기는 기본값 1280x720을 쓴다.

const InputCmd := preload("res://game/player/input_cmd.gd")
const TouchControls := preload("res://game/ui/touch_controls.gd")
const LEFT := Vector2(200.0, 500.0)
const RIGHT := Vector2(800.0, 300.0)
const FIRE := Vector2(1160.0, 590.0)
const JUMP := Vector2(1205.0, 455.0)
const AIM := Vector2(1030.0, 645.0)
const WEAPON := Vector2(1090.0, 420.0)
const PAUSE := Vector2(1242.0, 36.0)
const SCORE := Vector2(1182.0, 36.0)
const FLASH := Vector2(850.0, 560.0)
const MELEE := Vector2(975.0, 435.0)


func test_left_side_drag_moves_and_sprints() -> String:
	var touch := TouchControls.new()
	touch.handle_touch(0, LEFT, true)
	touch.handle_drag(0, LEFT + Vector2(0.0, -40.0), Vector2(0.0, -40.0))
	var message := ""
	if absf(touch.move.y + 0.5) > 0.01 or (touch.buttons() & InputCmd.SPRINT) != 0:
		message = "half push should walk forward without sprinting, move was %s" % touch.move
	touch.handle_drag(0, LEFT + Vector2(0.0, -200.0), Vector2(0.0, -160.0))
	if message.is_empty() and (touch.move.length() > 1.001 or touch.move.y > -0.99):
		message = "full push should clamp to -1, move was %s" % touch.move
	if message.is_empty() and (touch.buttons() & InputCmd.SPRINT) == 0:
		message = "pushing the stick fully forward should sprint"
	touch.handle_touch(0, LEFT, false)
	if message.is_empty() and touch.move != Vector2.ZERO:
		message = "releasing the stick should stop movement"
	touch.free()
	return message


func test_right_side_drag_looks_without_moving() -> String:
	var touch := TouchControls.new()
	var seen: Array = []
	touch.look.connect(func(relative: Vector2) -> void: seen.append(relative))
	touch.handle_touch(1, RIGHT, true)
	touch.handle_drag(1, RIGHT + Vector2(30.0, -10.0), Vector2(30.0, -10.0))
	var message := ""
	if seen.size() != 1 or seen[0] != Vector2(30.0, -10.0):
		message = "right-side drag should report look movement, got %s" % [seen]
	elif touch.move != Vector2.ZERO or touch.buttons() != 0:
		message = "looking should not move or press buttons"
	touch.free()
	return message


func test_fire_button_holds_fire_and_still_looks() -> String:
	var touch := TouchControls.new()
	var seen: Array = []
	touch.look.connect(func(relative: Vector2) -> void: seen.append(relative))
	touch.handle_touch(2, FIRE, true)
	var message := ""
	if (touch.buttons() & InputCmd.FIRE) == 0:
		message = "touching FIRE should fire"
	touch.handle_drag(2, FIRE + Vector2(-20.0, 5.0), Vector2(-20.0, 5.0))
	if message.is_empty() and seen.size() != 1:
		message = "dragging from FIRE should also turn the view"
	touch.handle_touch(2, FIRE, false)
	if message.is_empty() and (touch.buttons() & InputCmd.FIRE) != 0:
		message = "releasing FIRE should stop firing"
	touch.free()
	return message


func test_move_look_and_fire_work_together() -> String:
	var touch := TouchControls.new()
	touch.handle_touch(0, LEFT, true)
	touch.handle_drag(0, LEFT + Vector2(80.0, 0.0), Vector2(80.0, 0.0))
	touch.handle_touch(1, FIRE, true)
	touch.handle_touch(2, JUMP, true)
	var bits := touch.buttons()
	var message := ""
	if touch.move.x < 0.99:
		message = "stick should still read full right with other fingers down"
	elif (bits & InputCmd.FIRE) == 0 or (bits & InputCmd.JUMP) == 0:
		message = "fire and jump should both be pressed, bits were %d" % bits
	# 한 손가락을 떼어도 나머지는 유지된다.
	touch.handle_touch(1, FIRE, false)
	if message.is_empty() and ((touch.buttons() & InputCmd.FIRE) != 0 or touch.move.x < 0.99):
		message = "releasing FIRE should not affect the stick"
	touch.free()
	return message


func test_aim_toggles_and_weapon_button_counts_taps() -> String:
	var touch := TouchControls.new()
	touch.handle_touch(0, AIM, true)
	touch.handle_touch(0, AIM, false)
	var message := ""
	if (touch.buttons() & InputCmd.AIM) == 0:
		message = "tapping AIM should keep aiming after release"
	touch.handle_touch(0, AIM, true)
	touch.handle_touch(0, AIM, false)
	if message.is_empty() and (touch.buttons() & InputCmd.AIM) != 0:
		message = "tapping AIM again should stop aiming"
	touch.handle_touch(0, WEAPON, true)
	touch.handle_touch(0, WEAPON, false)
	touch.handle_touch(0, WEAPON, true)
	touch.handle_touch(0, WEAPON, false)
	if message.is_empty() and touch.take_weapon_steps() != 2:
		message = "two taps on the weapon button should give two steps"
	if message.is_empty() and touch.take_weapon_steps() != 0:
		message = "weapon steps should reset after being read"
	touch.free()
	return message


func test_pause_button_and_release_all() -> String:
	var touch := TouchControls.new()
	var paused: Array = []
	touch.pause_pressed.connect(func() -> void: paused.append(true))
	touch.handle_touch(0, PAUSE, true)
	var message := ""
	if paused.size() != 1:
		message = "tapping the pause button should request a pause"
	touch.handle_touch(1, FIRE, true)
	touch.handle_touch(2, LEFT, true)
	touch.handle_drag(2, LEFT + Vector2(0.0, -80.0), Vector2(0.0, -80.0))
	touch.release_all()
	if message.is_empty() and (touch.buttons() != 0 or touch.move != Vector2.ZERO):
		message = "release_all should clear held buttons and the stick"
	touch.free()
	return message


func test_score_button_holds_the_scoreboard_action() -> String:
	# 게임에서는 game/core/input_setup.gd가 등록한다. 테스트 실행기에는 없으므로 직접 만든다.
	if not InputMap.has_action("scoreboard"):
		InputMap.add_action("scoreboard")
	var touch := TouchControls.new()
	touch.handle_touch(3, SCORE, true)
	var held := Input.is_action_pressed("scoreboard")
	touch.handle_touch(3, SCORE, false)
	var released := not Input.is_action_pressed("scoreboard")
	touch.free()
	if not held:
		return "holding TAB should press the scoreboard action"
	if not released:
		return "letting go of TAB should release the scoreboard action"
	return ""


func test_flash_and_melee_buttons_tap_their_bits() -> String:
	var touch := TouchControls.new()
	touch.handle_touch(4, FLASH, true)
	touch.handle_touch(4, FLASH, false)
	touch.handle_touch(5, MELEE, true)
	touch.handle_touch(5, MELEE, false)
	var bits := touch.buttons()
	touch.free()
	if (bits & InputCmd.TACTICAL) == 0:
		return "tapping FLASH should throw a flashbang"
	if (bits & InputCmd.MELEE) == 0:
		return "tapping MELEE should swing"
	return ""
