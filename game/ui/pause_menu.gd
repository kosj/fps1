extends CanvasLayer
## 일시 정지 화면. Esc로 마우스 잠금이 풀리면 나타난다.
## 네트워크 대전은 멈추지 않으므로 화면만 가리고 조작을 쉰다.

signal resume_requested
signal menu_requested
signal sensitivity_changed(value: float)

const MenuKit := preload("res://game/ui/menu_kit.gd")
const Settings := preload("res://game/core/settings.gd")

var resume_button: Button
var menu_button: Button


func _ready() -> void:
	layer = 10
	var column := MenuKit.centered_column(self, Color(0.0, 0.0, 0.0, 0.55))
	column.add_child(MenuKit.label("PAUSED", 40))
	resume_button = MenuKit.button("RESUME")
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	column.add_child(resume_button)
	column.add_child(
		MenuKit.sensitivity_row(func(value: float) -> void: sensitivity_changed.emit(value))
	)
	column.add_child(MenuKit.ui_scale_row(get_tree()))
	if Settings.is_mobile():
		column.add_child(MenuKit.label("Left side: move (push fully forward to sprint)", 18))
		column.add_child(MenuKit.label("Right side or FIRE: drag to look", 18))
		column.add_child(MenuKit.label("DUCK while sprinting: slide    JUMP at a ledge: climb", 18))
	else:
		column.add_child(MenuKit.label("WASD move    Shift sprint    Ctrl crouch / slide", 18))
		column.add_child(MenuKit.label("Space jump / mantle    R reload", 18))
		column.add_child(MenuKit.label("LMB fire    RMB aim    1-4 or wheel: weapons", 18))
	menu_button = MenuKit.button("MAIN MENU")
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	column.add_child(menu_button)
