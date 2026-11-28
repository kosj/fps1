extends Node
## 게임 전체의 기본 테마. 자동 로드가 엔진 기본 테마에 덧입혀 모든 화면의 기본 글꼴과 버튼·입력칸 모양을 바꾼다.
## (창에 붙인 테마는 CanvasLayer에서 끊겨 HUD와 메뉴까지 내려가지 않으므로 기본 테마 자체를 바꾼다.)
## 색과 글꼴은 ui_style.gd의 토큰을 쓴다. 화면마다 다른 모양은 테마 변형으로 고른다:
## - PrimaryButton: 호박색으로 채운 주 행동 버튼(경기 시작 등)
## - NavButton: 시작 화면 왼쪽의 큰 메뉴 항목(누른 것은 왼쪽에 호박색 띠)
## - GhostButton: 테두리 없는 작은 버튼(뒤로 등)
## - CardPanel: 옅은 판, HudPanel: 경기 화면용 아주 옅은 판

const UiStyle := preload("res://game/ui/ui_style.gd")


func _init() -> void:
	apply(ThemeDB.get_default_theme())


## target(보통 엔진 기본 테마)에 이 게임의 테마를 덮어쓴다.
static func apply(target: Theme) -> void:
	var theme := build()
	target.merge_with(theme)
	target.default_font = theme.default_font
	target.default_font_size = theme.default_font_size


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = UiStyle.FONT_BODY
	theme.default_font_size = UiStyle.SIZE_M
	theme.set_color("font_color", "Label", UiStyle.TEXT)
	_buttons(theme)
	_variations(theme)
	_fields(theme)
	_toggles(theme)
	_ranges(theme)
	_panels(theme)
	return theme


static func _buttons(theme: Theme) -> void:
	for type: String in ["Button", "OptionButton", "MenuButton"]:
		var normal := UiStyle.box(Color(0.075, 0.085, 0.105, 0.86), UiStyle.LINE, 1)
		var hover := UiStyle.box(Color(0.13, 0.145, 0.17, 0.94), UiStyle.LINE_STRONG, 1)
		var pressed := UiStyle.box(Color(0.2, 0.16, 0.07, 0.95), UiStyle.ACCENT, 1)
		var disabled := UiStyle.box(Color(0.06, 0.07, 0.08, 0.5), UiStyle.LINE, 1)
		var focus := UiStyle.box(Color(0, 0, 0, 0), UiStyle.ACCENT, 1)
		focus.draw_center = false
		for item: Array in [
			["normal", normal], ["hover", hover], ["pressed", pressed],
			["hover_pressed", pressed], ["disabled", disabled], ["focus", focus],
		]:
			theme.set_stylebox(item[0], type, UiStyle.margins(item[1], 16.0, 9.0))
		theme.set_font("font", type, UiStyle.FONT_BOLD)
		theme.set_font_size("font_size", type, UiStyle.SIZE_M)
		theme.set_color("font_color", type, UiStyle.TEXT)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, UiStyle.ACCENT)
		theme.set_color("font_hover_pressed_color", type, UiStyle.ACCENT)
		theme.set_color("font_focus_color", type, UiStyle.TEXT)
		theme.set_color("font_disabled_color", type, UiStyle.TEXT_FAINT)
		theme.set_constant("h_separation", type, 10)
	theme.set_icon("arrow", "OptionButton", _chevron_down(UiStyle.TEXT_DIM))
	theme.set_constant("arrow_margin", "OptionButton", 10)


