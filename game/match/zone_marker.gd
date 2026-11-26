extends Node3D
## 거점 표시. 바닥의 원판과 떠 있는 글자로 위치와 소유 팀을 보여 준다.

const Domination := preload("res://game/match/domination.gd")

var _material := StandardMaterial3D.new()
var _label := Label3D.new()


func _init(zone_name: String = "A") -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(0.7, 0.7, 0.7, 0.25)
	var mesh := CylinderMesh.new()
	mesh.top_radius = Domination.RADIUS
	mesh.bottom_radius = Domination.RADIUS
	mesh.height = 0.06
	mesh.material = _material
	var disc := MeshInstance3D.new()
	disc.mesh = mesh
	disc.position.y = 0.03
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	_label.text = zone_name
	_label.font_size = 160
	_label.pixel_size = 0.01
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 3.0
	add_child(_label)


## color는 소유 팀 색, progress는 점령 진행도. 진행 중일수록 원판이 진해진다.
func set_state(color: Color, progress: float) -> void:
	_material.albedo_color = Color(color.r, color.g, color.b, 0.25 + 0.4 * progress)
	_label.modulate = color
