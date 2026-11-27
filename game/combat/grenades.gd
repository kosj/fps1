extends Node3D
## 수류탄. 던진 순간의 위치와 방향만 주고받고, 서버와 각 클라이언트가 같은 규칙으로 궤적을 계산한다.
## 피해는 판정 권한이 있는 쪽만 계산한다(exploded 신호를 받아 처리).

## 터졌을 때. owner_id는 던진 사람, at은 터진 자리.
signal exploded(owner_id: int, at: Vector3)

const Effects := preload("res://game/fx/effects.gd")
const SOUND := preload("res://game/audio/sfx/explosion.ogg")
const THROW_SPEED := 15.0
## 조준 방향보다 조금 위로 던져 포물선을 만든다.
const THROW_LIFT := 3.2
const GRAVITY := 14.0
const FUSE := 2.4
## 벽과 바닥에 튈 때 남는 속도 비율.
const BOUNCE := 0.38
const RADIUS := 6.5
const MAX_DAMAGE := 150.0
## 이 거리 안에서는 피해가 줄지 않는다.
const FULL_DAMAGE_RADIUS := 1.2
const BODY_RADIUS := 0.07
const PER_LIFE := 2

## 날아가는 수류탄. 각 항목은 [던진 사람, 노드, 속도, 남은 시간].
var _live: Array = []
var _mesh: SphereMesh


## 거리(m)에 따른 폭발 피해. 가까우면 최대, 반경 끝에서 0.
static func damage_at(distance: float) -> float:
	if distance >= RADIUS:
		return 0.0
	var falloff := inverse_lerp(RADIUS, FULL_DAMAGE_RADIUS, maxf(distance, FULL_DAMAGE_RADIUS))
	return MAX_DAMAGE * falloff


func throw(owner_id: int, origin: Vector3, direction: Vector3) -> void:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = BODY_RADIUS
		_mesh.height = BODY_RADIUS * 2.4
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.16, 0.2, 0.13)
		material.roughness = 0.7
		_mesh.material = material
	var body := MeshInstance3D.new()
	body.mesh = _mesh
	add_child(body)
	body.global_position = origin + direction * 0.4
	_live.append([owner_id, body, direction * THROW_SPEED + Vector3.UP * THROW_LIFT, FUSE])


func count() -> int:
	return _live.size()


## 한 틱 진행한다. 세션이 물리 틱마다 부른다(일시 정지 중에는 부르지 않는다).
func tick(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for item: Array in _live:
		var body: MeshInstance3D = item[1]
		var velocity: Vector3 = item[2]
		velocity.y -= GRAVITY * delta
		var from := body.global_position
		var to := from + velocity * delta
		# 맵 구조물(충돌 층 1)에만 부딪힌다. 사람은 통과한다.
		var query := PhysicsRayQueryParameters3D.create(from, to + velocity.normalized() * BODY_RADIUS, 1)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and not (hit["collider"] is CharacterBody3D):
			var normal: Vector3 = hit["normal"]
			to = (hit["position"] as Vector3) + normal * BODY_RADIUS
			velocity = velocity.bounce(normal) * BOUNCE
			# 바닥에서 거의 멈췄으면 굴러다니지 않게 세운다.
			if normal.y > 0.7 and velocity.length() < 1.2:
				velocity = Vector3.ZERO
		body.global_position = to
		item[2] = velocity
		item[3] = float(item[3]) - delta
	for item: Array in _live.filter(func(entry: Array) -> bool: return float(entry[3]) <= 0.0):
		var body: MeshInstance3D = item[1]
		var at := body.global_position
		body.queue_free()
		_explode(at)
		exploded.emit(int(item[0]), at)
	_live = _live.filter(func(entry: Array) -> bool: return float(entry[3]) > 0.0)


func _explode(at: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Effects.explosion(self, at)
	var audio := AudioStreamPlayer3D.new()
	audio.stream = SOUND
	audio.unit_size = 22.0
	audio.max_distance = 120.0
	audio.volume_db = 2.0
	add_child(audio)
	audio.global_position = at
	audio.play()
	audio.finished.connect(audio.queue_free)
