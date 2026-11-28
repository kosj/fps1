extends RefCounted
## 임시 효과음을 코드로 합성한다.
## ElevenLabs로 만든 사운드가 들어오기 전까지 타격감과 타이밍 조정에 쓴다. 바이너리 에셋이 필요 없다.

const MIX_RATE := 22050


## 총성: 날카로운 초기 노이즈 + 저역 몸통 + 짧은 저주파 타격.
static func gunshot() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var count := int(MIX_RATE * 0.22)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.3)
		var crack := noise * exp(-t * 90.0) * 0.8
		var body := low * exp(-t * 22.0) * 0.9
		var thump := sin(TAU * 70.0 * t) * exp(-t * 30.0) * 0.7
		samples[i] = crack + body + thump
	return _to_stream(samples)


## 짧은 감쇠 사인음. 히트마커와 처치 확인음에 쓴다.
static func tone(frequency: float, duration: float, decay: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / MIX_RATE
		var attack := minf(t * 400.0, 1.0)
		samples[i] = sin(TAU * frequency * t) * exp(-t * decay) * attack * 0.6
	return _to_stream(samples)


## 근접 공격의 휘두르는 소리: 높아졌다 낮아지는 잡음.
static func whoosh() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var count := int(MIX_RATE * 0.28)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	var band := 0.0
	for i in count:
		var t := float(i) / count
		# 필터가 열렸다 닫힌다: 바람을 가르는 소리.
		var open := sin(PI * t)
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.05 + 0.35 * open)
		band = lerpf(band, low, 0.5)
		samples[i] = (low - band * 0.6) * open * open * 1.6
	return _to_stream(samples)


## 섬광탄을 맞은 뒤의 귀울림: 사인음 두 개가 살짝 어긋나 맥놀이를 만든다.
## 먹먹해진 소리(저역 통과)를 지나도 들리도록 너무 높지 않게 둔다.
static func ringing(duration: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / MIX_RATE
		var fade := minf(t * 30.0, 1.0) * pow(1.0 - float(i) / count, 1.6)
		samples[i] = (sin(TAU * 1180.0 * t) + sin(TAU * 1186.0 * t)) * 0.22 * fade
	return _to_stream(samples)


## 두 음이 이어지는 처치 확인음.
static func kill_confirm() -> AudioStreamWAV:
	var count := int(MIX_RATE * 0.22)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / MIX_RATE
		var frequency := 1100.0 if t < 0.07 else 1650.0
		var local := t if t < 0.07 else t - 0.07
		samples[i] = sin(TAU * frequency * t) * exp(-local * 22.0) * 0.55
	return _to_stream(samples)


## 금속성 딸깍 소리. 빈 탄창과 재장전에 쓴다.
static func click(brightness: float, duration: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, brightness)
		var ring := sin(TAU * 2400.0 * t) * 0.3
		samples[i] = (low + ring) * exp(-t * 70.0) * 0.6
	return _to_stream(samples)


## 둔탁한 발소리.
static func footstep() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var count := int(MIX_RATE * 0.12)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.08)
		samples[i] = low * exp(-t * 35.0) * 1.6
	return _to_stream(samples)


static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
