extends Node3D
## 화면 캡처 도구. 실제 맵에 플레이어를 세우고 무기별로 지향/정조준 화면을 PNG로 저장한다.
## 사람이 보는 화면을 사람이 없는 환경에서 확인하기 위한 것으로, 창이 필요하다(xvfb 가능).
## 실행: godot res://tests/shots/shots.tscn -- --out=build/shots

const PLAYER_SCENE := preload("res://game/player/player.tscn")
const MAP_SCENE := preload("res://maps/depot/depot.tscn")
const Armory := preload("res://game/weapons/armory.gd")
const RemoteAvatar := preload("res://game/player/remote_avatar.gd")
const SETTLE_FRAMES := 50

## 찍을 무기: 주무기 네 가지와 권총(game/weapons/armory.gd 번호).
var _weapons := [0, 1, 2, 3, 4]
var _player: CharacterBody3D
var _out := "build/shots"
var _frame := 0
var _step := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--weapons="):
			# 일부 무기만 찍는다: --weapons=4 또는 --weapons=0,4
			var listed := arg.trim_prefix("--weapons=").split(",")
			_weapons = Array(listed).map(func(x: String) -> int: return int(x))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var map := MAP_SCENE.instantiate()
	add_child(map)
	_player = PLAYER_SCENE.instantiate()
	_player.set("require_mouse_capture", false)
	var spawn: Vector3 = Vector3(0.0, 0.2, 0.0)
	if map.has_method("spawn_points"):
		var points: Array = map.call("spawn_points", 0)
		if not points.is_empty():
			spawn = (points[0] as Transform3D).origin + Vector3.UP * 0.1
			_player.rotation.y = (points[0] as Transform3D).basis.get_euler().y
	_player.position = spawn
	add_child(_player)
	# 3인칭 모습 확인용: 앞쪽에 서 있는 적, 앉은 아군, 걷는 적을 세운다.
	var forward := -_player.global_transform.basis.z
	var right := _player.global_transform.basis.x
	_add_avatar(spawn + forward * 4.0 - right * 1.6, 0.6, false, Color(0.75, 0.25, 0.2), 0.0)
	_add_avatar(spawn + forward * 4.5 + right * 0.2, 2.6, true, Color(0.25, 0.45, 0.8), 0.0)
	_add_avatar(spawn + forward * 5.0 + right * 2.0, -1.2, false, Color(0.75, 0.25, 0.2), 2.5)


func _add_avatar(at: Vector3, yaw: float, low: bool, color: Color, speed: float) -> void:
	var avatar := RemoteAvatar.new()
	add_child(avatar)
	avatar.global_position = at
	avatar.rotation.y = _player.rotation.y + yaw
	avatar.set_color(color)
	avatar.set_pose(low, true)
	if speed > 0.0:
		# 제자리 달리기: 동작만 보려고 달리기 클립을 직접 재생한다.
		avatar.set_process(false)
		(avatar.get("_animation") as AnimationPlayer).play("run_f")


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	_frame = 0
	var weapon := _step / 2
	var aimed := _step % 2 == 1
	if _step > 0:
		_save("%d_%s" % [(_step - 1) / 2 + 1, "ads" if (_step - 1) % 2 == 1 else "hip"])
	if weapon == _weapons.size() and not aimed:
		# 효과 확인용: 소총으로 쏘는 중의 화면. 화염은 한 프레임뿐이라 캡처용으로 길게 켠다.
		Input.action_release("aim")
		_equip(_weapons[0])
		Input.action_press("fire")
		get_tree().create_timer(0.6).timeout.connect(_hold_flash)
		_step += 1
		return
	if weapon >= _weapons.size():
		Input.action_release("fire")
		get_tree().quit()
		return
	if aimed:
		Input.action_press("aim")
	else:
		Input.action_release("aim")
		_equip(_weapons[weapon])
	_step += 1


## 무기를 든다: 주무기는 로드아웃을 바꾸고 1번, 권총은 2번.
func _equip(id: int) -> void:
	Input.action_release("weapon_1")
	Input.action_release("weapon_2")
	if Armory.is_primary(id):
		_player.call("set_primary", id)
		Input.action_press("weapon_1")
	else:
		Input.action_press("weapon_2")


func _hold_flash() -> void:
	var view: Node = _player.get("view_model")
	view.set("_flash_left", 30.0)
	view.set("_eject_left", 30.0)


func _save(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	image.save_png(path)
	print("SHOT ", path)
