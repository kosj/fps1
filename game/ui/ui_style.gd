extends RefCounted
## UI 디자인 토큰(색, 글꼴, 크기)과 자주 쓰는 부품. 모든 화면이 여기서 값을 가져와 같은 모양을 낸다.
##
## 방향(참고: Call of Duty Mobile/Modern Warfare 계열의 전술 UI):
## - 거의 검은 반투명 판 위에 흰 글씨, 강조는 호박색 하나만 쓴다. 아군 파랑, 적 빨강.
## - 글꼴은 좁은 굵은 고딕(Roboto Condensed), 큰 제목과 숫자는 Anton, 아이콘은 Font Awesome.
## - 모서리는 거의 각지게(2px), 선은 1px 흰색 10~20%.

const FONT_BODY := preload("res://game/ui/fonts/RobotoCondensed-Medium.ttf")
const FONT_BOLD := preload("res://game/ui/fonts/RobotoCondensed-Bold.ttf")
const FONT_DISPLAY := preload("res://game/ui/fonts/Anton-Regular.ttf")
const FONT_ICONS := preload("res://game/ui/fonts/icons.ttf")

const INK := Color(0.035, 0.04, 0.05)
const PANEL := Color(0.055, 0.065, 0.08, 0.88)
const PANEL_SOFT := Color(0.055, 0.065, 0.08, 0.66)
const HUD_PANEL := Color(0.02, 0.025, 0.03, 0.55)
const LINE := Color(1.0, 1.0, 1.0, 0.1)
const LINE_STRONG := Color(1.0, 1.0, 1.0, 0.24)
const TEXT := Color(0.93, 0.94, 0.95)
const TEXT_DIM := Color(0.64, 0.68, 0.73)
const TEXT_FAINT := Color(0.42, 0.46, 0.51)
const ACCENT := Color(0.96, 0.71, 0.24)
const ACCENT_DARK := Color(0.1, 0.075, 0.02)
const ALLY := Color(0.3, 0.64, 1.0)
const ENEMY := Color(1.0, 0.36, 0.3)
const NEUTRAL := Color(0.82, 0.84, 0.87)
const GOOD := Color(0.45, 0.86, 0.5)

## 글자 크기(캔버스 단위. 데스크톱 1280x720, 가로 휴대폰은 약 1040x480).
const SIZE_XS := 13
const SIZE_S := 15
const SIZE_M := 18
const SIZE_L := 22
const SIZE_XL := 30
const SIZE_XXL := 44

## Font Awesome 아이콘 이름 -> 코드(tools/ui/make_fonts.py가 남긴 것만 있다).
const ICONS := {
	"location-crosshairs": 0xf601,
	"crosshairs": 0xf05b,
	"angles-up": 0xf102,
	"angles-down": 0xf103,
	"rotate": 0xf2f1,
	"right-left": 0xf362,
	"gun": 0xe19b,
	"bomb": 0xf1e2,
	"bolt": 0xf0e7,
	"hand-fist": 0xf6de,
	"pause": 0xf04c,
	"table-list": 0xf00b,
	"skull": 0xf54c,
	"play": 0xf04b,
	"users": 0xf0c0,
	"bullseye": 0xf140,
	"gear": 0xf013,
	"power-off": 0xf011,
	"lock": 0xf023,
	"check": 0xf00c,
	"chevron-right": 0xf054,
	"chevron-left": 0xf053,
	"user": 0xf007,
	"trophy": 0xf091,
	"medal": 0xf5a2,
	"star": 0xf005,
	"xmark": 0xf00d,
	"volume-high": 0xf028,
	"music": 0xf001,
	"display": 0xe163,
	"mobile-screen": 0xf3cf,
	"flag": 0xf024,
	"wifi": 0xf1eb,
	"clock": 0xf017,
	"map-location-dot": 0xf5a0,
	"person-rifle": 0xe54e,
	"burst": 0xe4dc,
	"heart-pulse": 0xf21e,
	"shield-halved": 0xf3ed,
	"person-running": 0xf70c,
	"eye": 0xf06e,
	"sliders": 0xf1de,
	"keyboard": 0xf11c,
	"circle-info": 0xf05a,
	"arrow-up": 0xf062,
	"arrow-down": 0xf063,
	"right-from-bracket": 0xf2f5,
	"ranking-star": 0xe561,
}

static var _caps: FontVariation
static var _display: FontVariation


## 아이콘 한 글자.
static func glyph(icon_name: String) -> String:
	return String.chr(int(ICONS.get(icon_name, 0x3f)))


## 대문자 작은 제목용: 굵은 글꼴에 자간을 넓힌다.
static func caps_font() -> FontVariation:
	if _caps == null:
		_caps = FontVariation.new()
		_caps.base_font = FONT_BOLD
		_caps.spacing_glyph = 1
	return _caps


## Anton에 자간을 조금 준 큰 제목 글꼴.
static func display_font() -> FontVariation:
	if _display == null:
		_display = FontVariation.new()
		_display.base_font = FONT_DISPLAY
		_display.spacing_glyph = 1
	return _display


static func label(
	text: String, size := SIZE_M, color := TEXT, font: Font = null
) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if font != null:
		node.add_theme_font_override("font", font)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## 작은 대문자 머리말(예: CALLSIGN, GAME MODE).
static func caption(text: String, color := TEXT_DIM, size := SIZE_XS) -> Label:
	return label(text.to_upper(), size, color, caps_font())


static func icon(icon_name: String, size := SIZE_L, color := TEXT) -> Label:
	var node := label(glyph(icon_name), size, color, FONT_ICONS)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return node


## 판 모양. radius는 모서리, border는 테두리 두께(0이면 없음).
static func box(
	color: Color, border_color := Color(0, 0, 0, 0), border := 0, radius := 2
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = radius > 0
	return style


## 왼쪽에 굵은 색 띠가 있는 판(선택된 항목, 팀 표시).
static func stripe_box(color: Color, stripe: Color, width := 4) -> StyleBoxFlat:
	var style := box(color)
	style.border_color = stripe
	style.border_width_left = width
	return style


static func margins(style: StyleBox, horizontal: float, vertical: float) -> StyleBox:
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


## 판(PanelContainer)을 만든다.
static func panel(style: StyleBox) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", style)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func row(separation := 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func column(separation := 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func spacer(width := 0.0, height := 0.0, expand := false) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(width, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## 아군/적/중립 색. relative: 1 아군, -1 적, 0 중립.
static func side_color(relative: int) -> Color:
	if relative > 0:
		return ALLY
	return ENEMY if relative < 0 else NEUTRAL


## 런타임에 SVG 문자열로 작은 텍스처를 만든다(스위치, 슬라이더 손잡이 같은 테마 아이콘).
static func svg_texture(svg: String, scale := 1.0) -> ImageTexture:
	var image := Image.new()
	image.load_svg_from_string(svg, scale)
	return ImageTexture.create_from_image(image)
