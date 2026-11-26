extends RefCounted
## 사용자 설정 저장소. 감도 같은 값을 user://settings.cfg에 보관한다(웹에서는 브라우저 저장소).

const PATH := "user://settings.cfg"
const SENSITIVITY := "input/sensitivity_scale"
const BOT_COUNT := "match/bots"
const SERVER_ADDRESS := "match/server_address"
const GAME_MODE := "match/mode"
const UI_SCALE := "ui/scale"
const MIN_UI_SCALE := 0.8
const MAX_UI_SCALE := 1.4
const MIN_SENSITIVITY := 0.2
const MAX_SENSITIVITY := 4.0


## key는 "섹션/이름" 형식.
static func read(key: String, fallback: Variant) -> Variant:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return fallback
	var parts := key.split("/")
	return config.get_value(parts[0], parts[1], fallback)


static func write(key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	var parts := key.split("/")
	config.set_value(parts[0], parts[1], value)
	config.save(PATH)


static func ui_scale() -> float:
	return clampf(float(read(UI_SCALE, 1.0)), MIN_UI_SCALE, MAX_UI_SCALE)


static func sensitivity() -> float:
	return clampf(float(read(SENSITIVITY, 1.0)), MIN_SENSITIVITY, MAX_SENSITIVITY)
