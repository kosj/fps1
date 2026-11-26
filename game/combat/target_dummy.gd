extends Node3D
## 사격 연습용 더미. 몸통과 머리 히트박스를 갖고, 쓰러지면 잠시 뒤 다시 선다.

signal damaged(amount: float, headshot: bool, killed: bool)

const Hitbox := preload("res://game/combat/hitbox.gd")
const MAX_HEALTH := 100.0
const RESPAWN_DELAY := 2.0
const BASE_COLOR := Color(0.85, 0.45, 0.2)
const HIT_COLOR := Color(1.0, 1.0, 1.0)

var health := MAX_HEALTH
var deaths := 0
var damage_taken := 0.0

var _respawn_left := 0.0
var _flash := 0.0
var _material := StandardMaterial3D.new()
var _parts: Array[StaticBody3D] = []


func _ready() -> void:
	_material.albedo_color = BASE_COLOR
	_add_part(Vector3(0.0, 0.75, 0.0), Vector3(0.55, 1.5, 0.3), false)
	_add_part(Vector3(0.0, 1.65, 0.0), Vector3(0.26, 0.28, 0.26), true)


func is_alive() -> bool:
	return health > 0.0


## 피해를 적용하고, 이 피해로 쓰러졌으면 true를 돌려준다.
func apply_damage(amount: float, headshot: bool) -> bool:
	if not is_alive():
		return false
	health = maxf(health - amount, 0.0)
	damage_taken += amount
	_flash = 1.0
	var killed := not is_alive()
	if killed:
		deaths += 1
		_respawn_left = RESPAWN_DELAY
		_set_standing(false)
	damaged.emit(amount, headshot, killed)
	return killed


func _physics_process(delta: float) -> void:
	if is_alive():
		return
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		health = MAX_HEALTH
		_set_standing(true)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 8.0, 0.0)
	_material.albedo_color = BASE_COLOR.lerp(HIT_COLOR, _flash)


func _set_standing(standing: bool) -> void:
	visible = standing
	for part in _parts:
		part.collision_layer = 1 if standing else 0


func _add_part(center: Vector3, size: Vector3, is_head: bool) -> void:
	var body := Hitbox.new()
	body.position = center
	body.is_head = is_head
	body.target = self
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)
	_parts.append(body)