static func _variations(theme: Theme) -> void:
	theme.set_type_variation("PrimaryButton", "Button")
	var colors := [UiStyle.ACCENT, Color(1.0, 0.8, 0.38), Color(0.86, 0.6, 0.16)]
	for index in 3:
		var style := UiStyle.margins(UiStyle.box(colors[index]), 22.0, 11.0)
		theme.set_stylebox(["normal", "hover", "pressed"][index], "PrimaryButton", style)
	theme.set_stylebox(
		"hover_pressed", "PrimaryButton", theme.get_stylebox("pressed", "PrimaryButton")
	)
	theme.set_font("font", "PrimaryButton", UiStyle.display_font())
	theme.set_font_size("font_size", "PrimaryButton", UiStyle.SIZE_L + 2)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, "PrimaryButton", UiStyle.ACCENT_DARK)

	theme.set_type_variation("NavButton", "Button")
	var empty := StyleBoxEmpty.new()
	UiStyle.margins(empty, 18.0, 6.0)
	var hover := UiStyle.stripe_box(Color(1, 1, 1, 0.06), UiStyle.ACCENT, 4)
	var on := UiStyle.stripe_box(Color(1, 1, 1, 0.1), UiStyle.ACCENT, 4)
	for item: Array in [["normal", empty], ["hover", hover], ["pressed", on],
			["hover_pressed", on], ["focus", empty]]:
		theme.set_stylebox(item[0], "NavButton", UiStyle.margins(item[1], 18.0, 6.0))
	theme.set_font("font", "NavButton", UiStyle.display_font())
	theme.set_font_size("font_size", "NavButton", UiStyle.SIZE_XL)
	theme.set_color("font_color", "NavButton", UiStyle.TEXT_DIM)
	theme.set_color("font_hover_color", "NavButton", Color.WHITE)
	theme.set_color("font_pressed_color", "NavButton", Color.WHITE)
	theme.set_color("font_hover_pressed_color", "NavButton", Color.WHITE)
	theme.set_color("font_focus_color", "NavButton", UiStyle.TEXT_DIM)

	theme.set_type_variation("CardButton", "Button")
	var card_states := [
		["normal", UiStyle.box(UiStyle.PANEL_SOFT, UiStyle.LINE, 1)],
		["hover", UiStyle.box(Color(0.12, 0.135, 0.16, 0.86), UiStyle.LINE_STRONG, 1)],
		["pressed", UiStyle.box(Color(UiStyle.ACCENT, 0.14), UiStyle.ACCENT, 2)],
		["hover_pressed", UiStyle.box(Color(UiStyle.ACCENT, 0.2), UiStyle.ACCENT, 2)],
		["focus", StyleBoxEmpty.new()],
	]
	for item: Array in card_states:
		theme.set_stylebox(item[0], "CardButton", UiStyle.margins(item[1], 10.0, 8.0))

	theme.set_type_variation("GhostButton", "Button")
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var ghost := StyleBoxEmpty.new()
		theme.set_stylebox(state, "GhostButton", UiStyle.margins(ghost, 8.0, 6.0))
	theme.set_color("font_color", "GhostButton", UiStyle.TEXT_DIM)
	theme.set_color("font_hover_color", "GhostButton", Color.WHITE)
	theme.set_color("font_pressed_color", "GhostButton", UiStyle.ACCENT)
	theme.set_font("font", "GhostButton", UiStyle.caps_font())
	theme.set_font_size("font_size", "GhostButton", UiStyle.SIZE_S)


static func _fields(theme: Theme) -> void:
	var normal := UiStyle.margins(UiStyle.box(Color(0, 0, 0, 0.4), UiStyle.LINE_STRONG, 1), 12, 8)
	var focus := UiStyle.margins(UiStyle.box(Color(0, 0, 0, 0.5), UiStyle.ACCENT, 1), 12, 8)
	theme.set_stylebox("normal", "LineEdit", normal)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_stylebox("read_only", "LineEdit", normal)
	theme.set_color("font_color", "LineEdit", UiStyle.TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", UiStyle.TEXT_FAINT)
	theme.set_color("caret_color", "LineEdit", UiStyle.ACCENT)
	theme.set_color("selection_color", "LineEdit", Color(UiStyle.ACCENT, 0.35))
	theme.set_font("font", "LineEdit", UiStyle.FONT_BOLD)
	theme.set_icon("updown", "SpinBox", _updown(UiStyle.TEXT_DIM))

	var popup := UiStyle.box(Color(0.07, 0.08, 0.1, 0.98), UiStyle.LINE_STRONG, 1)
	theme.set_stylebox("panel", "PopupMenu", UiStyle.margins(popup, 4.0, 4.0))
	theme.set_stylebox("hover", "PopupMenu", UiStyle.box(UiStyle.ACCENT))
	theme.set_color("font_color", "PopupMenu", UiStyle.TEXT)
	theme.set_color("font_hover_color", "PopupMenu", UiStyle.ACCENT_DARK)
	theme.set_font("font", "PopupMenu", UiStyle.FONT_BOLD)
	theme.set_font_size("font_size", "PopupMenu", UiStyle.SIZE_M)
	theme.set_constant("v_separation", "PopupMenu", 10)
	theme.set_constant("item_start_padding", "PopupMenu", 12)
	theme.set_constant("item_end_padding", "PopupMenu", 12)
	var radio_on := _dot(UiStyle.ACCENT, true)
	var radio_off := _dot(UiStyle.TEXT_FAINT, false)
	theme.set_icon("radio_checked", "PopupMenu", radio_on)
	theme.set_icon("radio_unchecked", "PopupMenu", radio_off)
	theme.set_icon("checked", "PopupMenu", radio_on)
	theme.set_icon("unchecked", "PopupMenu", radio_off)


static func _toggles(theme: Theme) -> void:
	var empty := UiStyle.margins(StyleBoxEmpty.new(), 4.0, 6.0)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		theme.set_stylebox(state, "CheckButton", empty)
	theme.set_icon("checked", "CheckButton", _switch(true))
	theme.set_icon("unchecked", "CheckButton", _switch(false))
	theme.set_icon("checked_disabled", "CheckButton", _switch(true))
	theme.set_icon("unchecked_disabled", "CheckButton", _switch(false))
	theme.set_font("font", "CheckButton", UiStyle.FONT_BOLD)
	theme.set_color("font_color", "CheckButton", UiStyle.TEXT)
	theme.set_color("font_hover_color", "CheckButton", Color.WHITE)
	theme.set_color("font_pressed_color", "CheckButton", UiStyle.TEXT)
	theme.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)
	theme.set_color("font_focus_color", "CheckButton", UiStyle.TEXT)


