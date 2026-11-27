extends Node3D
## 다른 플레이어의 모습. 서버 스냅샷을 버퍼에 쌓고 조금 과거 시점으로 보간해 부드럽게 그린다.
## 모델과 동작은 Varco 3D로 만든 병사(리깅 + 소총 동작 8종)를
## tools/asset_pipeline/merge_character.py로 합친 것이다.

const HitMath := preload("res://game/combat/hit_math.gd")
const Effects := preload("res://game/fx/effects.gd")
const FLASH_TIME := 0.05
const TRACER_LENGTH := 45.0
const SOLDIER := preload("res://game/player/models/soldier.glb")
## 무기 칸 순서. game/player/player.gd의 기본 무장과 같다.
const WEAPONS := [
	preload("res://game/weapons/data/rifle_vk7.tres"),
	preload("res://game/weapons/data/smg_kestrel.tres"),
	preload("res://game/weapons/data/shotgun_m90.tres"),
	preload("res://game/weapons/data/sniper_lr12.tres"),
]
const MAX_SAMPLES := 40
## 모델 원본 키(약 1m)를 히트 판정 키에 맞추는 배율.
const MODEL_HEIGHT := 1.0
const BLEND_TIME := 0.18
const MOVE_THRESHOLD := 0.6
## 달리기 동작이 만들어진 기준 속도(m/s). 실제 속도에 맞춰 재생 속도를 바꾼다.
const RUN_CLIP_SPEED := 4.5
const CROUCH_CLIP_SPEED := 1.6
const DEATH_SHOW_TIME := 3.2
const GRIP_BONE := "RightHand"
const SUPPORT_BONE := "LeftHand"
## 손목 뼈가 손바닥보다 위에 있는 만큼 총을 올린다(m).
const WRIST_LIFT := -0.02

var alive := true
var low := false

## 각 항목은 [서버 틱, 위치, yaw, low, alive].
var _samples: Array = []
var _model: Node3D
var _animation: AnimationPlayer
var _material: StandardMaterial3D
var _tint := Color(0.75, 0.25, 0.2)
var _shot_audio: AudioStreamPlayer3D
var _last_position := Vector3.ZERO
var _has_last := false
var _skeleton: Skeleton3D
var _rifle: Node3D
var _weapon_slot := -1
var _flash: Node3D
var _flash_left := 0.0
## 두 손의 가운데에서 총 원점까지: [총구 방향, 위쪽] (m). 무기마다 다르다.
var _hold_offset := Vector2(-0.1, 0.07)
var _grip_bone := -1
var _support_bone := -1
var _shown_alive := true
var _death_left := 0.0


func _ready() -> void:
	build()


func _process(delta: float) -> void:
	if _animation == null:
		return
	if _flash != null and _flash.visible:
		_flash_left -= delta
		_flash.visible = _flash_left > 0.0
	if _shown_alive != alive:
		_shown_alive = alive
		_has_last = false
		if alive:
			visible = true
		else:
			_death_left = DEATH_SHOW_TIME
			_play("death", 1.0)
		if _rifle != null:
			_rifle.visible = alive
	if not alive:
		# 쓰러지는 동작을 보여 준 뒤 사라진다.
		_death_left -= delta
		if _death_left <= 0.0:
			visible = false
		return
	# 보간된 위치(또는 붙어 있는 플레이어)의 실제 이동에서 속도를 구해 동작을 고른다.
	var now := global_position
	var velocity := Vector3.ZERO
	if _has_last and delta > 0.0:
		velocity = (now - _last_position) / delta
	_last_position = now
	_has_last = true
	var local := global_transform.basis.inverse() * velocity
	_play_movement(Vector2(local.x, local.z))
	_hold_rifle()


