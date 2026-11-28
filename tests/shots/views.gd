extends Node3D
## 맵 그래픽 비교용 고정 시점 캡처. 그래픽을 다듬기 전후를 같은 자리에서 비교한다.
## 실행: godot --rendering-driver opengl3 res://tests/shots/views.tscn -- --map=depot --out=/tmp/views
const Catalog := preload("res://maps/catalog.gd")
const LaunchArgs := preload("res://game/core/launch_args.gd")
const RemoteAvatar := preload("res://game/player/remote_avatar.gd")
const Dressing := preload("res://maps/dressing.gd")
## 맵마다 [카메라 자리, 바라보는 곳].
const VIEWS := {
	"depot": [
		[Vector3(-26, 24, 46), Vector3(0, 0, 0)],
		[Vector3(0, 1.6, 34), Vector3(0, 1.4, 10)],
		[Vector3(-22, 1.6, 12), Vector3(-5, 1.6, -6)],
		[Vector3(18, 1.6, -4), Vector3(28, 3.0, -30)],
	],
	"compound": [
		[Vector3(-26, 22, 40), Vector3(0, 0, 0)],
		[Vector3(0, 1.6, 27.5), Vector3(0, 1.4, 0)],
		[Vector3(-22, 1.6, 7), Vector3(-8, 1.4, 0)],
		[Vector3(6, 1.6, -4.5), Vector3(-4, 1.2, 6)],
	],
}
var _frame := 0
var _view := 0
var _cam: Camera3D
var _views: Array
var _out := "/tmp/views"
var _map_name := "depot"


func _ready() -> void:
	var args := LaunchArgs.parse()
	_map_name = str(args.get("map", "depot"))
	_out = str(args.get("out", _out))
	DirAccess.make_dir_recursive_absolute(_out)
	_views = VIEWS[_map_name]
	var map := (load(Catalog.path(_map_name)) as PackedScene).instantiate()
	add_child(map)
	# 마지막 장은 하늘 사진 속 해를 바라본다: 해와 그림자 방향이 맞는지 확인한다.
	var sun_uv: Vector2 = map.get_script().get_script_constant_map().get("SKY_SUN", Vector2.ZERO)
	if sun_uv != Vector2.ZERO:
		var eye := Vector3(0, 30, 0)
		_views = _views + [[eye, eye + Dressing.sky_direction(sun_uv) * 10.0]]
	# 크기 비교용 군인 둘.
	for spot: Vector3 in [Vector3(-3, 0, 22), Vector3(4, 0, 14)]:
		var soldier := RemoteAvatar.new()
		add_child(soldier)
		soldier.position = spot
	_cam = Camera3D.new()
	_cam.fov = 75
	add_child(_cam)
	_aim()


func _aim() -> void:
	_cam.position = _views[_view][0]
	_cam.look_at(_views[_view][1])


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < 14:
		return
	_frame = 0
	get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [_out, _map_name, _view])
	_view += 1
	if _view >= _views.size():
		get_tree().quit()
		return
	_aim()
