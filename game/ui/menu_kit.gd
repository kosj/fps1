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
	node.custom_minimum_size = Vector2(320.0, 46.0)
	node.add_theme_font_size_override("font_size", 20)
	return node


## 어두운 배경 위 가운데에 세로로 쌓이는 상자를 만들어 돌려준다.
static func centered_column(layer: CanvasLayer, background: Color) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = background
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	# 작은 화면에서는 메뉴가 화면보다 길어질 수 있어 스크롤로 감싼다.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shade.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	return column


## 감도 슬라이더 한 줄. 값이 바뀌면 설정에 저장하고 on_change를 부른다.
static func sensitivity_row(on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var caption := label("Mouse sensitivity", 18)
	row.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = Settings.MIN_SENSITIVITY
	slider.max_value = Settings.MAX_SENSITIVITY
	slider.step = 0.05
	slider.value = Settings.sensitivity()
	slider.custom_minimum_size = Vector2(170.0, 24.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var readout := label("%.2f" % slider.value, 18)
	row.add_child(readout)
	slider.value_changed.connect(
		func(value: float) -> void: _apply_sensitivity(value, readout, on_change)
	)
	return row


## 화면 글자와 버튼 크기를 조절하는 슬라이더 한 줄. 바꾸는 즉시 전체 UI에 적용하고 저장한다.
static func ui_scale_row(tree: SceneTree) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(label("UI size", 18))
	var slider := HSlider.new()
	slider.min_value = Settings.MIN_UI_SCALE
	slider.max_value = Settings.MAX_UI_SCALE
	slider.step = 0.05
	slider.value = Settings.ui_scale()
	slider.custom_minimum_size = Vector2(170.0, 24.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var readout := label("%d%%" % int(round(slider.value * 100.0)), 18)
	row.add_child(readout)
	slider.value_changed.connect(
		func(value: float) -> void: _apply_ui_scale(value, readout, tree)
	)
	return row


static func _apply_ui_scale(value: float, readout: Label, tree: SceneTree) -> void:
	readout.text = "%d%%" % int(round(value * 100.0))
	Settings.write(Settings.UI_SCALE, value)
	Settings.apply_ui_scale(tree.root)


## 터치 조작 켜기/끄기. 자동 판단이 틀렸을 때 직접 바꿀 수 있다.
static func touch_toggle(on_change: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = "Touch controls"
	toggle.add_theme_font_size_override("font_size", 18)
	toggle.button_pressed = Settings.touch_enabled()
	toggle.toggled.connect(
		func(enabled: bool) -> void: _apply_touch(enabled, on_change)
	)
	return toggle


static func _apply_touch(enabled: bool, on_change: Callable) -> void:
	Settings.write(Settings.TOUCH_MODE, "on" if enabled else "off")
	if on_change.is_valid():
		on_change.call(enabled)


static func _apply_sensitivity(value: float, readout: Label, on_change: Callable) -> void:
	readout.text = "%.2f" % value
	Settings.write(Settings.SENSITIVITY, value)
	if on_change.is_valid():
		on_change.call(value)
