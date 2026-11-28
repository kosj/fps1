extends VBoxContainer
## 죽었을 때 가운데 아래에 뜨는 카드: KILLED BY / 이름 / RESPAWNING...

const UiStyle := preload("res://game/ui/ui_style.gd")

var _caption: Label
var _name: Label
var _respawn: Label
var _dots := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 0)
	_caption = UiStyle.caption("KILLED BY", UiStyle.TEXT_DIM, UiStyle.SIZE_S)
	_name = UiStyle.label("", UiStyle.SIZE_XL, UiStyle.ENEMY, UiStyle.display_font())
	_respawn = UiStyle.caption("RESPAWNING", UiStyle.TEXT, UiStyle.SIZE_S)
	for label: Label in [_caption, _name, _respawn]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		label.add_theme_constant_override("outline_size", 4)
		add_child(label)


## killer가 비어 있으면 RESPAWNING만 보인다.
func show_killer(killer: String) -> void:
	_name.text = killer
	_caption.visible = not killer.is_empty()
	_name.visible = not killer.is_empty()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_dots = fmod(_dots + delta * 2.5, 4.0)
	_respawn.text = "RESPAWNING" + ".".repeat(int(_dots))
