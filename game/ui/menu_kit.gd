extends RefCounted
## 메뉴 화면을 코드로 만들 때 쓰는 공통 부품.

const Settings := preload("res://game/core/settings.gd")


static func label(text: String, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", font_size)
	return node


static func button(text: String) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(320.0, 48.0)
	node.add_theme_font_size_override("font_size", 20)
	return node


## 어두운 배경 위 가운데에 세로로 쌓이는 상자를 만들어 돌려준다.
static func centered_column(layer: CanvasLayer, background: Color) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = background
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	return column


## 감도 슬라이더 한 줄. 값이 바뀌면 설정에 저장하고 on_change를 부른다.
static func sensitivity_row(on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var caption := label("Mouse sensitivity", 16)
	row.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = Settings.MIN_SENSITIVITY
	slider.max_value = Settings.MAX_SENSITIVITY
	slider.step = 0.05
	slider.value = Settings.sensitivity()
	slider.custom_minimum_size = Vector2(170.0, 24.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var readout := label("%.2f" % slider.value, 16)
	row.add_child(readout)
	slider.value_changed.connect(
		func(value: float) -> void: _apply_sensitivity(value, readout, on_change)
	)
	return row


static func _apply_sensitivity(value: float, readout: Label, on_change: Callable) -> void:
	readout.text = "%.2f" % value
	Settings.write(Settings.SENSITIVITY, value)
	if on_change.is_valid():
		on_change.call(value)
