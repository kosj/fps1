extends Node3D
## 맵의 트인 정도를 잰다: 양 팀 진영과 가운데 사이(4 <= |z| <= 22 m)의 바닥에 3 m 간격 점을 깔고,
## 45 m 안의 맞은편 점 쌍 중 눈높이(1.6 m)에서 서로 보이는 비율을 출력한다.
## 맵을 고칠 때 비교용(Depot 0.43, Compound 0.15, Outpost 0.23).
## 실행: godot --headless --fixed-fps 60 res://tests/shots/sightlines.tscn -- --map=outpost

const Catalog := preload("res://maps/catalog.gd")
const LaunchArgs := preload("res://game/core/launch_args.gd")
const EYE := 1.6
const STEP := 3
const NEAR_Z := 4.0
const FAR_Z := 22.0
const MAX_DISTANCE := 45.0

var _map: Node3D
var _tick := 0


func _ready() -> void:
	var map_name := str(LaunchArgs.parse().get("map", "depot"))
	_map = (load(Catalog.path(map_name)) as PackedScene).instantiate()
	add_child(_map)


func _physics_process(_delta: float) -> void:
	_tick += 1
	if _tick != 3:
		return
	var space := get_world_3d().direct_space_state
	var home: Array = []
	var away: Array = []
	for x in range(-30, 31, STEP):
		for z in range(-40, 41, STEP):
			var spot := Vector3(x, EYE, z)
			if not _open_floor(space, spot):
				continue
			if z >= NEAR_Z and z <= FAR_Z:
				home.append(spot)
			elif z <= -NEAR_Z and z >= -FAR_Z:
				away.append(spot)
	var seen := 0
	var total := 0
	for a: Vector3 in home:
		for b: Vector3 in away:
			if a.distance_to(b) > MAX_DISTANCE:
				continue
			total += 1
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b)).is_empty():
				seen += 1
	var share := float(seen) / maxi(total, 1)
	print("sightlines %s: %d pairs, %.2f visible" % [_map.name, total, share])
	get_tree().quit()


## 맨바닥이고(구조물 위가 아니고) 눈높이가 구조물 속이 아닌 자리.
func _open_floor(space: PhysicsDirectSpaceState3D, spot: Vector3) -> bool:
	var below := Vector3(spot.x, -0.5, spot.z)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot, below))
	if hit.is_empty() or (hit["position"] as Vector3).y > 0.05:
		return false
	var inside := PhysicsPointQueryParameters3D.new()
	inside.position = spot
	return space.intersect_point(inside).is_empty()