static func _ranges(theme: Theme) -> void:
	var track := UiStyle.box(Color(1, 1, 1, 0.16), Color(0, 0, 0, 0), 0, 2)
	track.content_margin_top = 2.0
	track.content_margin_bottom = 2.0
	var filled := UiStyle.box(UiStyle.ACCENT, Color(0, 0, 0, 0), 0, 2)
	filled.content_margin_top = 2.0
	filled.content_margin_bottom = 2.0
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", _knob(UiStyle.ACCENT))
	theme.set_icon("grabber_highlight", "HSlider", _knob(Color(1.0, 0.82, 0.42)))
	theme.set_stylebox("background", "ProgressBar", UiStyle.box(Color(1, 1, 1, 0.14)))
	theme.set_stylebox("fill", "ProgressBar", UiStyle.box(UiStyle.ACCENT))
	theme.set_font_size("font_size", "ProgressBar", UiStyle.SIZE_XS)
	for bar: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, UiStyle.margins(UiStyle.box(Color(1, 1, 1, 0.04)), 2, 2))
		theme.set_stylebox("grabber", bar, UiStyle.box(Color(1, 1, 1, 0.22)))
		theme.set_stylebox("grabber_highlight", bar, UiStyle.box(Color(1, 1, 1, 0.4)))
		theme.set_stylebox("grabber_pressed", bar, UiStyle.box(UiStyle.ACCENT))


static func _panels(theme: Theme) -> void:
	var panel := UiStyle.margins(UiStyle.box(UiStyle.PANEL, UiStyle.LINE, 1), 16.0, 14.0)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_type_variation("CardPanel", "PanelContainer")
	var card := UiStyle.margins(UiStyle.box(UiStyle.PANEL_SOFT, UiStyle.LINE, 1), 14.0, 12.0)
	theme.set_stylebox("panel", "CardPanel", card)
	theme.set_type_variation("HudPanel", "PanelContainer")
	theme.set_stylebox("panel", "HudPanel", UiStyle.margins(UiStyle.box(UiStyle.HUD_PANEL), 10, 6))


static func _svg(body: String, width: int, height: int) -> ImageTexture:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">%s</svg>' % [
		width, height, body
	]
	return UiStyle.svg_texture(svg)


static func _hex(color: Color) -> String:
	return "#" + color.to_html(false)


## 켜고 끄는 스위치(46x24). 켜지면 호박색 바탕에 손잡이가 오른쪽.
static func _switch(on: bool) -> ImageTexture:
	var fill := _hex(UiStyle.ACCENT) if on else "#ffffff"
	var fill_opacity := 1.0 if on else 0.1
	var stroke := _hex(UiStyle.ACCENT) if on else "#ffffff"
	var knob := _hex(UiStyle.ACCENT_DARK) if on else _hex(UiStyle.TEXT_DIM)
	var knob_x := 34 if on else 12
	var body := (
		'<rect x="1" y="1" width="44" height="22" rx="11" fill="%s" fill-opacity="%.2f" '
		+ 'stroke="%s" stroke-opacity="0.35" stroke-width="1.5"/>'
		+ '<circle cx="%d" cy="12" r="7.5" fill="%s"/>'
	) % [fill, fill_opacity, stroke, knob_x, knob]
	return _svg(body, 46, 24)


static func _knob(color: Color) -> ImageTexture:
	var body := '<circle cx="10" cy="10" r="8" fill="%s" stroke="#0b0d10" stroke-width="2.5"/>' % [
		_hex(color)
	]
	return _svg(body, 20, 20)


static func _chevron_down(color: Color) -> ImageTexture:
	var body := (
		'<path d="M3 6 L8 11 L13 6" fill="none" stroke="%s" stroke-width="2.2" '
		+ 'stroke-linecap="round" stroke-linejoin="round"/>'
	) % [_hex(color)]
	return _svg(body, 16, 16)


static func _updown(color: Color) -> ImageTexture:
	var body := (
		'<path d="M4 9 L9 4 L14 9 M4 15 L9 20 L14 15" fill="none" stroke="%s" '
		+ 'stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
	) % [_hex(color)]
	return _svg(body, 18, 24)


static func _dot(color: Color, filled: bool) -> ImageTexture:
	var inner := '<circle cx="8" cy="8" r="3.5" fill="%s"/>' % [_hex(color)] if filled else ""
	var body := (
		'<circle cx="8" cy="8" r="6" fill="none" stroke="%s" stroke-width="1.6"/>' % [_hex(color)]
		+ inner
	)
	return _svg(body, 16, 16)
