extends RefCounted
## 맵 꾸밈(보이기만 하고 플레이에는 영향이 없다): 하늘 사진, 지평선까지 이어지는 땅,
## 물체 바닥의 접지 그림자, 경기장 밖 건물의 지붕과 문.
## 웹 빌드(Compatibility 렌더러)에는 SSAO가 없어서, 물체가 바닥에 떠 보이지 않도록 접지 그림자를 직접 깐다.

const Settings := preload("res://game/core/settings.gd")
const Surfaces := preload("res://game/world/surfaces.gd")
## 접지 그림자가 물체 둘레로 번지는 폭(m)과 진하기. 해 그림자를 끄는 저사양 설정에서는
## 이것이 유일한 그림자라 더 넓고 진하게 깐다.
const CONTACT_MARGIN := 0.7
const CONTACT_STRENGTH := 0.6
const LOW_CONTACT_MARGIN := 1.0
const LOW_CONTACT_STRENGTH := 0.72
const CONTACT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// 사각형 안쪽(물체 발자국)이 차지하는 비율. 0~1, 가로와 세로.
uniform vec2 inner = vec2(0.5);
uniform float strength = 0.5;
void fragment() {
	vec2 p = abs(UV - 0.5) * 2.0;
	vec2 d = max(p - inner, vec2(0.0)) / max(vec2(1.0) - inner, vec2(0.001));
	float fall = 1.0 - clamp(length(d), 0.0, 1.0);
	ALBEDO = vec3(0.0);
	ALPHA = fall * fall * strength;
}
"""
## 지평선까지 깔리는 땅의 한 변(m).
const FAR_GROUND_SIZE := 2400.0

static var _contact_shader: Shader
static var _contact_materials := {}
static var _flat_materials := {}


## 하늘 사진을 쓰고, 사진 속 해(sun_uv, 0~1)의 방위로 태양 조명을 돌린다.
## elevation_deg가 0보다 크면 조명의 고도는 그 값으로 둔다(해가 너무 낮은 사진에서 그림자가 지나치게 길지 않게).
static func use_sky(
	environment: Environment, panorama: Texture2D, sun_uv: Vector2, energy: float,
	sun: DirectionalLight3D, elevation_deg := 0.0
) -> void:
	var material := PanoramaSkyMaterial.new()
	material.panorama = panorama
	material.energy_multiplier = energy
	var sky := Sky.new()
	sky.sky_material = material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.sky_rotation = Vector3.ZERO
	sun.basis = Basis.looking_at(-sky_direction(sun_uv, elevation_deg), Vector3.UP)


## 파노라마의 (u, v)가 가리키는 방향. Godot 하늘 셰이더는 u = atan2(x, -z) / TAU(0~1로 감음),
## v = acos(y) / PI로 읽는다: u = 0이 -Z, u = 0.25가 +X.
static func sky_direction(uv: Vector2, elevation_deg := 0.0) -> Vector3:
	var azimuth := uv.x * TAU
	var elevation := (0.5 - uv.y) * PI
	if elevation_deg > 0.0:
		elevation = deg_to_rad(elevation_deg)
	return Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))


## 경기장 바깥으로 지평선까지 이어지는 땅. 안개가 끝을 가린다.
static func add_far_ground(parent: Node3D, kind: String) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(FAR_GROUND_SIZE, FAR_GROUND_SIZE)
	plane.material = Surfaces.material(kind)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.position = Vector3(0.0, -0.02, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ground)


## 바닥에 닿은 상자(중심 center, 크기 size) 둘레에 번지는 어두운 접지 그림자.
static func add_contact_shadow(parent: Node3D, center: Vector3, size: Vector3) -> void:
	if center.y - size.y * 0.5 > 0.05:
		return
	var low := Settings.low_graphics()
	var margin := LOW_CONTACT_MARGIN if low else CONTACT_MARGIN
	var outer := Vector2(size.x, size.z) + Vector2.ONE * margin * 2.0
	var quad := PlaneMesh.new()
	quad.size = outer
	quad.material = _contact_material(
		Vector2(size.x, size.z) / outer, LOW_CONTACT_STRENGTH if low else CONTACT_STRENGTH
	)
	var shadow := MeshInstance3D.new()
	shadow.mesh = quad
	shadow.position = Vector3(center.x, 0.012, center.z)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shadow)


static func _contact_material(inner: Vector2, strength: float) -> ShaderMaterial:
	var key := "%.3f,%.3f,%.2f" % [inner.x, inner.y, strength]
	if _contact_materials.has(key):
		return _contact_materials[key]
	if _contact_shader == null:
		_contact_shader = Shader.new()
		_contact_shader.code = CONTACT_SHADER
	var material := ShaderMaterial.new()
	material.shader = _contact_shader
	material.set_shader_parameter("inner", inner)
	material.set_shader_parameter("strength", strength)
	_contact_materials[key] = material
	return material


## 경기장 밖 건물 하나: 몸체, 지붕, 경기장 쪽 벽의 문과 창, 접지 그림자.
## kind가 "warehouse"면 박공지붕 창고, 아니면 평지붕에 난간이 있는 집.
static func add_building(parent: Node3D, center: Vector3, size: Vector3, kind: String) -> void:
	_add_mesh(parent, _box(size), center, Surfaces.material(kind))
	# 경기장(원점)을 바라보는 벽: x와 z 중 원점 쪽으로 더 많이 드러난 면.
	var facing := Vector3(-signf(center.x), 0.0, 0.0)
	if absf(center.z) - size.z * 0.5 > absf(center.x) - size.x * 0.5:
		facing = Vector3(0.0, 0.0, -signf(center.z))
	# along: 그 벽을 따라가는 방향, width: 벽의 길이.
	var along := Vector3(absf(facing.z), 0.0, absf(facing.x))
	var width := size.x if along.x > 0.5 else size.z
	var depth := size.z if along.x > 0.5 else size.x
	# 벽면 바로 앞, 바닥 높이(y = 0)를 기준으로 문과 창을 붙인다.
	var face := center + facing * (depth * 0.5 + 0.03) - Vector3.UP * center.y
	if kind == "warehouse":
		_add_warehouse_details(parent, center, size, face, along, width)
	else:
		_add_house_details(parent, center, size, face, along, width, kind)
	add_contact_shadow(parent, center, size)


## 창고: 긴 쪽으로 용마루가 지나가는 박공지붕, 셔터 문 두 개, 높은 창 띠.
static func _add_warehouse_details(
	parent: Node3D, center: Vector3, size: Vector3, face: Vector3, along: Vector3, width: float
) -> void:
	var prism := PrismMesh.new()
	var long_x := size.x >= size.z
	prism.size = Vector3(size.z if long_x else size.x, size.y * 0.22, size.x if long_x else size.z)
	var top := center.y + size.y * 0.5
	var roof := _add_mesh(
		parent, prism, Vector3(center.x, top + prism.size.y * 0.5, center.z),
		_flat(Color(0.32, 0.34, 0.36), 0.7)
	)
	roof.rotation.y = PI * 0.5 if long_x else 0.0
	var door_height := minf(5.0, size.y * 0.55)
	for side: float in [-0.25, 0.25]:
		_add_mesh(
			parent, _face_box(along, 4.2, door_height),
			face + along * width * side + Vector3.UP * door_height * 0.5,
			_flat(Color(0.2, 0.22, 0.24), 0.6)
		)
	_add_mesh(
		parent, _face_box(along, width * 0.85, 0.9), face + Vector3.UP * size.y * 0.82,
		_flat(Color(0.08, 0.1, 0.12), 0.25)
	)


## 집: 평지붕 난간과 층마다 작은 창들.
static func _add_house_details(
	parent: Node3D, center: Vector3, size: Vector3, face: Vector3, along: Vector3, width: float,
	kind: String
) -> void:
	var rim := _box(Vector3(size.x + 0.3, 0.5, size.z + 0.3))
	var top := center.y + size.y * 0.5
	_add_mesh(parent, rim, Vector3(center.x, top + 0.25, center.z), Surfaces.material(kind))
	var columns := maxi(int(width / 4.0), 1)
	for row in maxi(int(size.y / 3.2), 1):
		for column in columns:
			var offset := (float(column) + 0.5) / columns - 0.5
			_add_mesh(
				parent, _face_box(along, 1.1, 1.2),
				face + along * width * offset * 0.85 + Vector3.UP * (1.8 + row * 3.2),
				_flat(Color(0.09, 0.08, 0.08), 0.3)
			)


## 벽면에 붙이는 얇은 판: 벽을 따라 length, 높이 height.
static func _face_box(along: Vector3, length: float, height: float) -> BoxMesh:
	if along.x > 0.5:
		return _box(Vector3(length, height, 0.08))
	return _box(Vector3(0.08, height, length))


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _add_mesh(
	parent: Node3D, mesh: Mesh, at: Vector3, material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


static func _flat(color: Color, roughness: float) -> StandardMaterial3D:
	var key := "%s/%.2f" % [color.to_html(), roughness]
	if not _flat_materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = 0.3
		_flat_materials[key] = material
	return _flat_materials[key]
