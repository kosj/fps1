extends Node
## 아나운서 음성과 판 결과 음악. 경기 화면(game/net/match_view.gd)이 판의 흐름을 보고
## announce()로 일을 넘기면, 한 번에 한 마디씩 차례로 말한다.

const Settings := preload("res://game/core/settings.gd")
const LINES := {
	"start_tdm": preload("res://game/audio/voice/start_tdm.ogg"),
	"start_dom": preload("res://game/audio/voice/start_dom.ogg"),
	"victory": preload("res://game/audio/voice/victory.ogg"),
	"defeat": preload("res://game/audio/voice/defeat.ogg"),
	"draw": preload("res://game/audio/voice/draw.ogg"),
	"zone_taken": preload("res://game/audio/voice/zone_taken.ogg"),
	"zone_lost": preload("res://game/audio/voice/zone_lost.ogg"),
	"one_minute": preload("res://game/audio/voice/one_minute.ogg"),
}
const STINGERS := {
	"victory": preload("res://game/audio/music/victory.ogg"),
	"defeat": preload("res://game/audio/music/defeat.ogg"),
}
const VOICE_DB := -2.0
const STINGER_DB := -6.0
## 밀려 있는 말이 이만큼이면 덜 중요한 말(거점)은 버린다.
const MAX_QUEUE := 2

## 점령전이면 시작할 때 "거점을 확보하라"고 말한다. 경기 화면이 거점을 보면 켠다.
var domination := false

var _voice: AudioStreamPlayer
var _stinger: AudioStreamPlayer
var _queue: Array = []


func _ready() -> void:
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = VOICE_DB
	add_child(_voice)
	_stinger = AudioStreamPlayer.new()
	_stinger.volume_db = STINGER_DB
	add_child(_stinger)


## event: "start", "victory", "defeat", "draw", "zone_taken", "zone_lost", "one_minute".
## "start"는 실제로 말할 때 팀전인지 점령전인지 보고 고른다.
func announce(event: String) -> void:
	if event.begins_with("zone") and _queue.size() >= MAX_QUEUE:
		return
	if STINGERS.has(event) and _stinger != null and music_enabled():
		_stinger.stream = STINGERS[event]
		_stinger.play()
	_queue.append(event)


## 아직 말하지 않은 차례(테스트에서 무엇을 말하려 했는지 본다).
func pending() -> Array:
	return _queue.duplicate()


static func music_enabled() -> bool:
	return bool(Settings.read(Settings.MUSIC, true))


func _process(_delta: float) -> void:
	if _voice.playing or _queue.is_empty():
		return
	var event: String = _queue.pop_front()
	if event == "start":
		event = "start_dom" if domination else "start_tdm"
	_voice.stream = LINES.get(event)
	if _voice.stream != null:
		_voice.play()
