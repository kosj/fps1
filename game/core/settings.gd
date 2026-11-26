extends RefCounted
## 사용자 설정 저장소. 감도 같은 값을 user://settings.cfg에 보관한다(웹에서는 브라우저 저장소).

const PATH := "user://settings.cfg"
const SENSITIVITY := "input/sensitivity_scale"
const BOT_COUNT := "match/bots"
const SERVER_ADDRESS := "match/server_address"
const GAME_MODE := "match/mode"
const UI_SCALE := "ui/scale"
const MIN_UI_SCALE := 0.8
const MAX_UI_SCALE := 2.0
## 휴대폰은 화면이 작아 같은 배율로는 글자가 작게 보이므로 기본값을 키운다.
const MOBILE_UI_SCALE := 1.5
const MIN_SENSITIVITY := 0.2
const MAX_SENSITIVITY := 4.0

static var _mobile := -1


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


## 휴대폰이나 태블릿의 브라우저/앱인지. 한 번 판단한 결과를 기억한다.
static func is_mobile() -> bool:
	if _mobile < 0:
		var mobile := OS.has_feature("mobile")
		mobile = mobile or OS.has_feature("web_android") or OS.has_feature("web_ios")
		if not mobile and OS.has_feature("web"):
			# 엔진이 기기를 구분하지 못하는 브라우저를 위해, 주 입력 장치가 손가락인지 직접 묻는다.
			var script := "(navigator.maxTouchPoints > 0 && matchMedia('(pointer: coarse)').matches) ? 1 : 0"
			mobile = int(JavaScriptBridge.eval(script, true)) == 1
		_mobile = 1 if mobile else 0
	return _mobile == 1


static func ui_scale() -> float:
	var fallback := MOBILE_UI_SCALE if is_mobile() else 1.0
	return clampf(float(read(UI_SCALE, fallback)), MIN_UI_SCALE, MAX_UI_SCALE)


static func sensitivity() -> float:
	return clampf(float(read(SENSITIVITY, 1.0)), MIN_SENSITIVITY, MAX_SENSITIVITY)
