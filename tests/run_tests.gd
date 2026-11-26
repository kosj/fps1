extends SceneTree
## 헤드리스 테스트 러너.
## 실행: godot --headless --script res://tests/run_tests.gd
## 각 스위트의 test_ 로 시작하는 메서드를 호출한다. 빈 문자열이면 통과, 아니면 실패 메시지.

const SUITES := {
	"move_math": preload("res://tests/test_move_math.gd"),
	"weapon_state": preload("res://tests/test_weapon_state.gd"),
	"core": preload("res://tests/test_core.gd"),
}


func _init() -> void:
	var passed := 0
	var failed := 0
	for suite_name: String in SUITES:
		var suite: RefCounted = SUITES[suite_name].new()
		for method: Dictionary in suite.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var message: String = suite.call(method_name)
			if message.is_empty():
				passed += 1
			else:
				failed += 1
				printerr("FAIL %s.%s: %s" % [suite_name, method_name, message])
	print("tests: %d passed, %d failed" % [passed, failed])
	if passed == 0 and failed == 0:
		printerr("no tests were found")
		quit(1)
		return
	quit(1 if failed > 0 else 0)
