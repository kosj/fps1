extends RefCounted
## 메뉴 화면을 코드로 만들 때 쓰는 공통 부품. 모양은 전역 테마(ui_theme.gd)와 ui_style.gd를 따른다.

const Settings := preload("res://game/core/settings.gd")
const UiStyle := preload("res://game/ui/ui_style.gd")
## 설정 줄의 이름 칸 너비.
const CAPTION_WIDTH := 150.0


static func label(text: String, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", font_size)
	return node


static func button(text: String, variation := "") -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(300.0, 44.0)
	node.theme_type_variation = variation
	return node


## 아이콘이 붙은 버튼. 아이콘은 Font Awesome 글자라 버튼 글꼴과 섞을 수 없어 따로 붙인다.
static func icon_button(text: String, icon_name: String, variation := "") -> Button:
	var node := button("", variation)
	var row := UiStyle.row(10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var color := UiStyle.ACCENT_DARK if variation == "PrimaryButton" else UiStyle.TEXT
	row.add_child(UiStyle.icon(icon_name, UiStyle.SIZE_M, color))
	var font: Font = UiStyle.display_font() if variation == "PrimaryButton" else UiStyle.FONT_BOLD
	var font_size := UiStyle.SIZE_L + 2 if variation == "PrimaryButton" else UiStyle.SIZE_M
	row.add_child(UiStyle.label(text, font_size, color, font))
	node.add_child(row)
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


## centered_column처럼 가운데에 놓되, 테두리 있는 판 안에 넣는다(일시 정지 화면 같은 대화 상자).
static func centered_panel(layer: CanvasLayer, background: Color, width: float) -> VBoxContainer:
	var outer := centered_column(layer, background)
	var panel := PanelContainer.new()
	var style := UiStyle.margins(UiStyle.box(UiStyle.PANEL, UiStyle.LINE_STRONG, 1), 26, 20)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(width, 0.0)
	outer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column


## 설정 한 줄: 왼쪽에 작은 대문자 이름, 가운데 조작, 오른쪽에 값.
static func setting_row(caption: String, control: Control, readout: Label = null) -> HBoxContainer:
	var row := UiStyle.row(12)
	var name_label := UiStyle.caption(caption, UiStyle.TEXT_DIM, 13)
	name_label.custom_minimum_size = Vector2(CAPTION_WIDTH, 0.0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	if readout != null:
		readout.custom_minimum_size = Vector2(52.0, 0.0)
		readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(readout)
	return row


static func _slider(minimum: float, maximum: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(170.0, 24.0)
	return slider


static func _readout(text: String) -> Label:
	return UiStyle.label(text, UiStyle.SIZE_M, UiStyle.TEXT, UiStyle.FONT_BOLD)


## 감도 슬라이더 한 줄. 값이 바뀌면 설정에 저장하고 on_change를 부른다.
static func sensitivity_row(on_change: Callable) -> HBoxContainer:
	var slider := _slider(Settings.MIN_SENSITIVITY, Settings.MAX_SENSITIVITY, Settings.sensitivity())
	var readout := _readout("%.2f" % slider.value)
	slider.value_changed.connect(
		func(value: float) -> void: _apply_sensitivity(value, readout, on_change)
	)
	return setting_row("Look sensitivity", slider, readout)


## 화면 글자와 버튼 크기를 조절하는 슬라이더 한 줄. 바꾸는 즉시 전체 UI에 적용하고 저장한다.
static func ui_scale_row(tree: SceneTree) -> HBoxContainer:
	var slider := _slider(Settings.MIN_UI_SCALE, Settings.MAX_UI_SCALE, Settings.ui_scale())
	var readout := _readout("%d%%" % int(round(slider.value * 100.0)))
	slider.value_changed.connect(
		func(value: float) -> void: _apply_ui_scale(value, readout, tree)
	)
	return setting_row("UI size", slider, readout)


static func _apply_ui_scale(value: float, readout: Label, tree: SceneTree) -> void:
	readout.text = "%d%%" % int(round(value * 100.0))
	Settings.write(Settings.UI_SCALE, value)
	Settings.apply_ui_scale(tree.root)


## 켜고 끄는 스위치 한 줄(이름은 왼쪽, 스위치는 오른쪽 끝).
static func switch(caption: String, on: bool) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = caption.to_upper()
	toggle.add_theme_font_override("font", UiStyle.caps_font())
	toggle.add_theme_font_size_override("font_size", 13)
	toggle.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	toggle.add_theme_color_override("font_pressed_color", UiStyle.TEXT)
	toggle.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	toggle.button_pressed = on
	return toggle


## 터치 조작 켜기/끄기. 자동 판단이 틀렸을 때 직접 바꿀 수 있다.
static func touch_toggle(on_change: Callable) -> CheckButton:
	var toggle := switch("Touch controls", Settings.touch_enabled())
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
