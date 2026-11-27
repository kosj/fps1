extends RefCounted
## 점령전 규칙. 노드와 무관한 순수 계산이라 서버와 로컬 대전이 함께 쓰고 단위 테스트할 수 있다.
##
## - 거점에 한 팀만 있으면 점령이 진행되고, 인원이 많을수록 빨라진다(최대 2배).
## - 두 팀이 함께 있으면 멈춘다(경합).
## - 아무도 없으면 진행도가 서서히 줄어든다.
## - 거점 하나당 초당 1점. 처치는 점수가 아니다.

const RADIUS := 4.0
const HEIGHT_TOLERANCE := 3.0
const CAPTURE_TIME := 6.0
const DECAY_TIME := 4.0
const SCORE_LIMIT := 150
const NEUTRAL := -1
## 봇이 한 번에 노리는 거점 수(가까운 순).
const NEAREST_GOALS := 2

var names: Array = []
var centers: Array = []
## 거점별 소유 팀(NEUTRAL, 0, 1).
var owners: Array = []
## 거점별 점령 진행도(0~1)와 점령 중인 팀.
var progress: Array = []
var capturing: Array = []
var scores := [0.0, 0.0]
var captures := 0


## zones의 각 항목은 [이름, 중심 위치].
func _init(zones: Array) -> void:
	for zone: Array in zones:
		names.append(zone[0])
		centers.append(zone[1])
	reset()


func reset() -> void:
	owners.clear()
	progress.clear()
	capturing.clear()
	for index in centers.size():
		owners.append(NEUTRAL)
		progress.append(0.0)
		capturing.append(NEUTRAL)
	scores = [0.0, 0.0]


## position이 속한 거점 번호. 어느 거점에도 없으면 -1.
func zone_at(position: Vector3) -> int:
	for index in centers.size():
		var center: Vector3 = centers[index]
		var flat := Vector2(position.x - center.x, position.z - center.z).length()
		if flat <= RADIUS and absf(position.y - center.y) <= HEIGHT_TOLERANCE:
			return index
	return -1


## 한 틱 진행한다. positions_by_team은 [0팀 생존자 위치 목록, 1팀 생존자 위치 목록].
func update(delta: float, positions_by_team: Array) -> void:
	for index in centers.size():
		var present := [0, 0]
		for team in 2:
			for position: Vector3 in positions_by_team[team]:
				if zone_at(position) == index:
					present[team] += 1
		_update_zone(index, present[0], present[1], delta)
	for team in 2:
		scores[team] += owners.count(team) * delta


## 스냅샷과 화면 표시에 쓰는 거점 상태. 각 항목은 [소유 팀, 진행도, 점령 중인 팀].
func state() -> Array:
	var rows: Array = []
	for index in centers.size():
		rows.append([owners[index], progress[index], capturing[index]])
	return rows


## 이 팀이 지금 서서 지켜야 할 거점 번호(안에 있고 아직 우리 것이 아닌 거점). 없으면 -1.
func hold_zone_for(team: int, position: Vector3) -> int:
	var inside := zone_at(position)
	if inside >= 0 and int(owners[inside]) != team:
		return inside
	return -1


## 봇이 향할 곳. 점령 중인 거점 안에 있으면 그 자리를 지키고,
## 아니면 아직 우리 팀 것이 아닌 거점들, 모두 우리 것이면 전체 거점을 돌려준다.
func objectives_for(team: int, position: Vector3) -> Array:
	var inside := hold_zone_for(team, position)
	if inside >= 0:
		return [centers[inside]]
	var wanted: Array = []
	for index in centers.size():
		if int(owners[index]) != team:
			wanted.append(centers[index])
	if wanted.is_empty():
		return centers.duplicate()
	# 가까운 거점 둘만 노린다. 먼 거점까지 흩어지면 밀리는 팀이 한 명씩 들어가다 계속 진다.
	wanted.sort_custom(
		func(a: Vector3, b: Vector3) -> bool:
			return position.distance_squared_to(a) < position.distance_squared_to(b)
	)
	return wanted.slice(0, NEAREST_GOALS)


func _update_zone(index: int, count_a: int, count_b: int, delta: float) -> void:
	if count_a > 0 and count_b > 0:
		return
	if count_a + count_b == 0:
		_decay(index, delta / DECAY_TIME)
		return
	var team := 0 if count_a > 0 else 1
	var count := maxi(count_a, count_b)
	if int(owners[index]) == team:
		# 주인이 돌아오면 상대가 쌓던 진행도를 빠르게 지운다.
		_decay(index, 2.0 * delta / CAPTURE_TIME)
		return
	if int(capturing[index]) != team and float(progress[index]) > 0.0:
		_decay(index, 2.0 * delta / CAPTURE_TIME)
		return
	var rate := minf(1.0 + 0.5 * (count - 1), 2.0)
	capturing[index] = team
	progress[index] = float(progress[index]) + rate * delta / CAPTURE_TIME
	if float(progress[index]) >= 1.0:
		owners[index] = team
		progress[index] = 0.0
		capturing[index] = NEUTRAL
		captures += 1


func _decay(index: int, amount: float) -> void:
	progress[index] = maxf(float(progress[index]) - amount, 0.0)
	if float(progress[index]) <= 0.0:
		capturing[index] = NEUTRAL
