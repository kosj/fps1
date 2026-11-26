extends Node
## 헤드리스 메뉴 테스트: 시작 화면이 뜨고, 버튼으로 봇 대전이 시작되고, 일시 정지 화면이 준비되는지 확인한다.
## 실행: godot --headless --fixed-fps 60 res://tests/smoke/menu_smoke.tscn

const MAIN_SCENE := preload("res://game/main.tscn")

var _game: Node
var _tick := 0
var _failures := PackedStringArray()


func _ready() -> void:
	_game = MAIN_SCENE.instantiate()
	add_child(_game)


func _physics_process(_delta: float) -> void:
	_tick += 1
	match _tick:
		5:
			var menu: Node = _game.call("menu")
			_expect(menu != null, "no main menu without command line arguments")
			_expect(not _game.call("is_started"), "match started before a menu choice")
			if menu != null:
				menu.get("bot_count").set("value", 3)
				menu.get("play_button").emit_signal("pressed")
		30:
			_expect(_game.call("is_started"), "PLAY VS BOTS did not start the match")
			_expect(_game.call("menu") == null, "main menu is still open after starting")
			_expect(_game.call("local_player") != null, "no local player after starting")
			var count: int = _game.call("participant_count")
			_expect(count == 4, "expected the player and 3 bots, found %d participants" % count)
			var pause: Node = _game.call("pause_menu")
			_expect(pause != null, "no pause menu was created")
			if pause != null:
				_expect(pause.get("resume_button") != null, "pause menu has no resume button")
				pause.emit_signal("sensitivity_changed", 1.5)
		40:
			var player: Node = _game.call("local_player")
			var scale: float = player.get("sensitivity_scale")
			_expect(absf(scale - 1.5) < 0.001, "pause menu sensitivity did not reach the player")
		240:
			# 봇 대전이 메뉴에서 시작한 뒤에도 오류 없이 몇 초간 돈다.
			for failure in _failures:
				printerr("MENU SMOKE FAIL ", failure)
			print("menu smoke: %d failures" % _failures.size())
			get_tree().quit(1 if _failures.size() > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("tick %d: %s" % [_tick, message])
