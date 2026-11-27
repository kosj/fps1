extends RefCounted
## 실행 인자. 명령줄의 --이름=값 과, 웹 빌드에서는 주소창의 ?connect= / ?map= 을 읽는다.


static func parse() -> Dictionary:
	var args := {}
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var parts := argument.substr(2).split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	# 웹 빌드에는 명령줄이 없으므로 주소창의 ?connect=호스트:포트 를 읽는다.
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		for pair in query.trim_prefix("?").split("&", false):
			var parts := pair.split("=", true, 1)
			if parts.size() == 2 and parts[0] in ["connect", "map"]:
				args[parts[0]] = parts[1].uri_decode()
	return args
