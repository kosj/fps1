extends ColorRect
## 섬광탄에 눈이 먼 화면: 하얗게 덮였다가 천천히 걷히고, 그동안 소리가 먹먹해지며 귀가 울린다.
## HUD 위에 하나만 만들어 두고 apply()로 다시 쓴다.

const SfxSynth := preload("res://game/audio/sfx_synth.gd")
const Grenades := preload("res://game/combat/grenades.gd")
## 완전히 하얀 상태로 있는 시간의 비율. 그 뒤로 걷힌다.
const HOLD := 0.35
const MUFFLED_HZ := 900.0
const CLEAR_HZ := 20000.0

var _left := 0.0
var _total := 1.0
var _strength := 0.0
var _ring: AudioStreamPlayer
var _filter: AudioEffectLowPassFilter


## hud(CanvasLayer) 위의 눈부심을 찾아(없으면 만들어) amount(0~1)만큼 눈을 멀게 한다.
static func apply(hud: Node, amount: float) -> void:
	if hud == null or amount <= 0.0:
		return
	var blind := hud.get_node_or_null("FlashBlind")
	if blind == null:
		blind = new()
		blind.name = "FlashBlind"
		hud.add_child(blind)
	blind.call("start", amount)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1.0, 1.0, 0.97, 0.0)
	_ring = AudioStreamPlayer.new()
	_ring.stream = SfxSynth.ringing(Grenades.FLASH_TIME)
	add_child(_ring)


func start(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	# 이미 눈이 먼 상태면 더 센 쪽을 따른다.
	if amount * Grenades.FLASH_TIME < _left:
		return
	_strength = amount
	_total = 0.5 + Grenades.FLASH_TIME * amount
	_left = _total
	_ring.volume_db = linear_to_db(0.25 + 0.75 * amount) + 4.0
	_ring.play()
	_set_muffle(true)


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	var progress := 1.0 - _left / _total
	var cover := 1.0 if progress < HOLD else 1.0 - (progress - HOLD) / (1.0 - HOLD)
	color.a = clampf(cover * (0.55 + 0.45 * _strength), 0.0, 1.0)
	if _filter != null:
		_filter.cutoff_hz = lerpf(MUFFLED_HZ, CLEAR_HZ, pow(1.0 - cover, 2.0))
	if _left <= 0.0:
		_set_muffle(false)


func _exit_tree() -> void:
	_set_muffle(false)


## 주 버스에 저역 통과 필터를 걸었다 뺀다(게임 소리 전체가 먹먹해진다. 귀울림도 함께 깎인다).
func _set_muffle(on: bool) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if on and _filter == null:
		_filter = AudioEffectLowPassFilter.new()
		_filter.cutoff_hz = MUFFLED_HZ
		AudioServer.add_bus_effect(bus, _filter)
	elif not on and _filter != null:
		for index in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, index) == _filter:
				AudioServer.remove_bus_effect(bus, index)
				break
		_filter = null
