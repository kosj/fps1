extends RefCounted
## 플레이어 이름(콜사인). 웹 빌드에 한글 글꼴이 없어 영문, 숫자, 몇 가지 기호만 쓴다.
## 서버는 클라이언트가 보낸 이름을 믿지 않고 다시 다듬는다.

const Settings := preload("res://game/core/settings.gd")
const KEY := "player/name"
const MAX_LENGTH := 16
const ALLOWED := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-."
const BOT_NAMES := [
	"Viper", "Ghost", "Nomad", "Rook", "Havoc", "Sable", "Flint", "Mako",
	"Dusk", "Echo", "Brick", "Wren", "Talon", "Rust", "Onyx", "Kite",
]


## 허용된 글자만 남기고, 공백을 하나로 줄이고, 길이를 자른다. 남는 게 없으면 빈 문자열.
static func sanitize(text: String) -> String:
	var kept := ""
	for character in text:
		if ALLOWED.contains(character):
			kept += character
	while kept.contains("  "):
		kept = kept.replace("  ", " ")
	return kept.strip_edges().left(MAX_LENGTH).strip_edges()


## 저장된 이름. 없으면 무작위 이름을 만들어 저장한다.
static func saved() -> String:
	var name := sanitize(str(Settings.read(KEY, "")))
	if name.is_empty():
		name = "Soldier%04d" % (randi() % 10000)
		Settings.write(KEY, name)
	return name


static func bot_name(index: int) -> String:
	return "%s" % BOT_NAMES[index % BOT_NAMES.size()]


## taken에 이미 있는 이름이면 뒤에 숫자를 붙여 겹치지 않게 한다.
static func unique(name: String, taken: Array) -> String:
	if not taken.has(name):
		return name
	var number := 2
	while taken.has("%s%d" % [name.left(MAX_LENGTH - 2), number]):
		number += 1
	return "%s%d" % [name.left(MAX_LENGTH - 2), number]


## 처음 이름: 내 이름은 저장된 콜사인, 봇은 정해진 콜사인, 접속한 사람은 이름을 보내 올 때까지 번호.
## kind는 game_session의 참가자 종류("local", "bot", "peer"), 봇 id는 1000부터다.
static func first_name(id: int, kind: String) -> String:
	match kind:
		"local":
			return saved()
		"bot":
			return bot_name(id - 1000)
	return "P-%d" % (id % 1000)


## 참가자(peers의 id)의 이름을 바꾼다. 다듬고 다른 사람과 겹치지 않게 한다. 바뀌었으면 true.
static func rename(peers: Dictionary, id: int, wanted: String) -> bool:
	var clean := sanitize(wanted)
	if not peers.has(id) or clean.is_empty():
		return false
	var taken: Array = []
	for other: int in peers:
		if other != id:
			taken.append(peers[other]["name"])
	peers[id]["name"] = unique(clean, taken)
	return true
