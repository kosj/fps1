extends RefCounted
## 맵 표면 재질 모음. 상자 크기와 상관없이 무늬 크기가 일정하도록 월드 기준 트라이플래너로 입힌다.
## 텍스처는 maps/textures의 Poly Haven CC0 세트(색, 노멀, AO/러프니스/메탈릭)를 쓴다.

const Settings := preload("res://game/core/settings.gd")
const TEXTURE_DIR := "res://maps/textures/"
## 종류별 [텍스처 접두어, 1m당 반복 수, 색조, (선택) 색 텍스처만 다른 접두어].
## 컨테이너는 회색으로 바꾼 색 텍스처에 색조를 곱해 여러 색을 낸다.
const KINDS := {
	"floor": ["asphalt_02", 0.25, Color(0.85, 0.85, 0.88)],
	# 조립식 콘크리트 판(실제 2.1m 크기의 사진이라 1m당 0.476번 반복).
	"wall": ["concrete_slab_wall_02", 0.476, Color(0.78, 0.78, 0.8)],
	"container": ["container_side", 0.4, Color(0.36, 0.62, 0.42), "container_grey"],
	"crate": ["plywood", 0.6, Color(0.95, 0.9, 0.8)],
	"container_blue": ["container_side", 0.4, Color(0.25, 0.42, 0.75), "container_grey"],
	"container_rust": ["container_side", 0.4, Color(0.72, 0.33, 0.2), "container_grey"],
	"container_frame": ["container_side", 0.05, Color(0.42, 0.5, 0.45)],
	"barrier": ["cracked_concrete_wall", 0.7, Color(0.5, 0.5, 0.5)],
	"barrier_frame": ["cracked_concrete_wall", 0.7, Color(0.22, 0.22, 0.22)],
	"barrels": ["", 1.0, Color(0.16, 0.3, 0.5)],
	"barrels_frame": ["", 1.0, Color(0.09, 0.12, 0.18)],
	"warehouse": ["corrugated_iron_02", 0.18, Color(0.72, 0.74, 0.76)],
	"crate_frame": ["plywood", 0.9, Color(0.62, 0.52, 0.4)],
	# Compound 맵
	"ground": ["dry_ground_01", 0.22, Color(0.95, 0.88, 0.78)],
	"plaster": ["yellow_plaster", 0.35, Color(0.95, 0.88, 0.76)],
	"plaster_far": ["yellow_plaster", 0.2, Color(0.8, 0.72, 0.62)],
	"brick": ["red_brick_03", 0.45, Color(0.9, 0.85, 0.8)],
	"roof": ["corrugated_iron_02", 0.3, Color(0.5, 0.42, 0.36)],
}
const PROP_DIR := "res://maps/props/"

static var _cache := {}


static func material(kind: String) -> StandardMaterial3D:
	if _cache.has(kind):
		return _cache[kind]
	var spec: Array = KINDS[kind]
	var prefix: String = TEXTURE_DIR + str(spec[0])
	var result := StandardMaterial3D.new()
	result.albedo_color = spec[2]
	if str(spec[0]) == "":
		# 텍스처 없는 칠한 금속(드럼통).
		result.roughness = 0.45
		result.metallic = 0.4
		_cache[kind] = result
		return result
	var color_prefix: String = TEXTURE_DIR + str(spec[3]) if spec.size() > 3 else prefix
	result.albedo_texture = load(color_prefix + "_diff.jpg")
	# 비스듬히 보이는 바닥과 벽이 뭉개지지 않게 이방성 필터를 쓴다.
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	result.uv1_triplanar = true
	result.uv1_world_triplanar = true
	result.uv1_scale = Vector3.ONE * float(spec[1])
	result.roughness = 1.0
	# 낮은 그래픽 설정에서는 색 텍스처만 쓴다(휴대폰 브라우저의 메모리와 속도).
	if not Settings.low_graphics():
		var arm: Texture2D = load(prefix + "_arm.jpg")
		result.normal_enabled = true
		result.normal_texture = load(prefix + "_nor.jpg")
		result.ao_enabled = true
		result.ao_texture = arm
		result.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		result.roughness_texture = arm
		result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		result.metallic = 1.0
		result.metallic_texture = arm
		result.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	_cache[kind] = result
	return result


## 종류와 크기에 맞는 엄폐물 모델을 돌려준다. 그 크기의 모델이 없으면 null(상자로 대신한다).
## 모델의 재질 슬롯 panel, frame을 이 모음의 재질로 바꿔 끼운다.
static func prop(kind: String, size: Vector3) -> Node3D:
	# container_blue 같은 색 변형은 container 모델과 테두리 재질을 같이 쓴다.
	var base := kind.get_slice("_", 0)
	var path := "%s%s_%d_%d_%d.glb" % [
		PROP_DIR, base, roundi(size.x * 100.0), roundi(size.y * 100.0), roundi(size.z * 100.0)
	]
	if not KINDS.has(base + "_frame") or not ResourceLoader.exists(path):
		return null
	var node := (load(path) as PackedScene).instantiate() as Node3D
	for found in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var slot := mesh_instance.mesh.surface_get_material(surface).resource_name
			var which := base + "_frame" if slot == "frame" else kind
			mesh_instance.set_surface_override_material(surface, material(which))
	return node
