extends SceneTree
## 웹 빌드의 에셋 팩을 만든다: game/과 maps/ 아래의 가져온(import) 텍스처·모델·소리를 한 팩에 담는다.
## 본 팩(index.pck)은 내보내기 설정(Web 프리셋의 exclude_filter)에서 이 파일들을 뺀다.
## 에셋이 그대로면 팩 이름(내용 해시)도 그대로라, 휴대폰은 코드만 바뀐 새 빌드에서 에셋을 다시 받지 않는다.
##
## 실행(가져오기를 마친 프로젝트에서):
##   godot --headless --script res://tools/web/make_asset_pack.gd -- <출력.pck>
## 출력: ASSET_HASH <원본 파일과 .import 파일, 엔진 버전으로 만든 sha256>
##
## 본 팩의 UID 목록에는 빠진 에셋이 없으므로, 에셋의 UID와 경로를 UIDS 파일로 함께 넣어
## game/core/asset_pack.gd가 팩을 끼운 직후 등록한다(그래야 "invalid UID" 경고 없이 바로 찾는다).

const ROOTS := ["res://game", "res://maps"]
const EXTENSIONS := ["jpg", "png", "glb", "ogg", "wav"]
const UIDS := "res://.godot/asset_uids.txt"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- <output.pck>")
		quit(2)
		return
	var sources: Array[String] = []
	for root: String in ROOTS:
		_collect(root, sources)
	sources.sort()
	var packer := PCKPacker.new()
	if packer.pck_start(args[0]) != OK:
		push_error("cannot write " + args[0])
		quit(1)
		return
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(Engine.get_version_info()["string"].to_utf8_buffer())
	var count := 0
	var uids := PackedStringArray()
	for source: String in sources:
		var import_path := source + ".import"
		var outputs := _imported_files(import_path)
		if outputs.is_empty():
			push_error("no imported files for " + source)
			quit(1)
			return
		hashing.update(source.to_utf8_buffer())
		hashing.update(FileAccess.get_file_as_bytes(source))
		hashing.update(FileAccess.get_file_as_bytes(import_path))
		var uid := _uid(import_path)
		if not uid.is_empty():
			uids.append("%s %s" % [uid, source])
		packer.add_file(import_path, ProjectSettings.globalize_path(import_path))
		for output: String in outputs:
			packer.add_file(output, ProjectSettings.globalize_path(output))
			count += 1
	var uid_file := args[0].get_base_dir().path_join("asset_uids.txt")
	var writer := FileAccess.open(uid_file, FileAccess.WRITE)
	writer.store_string("\n".join(uids) + "\n")
	writer.close()
	packer.add_file(UIDS, uid_file)
	packer.flush()
	print("asset pack: %d sources, %d imported files -> %s" % [sources.size(), count, args[0]])
	print("ASSET_HASH ", hashing.finish().hex_encode())
	quit(0)


func _collect(dir: String, into: Array[String]) -> void:
	for name in DirAccess.get_files_at(dir):
		var path := dir.path_join(name)
		if name.get_extension().to_lower() in EXTENSIONS and FileAccess.file_exists(path + ".import"):
			into.append(path)
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), into)


## 가져오기 결과 파일들([deps] dest_files).
func _imported_files(import_path: String) -> Array[String]:
	var config := ConfigFile.new()
	var result: Array[String] = []
	if config.load(import_path) != OK:
		return result
	for path: String in config.get_value("deps", "dest_files", []):
		if FileAccess.file_exists(path):
			result.append(path)
	return result


func _uid(import_path: String) -> String:
	var config := ConfigFile.new()
	if config.load(import_path) != OK:
		return ""
	return str(config.get_value("remap", "uid", ""))
