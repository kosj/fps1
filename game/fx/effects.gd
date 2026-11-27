extends RefCounted
## 총구 화염, 예광탄, 탄착(탄흔·먼지·불꽃), 탄피 같은 짧은 시각 효과를 만든다.
## 웹(WebGL2)에서도 같은 모습이 나오도록 CPU 파티클과 절차적 텍스처만 쓴다.

const TRACER_TIME := 0.06
const HOLE_TIME := 10.0
const PUFF_TIME := 0.7

static var _glow: GradientTexture2D
static var _hole_material: StandardMaterial3D
static var _flash_material: StandardMaterial3D
static var _tracer_material: StandardMaterial3D
static var _dust_material: StandardMaterial3D
static var _spark_material: StandardMaterial3D
static var _brass_material: StandardMaterial3D


## 가운데가 밝고 가장자리로 사라지는 둥근 텍스처.
static func glow_texture() -> GradientTexture2D:
	if _glow == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 0.55))
		_glow = GradientTexture2D.new()
		_glow.gradient = gradient
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 64
		_glow.height = 64
	return _glow


## 총구 화염: 서로 엇갈린 판 세 장. 쏠 때마다 show_flash로 크기와 각도를 바꾼다.
static func muzzle_flash() -> Node3D:
	if _flash_material == null:
		_flash_material = _unshaded(Color(1.0, 0.78, 0.4), true)
		_flash_material.albedo_texture = glow_texture()
	var root := Node3D.new()
	for index in 3:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.34, 0.12) if index < 2 else Vector2(0.2, 0.2)
		quad.material = _flash_material
		var plate := MeshInstance3D.new()
		plate.mesh = quad
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if index < 2:
			# 총열 방향으로 길쭉한 판 두 장을 십자로.
			plate.rotation = Vector3(0.0, PI / 2.0, index * PI / 2.0)
			plate.position.z = -0.12
		root.add_child(plate)
	root.visible = false
	return root


static func show_flash(flash: Node3D) -> void:
	flash.visible = true
	flash.rotation.z = randf() * TAU
	flash.scale = Vector3.ONE * randf_range(0.75, 1.25)


## 총구에서 탄착점까지 잠깐 보이는 빛줄기.
static func tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 1.5 or not parent.is_inside_tree():
		return
	if _tracer_material == null:
		# 밝은 벽 앞에서도 보이도록 더하기 혼합이 아닌 일반 혼합을 쓴다.
		_tracer_material = _unshaded(Color(1.0, 0.92, 0.65, 0.9), false)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.014, 0.014, length)
	mesh.material = _tracer_material
	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(line)
	line.look_at_from_position((from + to) / 2.0, to, _up_for(to - from))
	parent.get_tree().create_timer(TRACER_TIME).timeout.connect(line.queue_free)


## 탄착: 탄흔과 먼지, 불꽃. 돌려준 노드에 소리 같은 것을 더 붙일 수 있고 HOLE_TIME 뒤에 사라진다.
static func impact(parent: Node, point: Vector3, normal: Vector3) -> Node3D:
	if _hole_material == null:
		_hole_material = StandardMaterial3D.new()
		_hole_material.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
		_hole_material.albedo_texture = glow_texture()
		_hole_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hole_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_material = _unshaded(Color(0.5, 0.47, 0.42, 0.4), false)
		_dust_material.albedo_texture = glow_texture()
		_dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spark_material = _unshaded(Color(1.0, 0.8, 0.4), true)
		_spark_material.albedo_texture = glow_texture()
		_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var root := Node3D.new()
	parent.add_child(root)
	root.look_at_from_position(point + normal * 0.006, point + normal, _up_for(normal))

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * randf_range(0.11, 0.16)
	quad.material = _hole_material
	var hole := MeshInstance3D.new()
	hole.mesh = quad
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# look_at은 -Z를 표면 바깥으로 돌리므로, 앞면(+Z)이 바깥을 보게 뒤집는다.
	hole.rotation.y = PI
	root.add_child(hole)

	var dust := _burst(_dust_material, 10, 0.24, 1.6, PUFF_TIME, 0.9, Vector3(0, -1.5, 0))
	# 카메라를 보는 먼지 판이 벽에 반쯤 묻히지 않게 표면에서 조금 띄워 시작한다.
	dust.position.z = -0.1
	root.add_child(dust)
	root.add_child(_burst(_spark_material, 6, 0.045, 5.0, 0.25, 1.0, Vector3(0, -9.0, 0)))
	parent.get_tree().create_timer(HOLE_TIME).timeout.connect(root.queue_free)
	return root


## 탄피 배출: 쏘는 동안만 emitting을 켜서 쓴다. 총 모델의 오른쪽 배출구에 붙인다.
static func shell_ejector() -> CPUParticles3D:
	if _brass_material == null:
		_brass_material = StandardMaterial3D.new()
		_brass_material.albedo_color = Color(0.55, 0.42, 0.2)
		_brass_material.metallic = 0.9
		_brass_material.roughness = 0.35
	var shell := BoxMesh.new()
	shell.size = Vector3(0.009, 0.009, 0.026)
	shell.material = _brass_material
	var particles := CPUParticles3D.new()
	particles.mesh = shell
	particles.emitting = false
	particles.amount = 8
	particles.lifetime = 0.7
	particles.local_coords = false
	particles.direction = Vector3(1.0, 0.7, 0.2)
	particles.spread = 14.0
	particles.initial_velocity_min = 1.4
	particles.initial_velocity_max = 2.1
	particles.angular_velocity_min = -720.0
	particles.angular_velocity_max = 720.0
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


static func _burst(
	material: Material, amount: int, size: float, speed: float, lifetime: float,
	explosiveness: float, gravity: Vector3
) -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = material
	var particles := CPUParticles3D.new()
	particles.mesh = quad
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = explosiveness
	# 부모가 표면 바깥(-Z)을 보고 있으므로 그 방향으로 뿜는다.
	particles.direction = Vector3(0.0, 0.0, -1.0)
	particles.spread = 38.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = gravity
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = true
	return particles


static func _unshaded(color: Color, additive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return material


## look_at에 쓸 위쪽 벡터. 방향이 수직에 가까우면 다른 축을 쓴다.
static func _up_for(direction: Vector3) -> Vector3:
	return Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.95 else Vector3.UP
