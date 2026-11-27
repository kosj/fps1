extends CanvasLayer
## 서버 접속을 맡는다: 접속 중 안내, 실패했을 때 다시 시도, 끊겼을 때 알림.
## 무료 호스팅의 서버는 쉬고 있다가 첫 접속 때 깨어나는 데 1분쯤 걸리므로, 바로 포기하지 않고 기다린다.

signal connected
## 끝내 접속하지 못했거나(gave_up) 경기 중 끊겼을 때. reason은 사용자에게 보여 줄 영어 문구.
signal failed(reason: String)

const RETRY_DELAY := 3.0
const MAX_WAIT := 150.0
## 접속은 됐는데 이 시간 동안 스냅샷이 하나도 오지 않으면 서버와 게임의 버전이 다른 것으로 본다.
## (새 버전을 올린 직후 몇 분간 서버와 웹 빌드가 엇갈린다.)
const SILENT_LIMIT := 8.0

var _url := ""
var _waiting := 0.0
var _retry_in := -1.0
var _online := false
var _silent := 0.0
var _label: Label


func _ready() -> void:
	layer = 30
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.07, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 30)
	shade.add_child(_label)
	# 서버가 깨어나길 기다리는 동안에도 시작 화면으로 돌아갈 수 있어야 한다.
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(220.0, 46.0)
	back.add_theme_font_size_override("font_size", 20)
	back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	back.position += Vector2(-110.0, -90.0)
	back.pressed.connect(func() -> void: failed.emit(""))
	shade.add_child(back)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_attempt_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)


## address는 "호스트:포트" 또는 "wss://주소". https 페이지에서는 브라우저가 wss://만 허용한다.
func start(address: String) -> void:
	_url = address if address.contains("://") else "ws://" + address
	_waiting = 0.0
	print("connecting to %s" % address)
	_attempt()


func _process(delta: float) -> void:
	if _online:
		_watch_for_silence(delta)
		return
	_waiting += delta
	var text := "Connecting to the server..."
	if _waiting > 6.0:
		text = "Waking the server up... %d s\n(a resting server takes about a minute)" % int(_waiting)
	_label.text = text
	if _retry_in >= 0.0:
		_retry_in -= delta
		if _retry_in < 0.0:
			_attempt()


func _watch_for_silence(delta: float) -> void:
	if _silent < 0.0:
		return
	var session_stats: Variant = get_parent().get("stats")
	if session_stats is Dictionary and int(session_stats.get("snapshots", 0)) > 0:
		_silent = -1.0
		return
	_silent += delta
	if _silent > SILENT_LIMIT:
		_silent = -1.0
		failed.emit("The server is updating. Reload and try again in a few minutes.")


func _attempt() -> void:
	_retry_in = -1.0
	var peer := WebSocketMultiplayerPeer.new()
	# 화면이 잠깐 멈추면(탭 전환 등) 그사이 온 스냅샷이 쌓인다. 기본 64KB로는 몇 초 만에 넘쳐
	# 킬 알림 같은 신뢰 전송까지 버려지므로 넉넉히 잡는다.
	peer.inbound_buffer_size = 1 << 20
	peer.max_queued_packets = 8192
	var error := peer.create_client(_url)
	if error != OK:
		failed.emit("Could not connect: bad address")
		return
	multiplayer.multiplayer_peer = peer


func _on_connected() -> void:
	_online = true
	visible = false
	connected.emit()


func _on_attempt_failed() -> void:
	if _waiting < MAX_WAIT:
		_retry_in = RETRY_DELAY
	else:
		failed.emit("Could not reach the server")


func _on_disconnected() -> void:
	failed.emit("Disconnected from the server")
