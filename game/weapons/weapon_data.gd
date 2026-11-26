extends Resource
## 무기 한 종의 밸런스 데이터. 코드 수정 없이 .tres 파일로 조정한다.

@export var display_name := "Rifle"
@export var automatic := true

@export_group("Damage")
@export var damage := 28.0
@export var min_damage := 18.0
@export var headshot_multiplier := 1.5
## 이 거리(m)부터 피해가 줄기 시작한다.
@export var falloff_start := 25.0
## 이 거리(m)부터는 min_damage가 적용된다.
@export var falloff_end := 60.0
@export var max_range := 200.0

@export_group("Handling")
## 발사 간격(초). 0.085초는 분당 약 705발.
@export var fire_interval := 0.085
@export var magazine_size := 30
@export var reload_time := 1.9
@export var ads_time := 0.2
@export var ads_fov := 55.0

@export_group("Accuracy")
@export var hip_spread_deg := 2.2
@export var ads_spread_deg := 0.15
## 최고 속도로 이동할 때 지향 사격에 더해지는 퍼짐.
@export var move_spread_deg := 1.5

@export_group("Recoil")
## 발사 순서별 반동(도). x: 좌우(오른쪽이 +), y: 상승.
## 무작위가 아닌 고정 패턴이라 연습으로 제어할 수 있다.
@export var recoil_pattern := PackedVector2Array()
@export var recoil_recovery := 9.0
## 이 시간(초) 동안 쏘지 않으면 패턴이 처음으로 돌아간다.
@export var recoil_reset_time := 0.35
@export var ads_recoil_scale := 0.75
