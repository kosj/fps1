extends Node
## 웹 빌드는 큰 에셋(텍스처, 모델, 소리)을 본 팩과 따로 받는다(tools/web/stage_site.py).
## 페이지가 그 팩을 assets.pck라는 이름으로 미리 받아 두면, 다른 무엇이 에셋을 읽기 전에
## 여기서 끼워 넣는다. 그래서 자동 로드 목록의 맨 앞에 둔다.
## 데스크톱과 서버 빌드는 에셋이 본 팩에 들어 있어서 할 일이 없다.

const PACK := "assets.pck"
## 팩에 담긴 에셋의 "uid://... res://경로" 목록(tools/web/make_asset_pack.gd).
const UIDS := "res://.godot/asset_uids.txt"

## 에셋 팩을 끼워 넣었는지(웹 빌드에서만 true).
static var mounted := false


func _init() -> void:
	if not OS.has_feature("web"):
		return
	mounted = ProjectSettings.load_resource_pack(PACK)
	if not mounted:
		push_error("web asset pack %s is missing: textures, models and sounds will not load" % PACK)
		return
	register_uids(FileAccess.get_file_as_string(UIDS))


## 본 팩의 UID 목록에 없는 에셋 UID를 등록한다. 한 줄에 "uid://... res://경로".
static func register_uids(text: String) -> int:
	var added := 0
	for line in text.split("\n", false):
		var parts := line.split(" ", false)
		if parts.size() != 2:
			continue
		var id := ResourceUID.text_to_id(parts[0])
		if id == ResourceUID.INVALID_ID or ResourceUID.has_id(id):
			continue
		ResourceUID.add_id(id, parts[1])
		added += 1
	return added
