extends RefCounted
## 클라이언트 예측 보정. game_session.gd에서 떼어 낸 순수 계산이다.
## pending의 각 항목은 [입력 번호, 입력, 그 입력을 적용한 뒤의 예측 상태]이고 이 함수가 내용을 바꾼다.
## stats의 max_error와 corrections를 갱신한다.

const Protocol := preload("res://game/net/net_protocol.gd")


## 서버가 last_seq까지 적용한 결과(own)를 그 시점의 내 예측과 비교한다.
## 다르면 서버 상태로 되돌리고, 그 뒤에 보낸 입력을 다시 돌려 현재 상태를 새로 계산한다.
static func reconcile(
	local, pending: Array, last_seq: int, own: Array, delta: float, stats: Dictionary
) -> void:
	while not pending.is_empty() and int(pending[0][0]) < last_seq:
		pending.pop_front()
	if pending.is_empty() or int(pending[0][0]) != last_seq:
		# 비교할 예측이 없으면(접속 직후) 서버 상태를 그대로 따른다.
		if last_seq == 0:
			local.restore_state(own)
		return
	var predicted: Array = pending[0][2]
	var predicted_position: Vector3 = predicted[0]
	var server_position: Vector3 = own[0]
	var error := predicted_position.distance_to(server_position)
	stats["max_error"] = maxf(stats["max_error"], error)
	if error <= Protocol.RECONCILE_TOLERANCE and int(predicted[2]) == int(own[2]):
		return
	stats["corrections"] += 1
	var before: Vector3 = local.global_position
	local.restore_state(own)
	for index in range(1, pending.size()):
		local.simulate(pending[index][1], delta, true)
		pending[index][2] = local.capture_state()
	local.add_visual_offset(before - local.global_position)
