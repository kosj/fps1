extends RefCounted
## 맵 표면 재질 모음. 상자 크기와 상관없이 무늬 크기가 일정하도록 월드 기준 트라이플래너로 입힌다.
## 텍스처는 maps/textures의 Poly Haven CC0 세트(색, 노멀, AO/러프니스/메탈릭)를 쓴다.

const Settings := preload("res://game/core/settings.gd")
const TEXTURE_DIR := "res://maps/textures/"
## 종류별 [텍스처 접두어, 1m당 반복 수, 색조].
const KINDS := {
	"floor": ["asphalt_02", 0.25, Color(0.85, 0.85, 0.88)],
	"wall": ["cracked_concrete_wall", 0.45, Color(0.62, 0.62, 0.64)],
	"container": ["container_side", 0.4, Color(0.7, 0.78, 0.72)],
	"crate": ["plywood", 0.6, Color(0.95, 0.9, 0.8)],
}

static var _cache := {}


static func material(kind: String) -> StandardMaterial3D:
	if _cache.has(kind):
		return _cache[kind]
	var spec: Array = KINDS[kind]
	var prefix: String = TEXTURE_DIR + str(spec[0])
	var result := StandardMaterial3D.new()
	result.albedo_color = spec[2]
	result.albedo_texture = load(prefix + "_diff.jpg")
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
