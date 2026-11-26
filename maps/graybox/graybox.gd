extends Node3D
## M0 그레이박스 맵. 엄폐물 상자를 코드로 배치해 씬 파일을 작게 유지한다.

## 각 항목은 [중심 위치, 크기].
const COVERS := [
	[Vector3(4.0, 0.75, -6.0), Vector3(3.0, 1.5, 1.0)],
	[Vector3(-5.0, 0.75, -9.0), Vector3(1.0, 1.5, 4.0)],
	[Vector3(0.0, 0.5, -14.0), Vector3(6.0, 1.0, 1.0)],
	[Vector3(8.0, 1.5, -15.0), Vector3(2.0, 3.0, 2.0)],
	[Vector3(-9.0, 1.5, -3.0), Vector3(2.0, 3.0, 6.0)],
	[Vector3(3.0, 0.25, 5.0), Vector3(4.0, 0.5, 4.0)],
]

@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	_sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.57, 0.6)
	for cover: Array in COVERS:
		_add_box(cover[0], cover[1], material)
	if OS.has_feature("dedicated_server"):
		print("FPS1 dedicated server build (M0 placeholder, no networking yet)")


func _add_box(center: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)
