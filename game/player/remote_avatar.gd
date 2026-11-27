extends Node3D
## 다른 플레이어의 모습. 서버 스냅샷을 버퍼에 쌓고 조금 과거 시점으로 보간해 부드럽게 그린다.
## 모델은 tools/asset_pipeline/build_soldier.py로 만든 관절별 부품이고,
## 걷기·앉기·총 드는 자세는 부품 회전으로 만든다(game/player/avatar_pose.gd).

const HitMath := preload("res://game/combat/hit_math.gd")
const AvatarPose := preload("res://game/player/avatar_pose.gd")
const SOLDIER := preload("res://game/player/models/soldier.glb")
const RIFLE := preload("res://game/weapons/models/rifle_vk7.glb")
const SHOT_SOUND := preload("res://game/audio/sfx/shot_rifle.ogg")
const MAX_SAMPLES := 40
const UNIFORM_SLOT := "uniform"

var alive := true
var low := false

## 각 항목은 [서버 틱, 위치, yaw, low, alive].
var _samples: Array = []
var _model: Node3D
var _pose: AvatarPose
var _material := StandardMaterial3D.new()
var _shot_audio: AudioStreamPlayer3D
var _last_position := Vector3.ZERO
var _has_last := false


func _ready() -> void:
	build()


func _process(delta: float) -> void:
	if _pose == null or not visible:
		return
	# 보간된 위치(또는 붙어 있는 플레이어)의 실제 이동에서 속도를 구해 걸음을 맞춘다.
	var now := global_position
	var speed := 0.0
	if _has_last and delta > 0.0:
		speed = Vector2(now.x - _last_position.x, now.z - _last_position.z).length() / delta
	_last_position = now
	_has_last = true
	_pose.update(delta, speed, low)


## 모델을 만든다. 트리에 넣지 않고 쓰는 테스트에서도 호출할 수 있다.
func build() -> void:
	if _model != null:
		return
	_material.albedo_color = Color(0.75, 0.25, 0.2)
	_material.roughness = 0.85
	_model = SOLDIER.instantiate() as Node3D
	add_child(_model)
	for found in _model.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		for surface in part.mesh.get_surface_count():
			if part.mesh.surface_get_material(surface).resource_name == UNIFORM_SLOT:
				part.set_surface_override_material(surface, _material)
	_pose = AvatarPose.new()
	_pose.bind(_model, RIFLE.instantiate() as Node3D)
	_pose.update(0.0, 0.0, low)
	# 거리와 방향이 들리는 3D 총소리. 적의 위치를 귀로 알 수 있게 한다.
	_shot_audio = AudioStreamPlayer3D.new()
	_shot_audio.stream = SHOT_SOUND
	_shot_audio.unit_size = 14.0
	_shot_audio.max_distance = 110.0
	_shot_audio.max_polyphony = 4
	_shot_audio.position.y = 1.4
	add_child(_shot_audio)


func play_shot() -> void:
	if _shot_audio != null and _shot_audio.is_inside_tree():
		_shot_audio.play()


func set_color(color: Color) -> void:
	_material.albedo_color = color


## 보간 없이 자세만 바로 반영한다. 같은 프로세스에 있는 플레이어(봇)에 붙여 쓸 때 사용한다.
func set_pose(is_low: bool, is_alive: bool) -> void:
	alive = is_alive
	visible = is_alive
	low = is_low


func push(tick: int, at: Vector3, yaw: float, is_low: bool, is_alive: bool) -> void:
	if not _samples.is_empty() and tick <= int(_samples.back()[0]):
		return
	_samples.append([tick, at, yaw, is_low, is_alive])
	if _samples.size() > MAX_SAMPLES:
		_samples.pop_front()


## render_tick 시점의 모습으로 갱신한다. 최신 스냅샷보다 앞서면 예측하지 않고 최신 위치에 둔다.
func sample(render_tick: float) -> void:
	if _samples.is_empty():
		return
	var newer: Array = _samples.back()
	var older: Array = _samples.front()
	for index in range(_samples.size() - 1, -1, -1):
		var entry: Array = _samples[index]
		if float(entry[0]) <= render_tick:
			older = entry
			newer = _samples[mini(index + 1, _samples.size() - 1)]
			break
		newer = entry
	var span := float(newer[0]) - float(older[0])
	var weight := 0.0
	if span > 0.0:
		weight = clampf((render_tick - float(older[0])) / span, 0.0, 1.0)
	var from: Vector3 = older[1]
	var to: Vector3 = newer[1]
	position = from.lerp(to, weight)
	rotation.y = lerp_angle(float(older[2]), float(newer[2]), weight)
	alive = older[4]
	visible = alive
	low = older[3]
