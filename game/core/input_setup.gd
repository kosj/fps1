extends Node
## 입력 액션을 코드로 등록한다.
## project.godot에 직렬화된 이벤트 대신 여기서 관리해 변경 이력을 읽기 쉽게 한다.

const KEY_ACTIONS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"sprint": KEY_SHIFT,
	"crouch": KEY_CTRL,
	"reload": KEY_R,
}

const MOUSE_ACTIONS := {
	"fire": MOUSE_BUTTON_LEFT,
	"aim": MOUSE_BUTTON_RIGHT,
}


func _ready() -> void:
	for action: String in KEY_ACTIONS:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_ACTIONS[action]
		_register(action, key_event)
	for action: String in MOUSE_ACTIONS:
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_ACTIONS[action]
		_register(action, mouse_event)


func _register(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_add_event(action, event)
