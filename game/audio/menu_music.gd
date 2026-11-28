extends AudioStreamPlayer
## 시작 화면 음악. 32초짜리 이음매 없는 반복(tools/audio/compose_menu.py로 만든다).
## 설정에서 음악을 끄면 조용히 멈춘다.

const Settings := preload("res://game/core/settings.gd")
const LOOP := preload("res://game/audio/music/menu_loop.ogg")
const VOLUME_DB := -14.0
const FADE_IN := 2.0


func _ready() -> void:
	var loop := LOOP.duplicate() as AudioStreamOggVorbis
	loop.loop = true
	stream = loop
	volume_db = -60.0
	refresh()


## 설정을 다시 읽어 켜거나 끈다. 켤 때는 천천히 키운다.
func refresh() -> void:
	var enabled := bool(Settings.read(Settings.MUSIC, true))
	if enabled and not playing:
		play()
		create_tween().tween_property(self, "volume_db", VOLUME_DB, FADE_IN)
	elif not enabled and playing:
		stop()
		volume_db = -60.0