## 모델을 만든다. 트리에 넣지 않고 쓰는 테스트에서도 호출할 수 있다.
func build() -> void:
	if _model != null:
		return
	_model = SOLDIER.instantiate() as Node3D
	# 모델은 +z를 보고 만들어졌고 게임의 정면은 -z다.
	_model.rotation.y = PI
	_model.scale = Vector3.ONE * (HitMath.STAND_HEIGHT / MODEL_HEIGHT)
	add_child(_model)
	_animation = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for found in _model.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		# 회색 군복 텍스처에 팀 색을 곱한다. 아바타마다 색이 달라야 하므로 재질을 복제한다.
		_material = (part.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
		part.set_surface_override_material(0, _material)
	set_color(_tint)
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton != null:
		_grip_bone = _skeleton.find_bone(GRIP_BONE)
		_support_bone = _skeleton.find_bone(SUPPORT_BONE)
	_play("idle", 1.0)
	# 거리와 방향이 들리는 3D 총소리. 적의 위치를 귀로 알 수 있게 한다.
	_shot_audio = AudioStreamPlayer3D.new()
	_shot_audio.unit_size = 14.0
	_shot_audio.max_distance = 110.0
	_shot_audio.max_polyphony = 4
	_shot_audio.position.y = 1.4
	add_child(_shot_audio)
	set_weapon(0)


## 들고 있는 무기를 바꾼다. 모델과 발사음이 그 무기 것으로 바뀐다.
func set_weapon(slot: int) -> void:
	slot = clampi(slot, 0, WEAPONS.size() - 1)
	if slot == _weapon_slot or _shot_audio == null:
		return
	_weapon_slot = slot
	var data: Resource = WEAPONS[slot]
	_shot_audio.stream = data.get("shot_sound")
	if _grip_bone < 0 or _support_bone < 0:
		return
	if _rifle != null:
		_rifle.queue_free()
	_rifle = (data.get("model") as PackedScene).instantiate() as Node3D
	# 동작의 두 손은 가까이 모여 있다. 손잡이와 총열 덮개의 가운데를 두 손 사이에 오게 해서
	# 개머리판이 어깨 쪽으로 오고, 긴 총일수록 뒤로 더 물리게 한다.
	var grip_at: Vector3 = data.get("grip_point")
	var support_at: Vector3 = data.get("support_point")
	var middle := (grip_at + support_at) * 0.5
	_hold_offset = Vector2(middle.z, -middle.y + WRIST_LIFT)
	_rifle.visible = alive
	add_child(_rifle)
	_flash = Effects.muzzle_flash()
	var muzzle := _rifle.find_child("muzzle", true, false) as Node3D
	_flash.position = muzzle.position if muzzle != null else Vector3(0.0, 0.0, -0.7)
	_rifle.add_child(_flash)


func play_shot() -> void:
	if _shot_audio == null or not _shot_audio.is_inside_tree():
		return
	_shot_audio.play()
	if _flash == null or not visible:
		return
	# 총구 화염과, 바라보는 방향으로 뻗는 예광탄. 어디서 쏘는지 눈으로 알 수 있게 한다.
	_flash_left = FLASH_TIME
	Effects.show_flash(_flash)
	var from := _flash.global_position
	var to := from - global_transform.basis.z * TRACER_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	if not wall.is_empty():
		to = wall["position"]
	Effects.tracer(get_tree().current_scene, from, to)


func set_color(color: Color) -> void:
	_tint = color
	if _material != null:
		# 텍스처 디테일이 남도록 팀 색을 밝게 섞어 곱한다.
		_material.albedo_color = color.lerp(Color.WHITE, 0.25)


## 보간 없이 자세만 바로 반영한다. 같은 프로세스에 있는 플레이어(봇)에 붙여 쓸 때 사용한다.
func set_pose(is_low: bool, is_alive: bool) -> void:
	alive = is_alive
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
	low = older[3]


## local은 아바타 기준 수평 속도(x: 오른쪽, y: 뒤쪽이 +).
func _play_movement(local: Vector2) -> void:
	var speed := local.length()
	if low:
		if speed > MOVE_THRESHOLD:
			_play("crouch_walk", clampf(speed / CROUCH_CLIP_SPEED, 0.6, 2.0))
		else:
			_play("crouch_idle", 1.0)
		return
	if speed <= MOVE_THRESHOLD:
		_play("idle", 1.0)
		return
	var clip := "run_f"
	if absf(local.x) > absf(local.y):
		clip = "run_r" if local.x > 0.0 else "run_l"
	elif local.y > 0.0:
		clip = "run_b"
	_play(clip, clampf(speed / RUN_CLIP_SPEED, 0.5, 1.8))


func _play(clip: String, speed: float) -> void:
	if not _animation.has_animation(clip):
		return
	if _animation.current_animation != clip:
		_animation.play(clip, BLEND_TIME)
	_animation.speed_scale = speed


## 총을 오른손(손잡이)에 두고 왼손(총열 덮개) 쪽을 향하게 한다.
## 동작마다 손 위치가 달라도 두 손을 잇는 선에 총이 놓이므로 뼈별 각도 보정이 필요 없다.
func _hold_rifle() -> void:
	if _rifle == null or not is_inside_tree():
		return
	var base := _skeleton.global_transform
	var grip := base * _skeleton.get_bone_global_pose(_grip_bone).origin
	var support := base * _skeleton.get_bone_global_pose(_support_bone).origin
	var forward := support - grip
	if forward.length() < 0.05 or absf(forward.normalized().dot(Vector3.UP)) > 0.95:
		forward = -global_transform.basis.z
	# 손을 잇는 선만 쓰면 총이 몸을 가로지르는 동작이 있어, 바라보는 방향과 반씩 섞는다.
	forward = (forward.normalized() - global_transform.basis.z).normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var up := side.cross(forward)
	_rifle.global_transform = Transform3D(
		Basis(side, up, -forward),
		(grip + support) * 0.5 + forward * _hold_offset.x + up * _hold_offset.y
	)
