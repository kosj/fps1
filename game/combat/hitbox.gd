extends StaticBody3D
## 피해를 받을 수 있는 부위. 받은 피해를 소유 대상에게 전달한다.

const LAYER := 4

var is_head := false
var target: Node = null


func _init() -> void:
	# 히트박스는 탄 판정 전용 레이어에 두어 캐릭터 이동을 막지 않게 한다.
	collision_layer = LAYER
	collision_mask = 0


## 피해를 적용하고, 이 피해로 대상이 쓰러졌으면 true를 돌려준다.
func apply_damage(amount: float) -> bool:
	if target == null:
		return false
	var killed: bool = target.call("apply_damage", amount, is_head)
	return killed
