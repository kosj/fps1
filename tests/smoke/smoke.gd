extends Node3D
## 헤드리스 통합 테스트.
## 실제 플레이어 씬을 물리와 함께 돌려 이동, 사격, 재장전, 슬라이딩, 난간 넘기를 순서대로 확인한다.
## 실행: godot --headless --fixed-fps 60 res://tests/smoke/smoke.tscn

const PLAYER_SCENE := preload("res://game/player/player.tscn")
const TargetDummy := preload("res://game/combat/target_dummy.gd")
const ACTIONS := [
	"move_forward", "move_back", "move_left", "move_right",
	"jump", "sprint", "crouch", "reload", "fire", "aim", "weapon_3",
]
const LEDGE_HEIGHT := 1.0

var _player: CharacterBody3D
var _dummy: TargetDummy
var _tick := 0
var _failures := PackedStringArray()
var _start_z := 0.0
var _saw_slide := false
var _saw_mantle := false
var _shots_before := 0
var _hits_before := 0


func _ready() -> void:
	_add_box(Vector3(0.0, -0.5, 0.0), Vector3(200.0, 1.0, 200.0))
	# 난간 넘기용 상자: 앞면이 x=40 지점에서 z=-0.5에 온다.
	_add_box(Vector3(40.0, LEDGE_HEIGHT / 2.0, -1.5), Vector3(3.0, LEDGE_HEIGHT, 2.0))
	_dummy = TargetDummy.new()
	_dummy.position = Vector3(0.0, 0.0, -30.0)
	add_child(_dummy)
	_player = PLAYER_SCENE.instantiate()
	_player.set("require_mouse_capture", false)
	_player.position = Vector3(0.0, 0.05, 0.0)
	add_child(_player)


func _physics_process(_delta: float) -> void:
	_tick += 1
	_watch_states()
	match _tick:
		20:
			_start_z = _player.global_position.z
			Input.action_press("move_forward")
		80:
			Input.action_release("move_forward")
			var walked := _start_z - _player.global_position.z
			_expect(walked > 3.0, "walking forward for 1 s moved less than 3 m")
			Input.action_press("aim")
		100:
			Input.action_press("fire")
		130:
			Input.action_release("fire")
			Input.action_release("aim")
		135:
			_check_shooting()
			Input.action_press("reload")
		137:
			Input.action_release("reload")
			_expect(_weapon_state().phase == 1, "reload did not start")
		270:
			_expect(_weapon_state().ammo == 30, "magazine was not refilled after reload")
			Input.action_press("sprint")
			Input.action_press("move_forward")
		310:
			_expect(_player.call("is_sprinting"), "player is not sprinting")
			Input.action_press("crouch")
		316:
			Input.action_release("crouch")
			Input.action_release("sprint")
			Input.action_release("move_forward")
		420:
			_expect(_saw_slide, "crouching while sprinting did not start a slide")
			_expect(_player.get("move_state") == 0, "slide never ended")
			_player.global_position = Vector3(40.0, 0.05, 0.0)
			_player.velocity = Vector3.ZERO
		440:
			Input.action_press("jump")
		442:
			Input.action_release("jump")
		500:
			_expect(_saw_mantle, "jumping at a 1 m ledge did not start a mantle")
			var position_now := _player.global_position
			_expect(absf(position_now.y - LEDGE_HEIGHT) < 0.15, "player is not standing on the ledge")
			_expect(position_now.z < -0.6, "player did not move onto the ledge")
		505:
			# 산탄총으로 바꿔 5 m 앞 더미를 쏜다.
			_player.global_position = Vector3(0.0, 0.05, -25.0)
			_player.velocity = Vector3.ZERO
			Input.action_press("weapon_3")
		507:
			Input.action_release("weapon_3")
		550:
			var weapon: Node = _player.get("weapon")
			_expect(weapon.get("slot") == 2, "pressing 3 did not switch to the shotgun")
			_shots_before = weapon.get("shots_fired")
			_hits_before = weapon.get("hits_landed")
			Input.action_press("fire")
		552:
			Input.action_release("fire")
		570:
			var weapon: Node = _player.get("weapon")
			var shots: int = weapon.get("shots_fired") - _shots_before
			var hits: int = weapon.get("hits_landed") - _hits_before
			_expect(shots == 1, "one trigger pull fired %d shotgun shells" % shots)
			_expect(hits >= 2, "only %d of 8 pellets hit a dummy 5 m away" % hits)
			print("smoke: shotgun landed %d of 8 pellets" % hits)
		572:
			_player.call("set_touch", true)
		578:
			_expect(_player.get("touch") != null, "set_touch did not create touch controls")
			_expect(_player.call("input_active"), "touch controls should be active when not paused")
			# 버튼은 화면 크기를 기준으로 놓이므로, 크기가 0이면 전부 화면 밖에 그려진다.
			var touch_area: Vector2 = (_player.get("touch") as Control).size
			_expect(touch_area.x > 100.0 and touch_area.y > 100.0, "touch controls have no area")
			_player.call("set_paused", true)
			_expect(not _player.call("input_active"), "paused touch controls still accept input")
		580:
			_finish()


func _watch_states() -> void:
	var move_state: int = _player.get("move_state")
	if move_state == 1:
		_saw_slide = true
	elif move_state == 2:
		_saw_mantle = true


func _check_shooting() -> void:
	var weapon: Node = _player.get("weapon")
	var shots: int = weapon.get("shots_fired")
	var hits: int = weapon.get("hits_landed")
	_expect(shots >= 5 and shots <= 7, "expected 5-7 shots in 0.5 s, got %d" % shots)
	_expect(_weapon_state().ammo == 30 - shots, "ammo does not match shots fired")
	_expect(hits >= 1, "no shot hit the dummy 30 m ahead while aiming")
	_expect(_dummy.damage_taken > 0.0, "dummy took no damage")
	var pitch: float = _player.get_node("Head").rotation.x
	_expect(pitch > 0.001, "recoil did not raise the view")
	print("smoke: %d shots, %d hits, %.1f damage" % [shots, hits, _dummy.damage_taken])


func _weapon_state() -> RefCounted:
	var weapon: Node = _player.get("weapon")
	return weapon.get("state")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("tick %d: %s" % [_tick, message])


func _finish() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)
	for failure in _failures:
		printerr("SMOKE FAIL ", failure)
	print("smoke: %d failures" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _add_box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
