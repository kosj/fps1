extends VBoxContainer
## 무기와 탄약: 무기 옆모습, 탄창 남은 수(크게)와 탄창 크기, 무기 이름, 수류탄·섬광탄 수.
## 탄이 적으면 빨갛게, 재장전 중이면 호박색 RELOADING.

const UiStyle := preload("res://game/ui/ui_style.gd")
const Armory := preload("res://game/weapons/armory.gd")

var _icon: TextureRect
var _name: Label
var _ammo: Label
var _magazine: Label
var _reloading: Label
var _frags: Label
var _flashes: Label
var _frag_icon: Label
var _flash_icon: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 0)
	_reloading = UiStyle.caption("RELOADING", UiStyle.ACCENT, UiStyle.SIZE_S)
	_reloading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reloading.visible = false
	add_child(_reloading)
	var top := UiStyle.row(10)
	top.alignment = BoxContainer.ALIGNMENT_END
	add_child(top)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(104.0, 44.0)
	_icon.modulate = Color(1.0, 1.0, 1.0, 0.9)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_icon)
	var count := UiStyle.row(2)
	count.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(count)
	_ammo = _outlined(UiStyle.label("30", UiStyle.SIZE_XXL, UiStyle.TEXT, UiStyle.FONT_DISPLAY))
	count.add_child(_ammo)
	_magazine = _outlined(UiStyle.label("/30", UiStyle.SIZE_L, UiStyle.TEXT_DIM, UiStyle.FONT_BOLD))
	_magazine.size_flags_vertical = Control.SIZE_SHRINK_END
	_magazine.custom_minimum_size = Vector2(0.0, 0.0)
	count.add_child(_magazine)
	var bottom := UiStyle.row(12)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	add_child(bottom)
	_name = _outlined(UiStyle.caption("", UiStyle.TEXT_DIM, UiStyle.SIZE_XS))
	bottom.add_child(_name)
	_frag_icon = UiStyle.icon("bomb", UiStyle.SIZE_S)
	bottom.add_child(_frag_icon)
	_frags = _outlined(UiStyle.label("2", UiStyle.SIZE_M, UiStyle.TEXT, UiStyle.FONT_BOLD))
	bottom.add_child(_frags)
	_flash_icon = UiStyle.icon("bolt", UiStyle.SIZE_S)
	bottom.add_child(_flash_icon)
	_flashes = _outlined(UiStyle.label("1", UiStyle.SIZE_M, UiStyle.TEXT, UiStyle.FONT_BOLD))
	bottom.add_child(_flashes)


## 작은 화면(터치)에서는 무기 그림을 줄인다.
func set_compact(compact: bool) -> void:
	_icon.custom_minimum_size = Vector2(78.0, 32.0) if compact else Vector2(104.0, 44.0)
	_ammo.add_theme_font_size_override("font_size", 34 if compact else UiStyle.SIZE_XXL)


func set_weapon(weapon_id: int, slot: int) -> void:
	_icon.texture = Armory.ICONS[weapon_id] if weapon_id < Armory.ICONS.size() else null
	_name.text = "%d  %s" % [slot + 1, Armory.title(weapon_id).to_upper()]


func set_ammo(ammo: int, magazine_size: int) -> void:
	_ammo.text = str(ammo)
	_magazine.text = "/%d" % magazine_size
	var low := ammo <= magazine_size / 5
	_ammo.add_theme_color_override("font_color", UiStyle.ENEMY if low else UiStyle.TEXT)


func set_reloading(reloading: bool) -> void:
	_reloading.visible = reloading


func set_grenades(frags: int, flashes: int) -> void:
	_frags.text = str(frags)
	_flashes.text = str(flashes)
	for pair: Array in [[_frag_icon, _frags, frags], [_flash_icon, _flashes, flashes]]:
		var alpha := 1.0 if int(pair[2]) > 0 else 0.35
		(pair[0] as Control).modulate.a = alpha
		(pair[1] as Control).modulate.a = alpha


static func _outlined(label: Label) -> Label:
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("outline_size", 4)
	return label
