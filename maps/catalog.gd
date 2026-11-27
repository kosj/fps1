extends RefCounted
## 경기용 맵 목록. 메뉴의 맵 선택, 서버의 --map, 판마다 맵을 바꾸는 순환이 함께 쓴다.

## 각 항목은 [짧은 이름, 화면에 보이는 이름, 장면 경로].
const MAPS := [
	["depot", "Depot", "res://maps/depot/depot.tscn"],
	["compound", "Compound", "res://maps/compound/compound.tscn"],
]


static func names() -> Array:
	return MAPS.map(func(entry: Array) -> String: return entry[0])


static func titles() -> Array:
	return MAPS.map(func(entry: Array) -> String: return entry[1])


## 짧은 이름을 장면 경로로 바꾼다. 경로(res://...)를 그대로 줘도 된다. 모르는 이름은 첫 맵.
static func path(map_name: String) -> String:
	if map_name.begins_with("res://"):
		return map_name
	for entry: Array in MAPS:
		if entry[0] == map_name:
			return entry[2]
	return MAPS[0][2]


## 장면 경로의 짧은 이름. 목록에 없는 맵(연습장, 테스트용)은 경로를 그대로 돌려준다.
static func name_of(scene_path: String) -> String:
	for entry: Array in MAPS:
		if entry[2] == scene_path:
			return entry[0]
	return scene_path


## 순환에서 다음 차례의 맵 이름. 목록에 없는 맵이면 그대로 둔다.
static func next(map_name: String) -> String:
	var all := names()
	var index := all.find(map_name)
	if index < 0:
		return map_name
	return all[(index + 1) % all.size()]
