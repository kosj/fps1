extends StaticBody3D
## 피해를 받을 수 있는 부위. 받은 피해를 소유 대상에게 전달한다.

var is_head := false
var target: Node = null


## 피해를 적용하고, 이 피해로 대상이 쓰러졌으면 true를 돌려준다.
func apply_damage(amount: float) -> bool:
	if target == null:
		return false
	var killed: bool = target.call("apply_damage", amount, is_head)
	return killed
