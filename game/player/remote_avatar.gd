extends Node3D
## 다른 플레이어의 모습. 서버 스냅샷을 버퍼에 쌓고 조금 과거 시점으로 보간해 부드럽게 그린다.
## 임시 상자 모델이며 M3에서 캐릭터 모델로 교체한다.

const HitMath := preload("res://game/combat/hit_math.gd")
const SHOT_SOUND := preload("res://game/audio/sfx/shot_rifle.ogg")
const MAX_SAMPLES := 40

var alive := true
var low := false

## 각 항목은 [서버 틱, 위치, yaw, low, alive].
var _samples: Array = []
var _body: MeshInstance3D
var _head: MeshInstance3D
var _material := StandardMaterial3D.new()
var _shot_audio: AudioStreamPlayer3D


func _ready() -> void:
	build()


## 임시 모델을 만든다. 트리에 넣지 않고 쓰는 테스트에서도 호출할 수 있다.
func build() -> void:
	if _body != null:
		return
	_material.albedo_color = Color(0.75, 0.25, 0.2)
	_body = _add_part(Vector3(0.6, 1.0, 0.35), _material)
	_head = _add_part(Vector3(0.28, 0.28, 0.28), _material)
	_apply_height()
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
	if low != is_low:
		low = is_low
		_apply_height()


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
	if low != bool(older[3]):
		low = older[3]
		_apply_height()


func _apply_height() -> void:
	var height := HitMath.LOW_HEIGHT if low else HitMath.STAND_HEIGHT
	var body_height := height - 0.28
	(_body.mesh as BoxMesh).size.y = body_height
	_body.position.y = body_height / 2.0
	_head.position.y = height - 0.14


func _add_part(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	add_child(part)
	return part
