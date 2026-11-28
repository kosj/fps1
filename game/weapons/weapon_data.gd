extends Resource
## 무기 한 종의 밸런스 데이터. 코드 수정 없이 .tres 파일로 조정한다.

@export var display_name := "Rifle"
@export var automatic := true

## 한 번 쏠 때 나가는 탄 수. 산탄총은 여러 발이다.
@export var pellets := 1
## 산탄이 조준점 주위로 퍼지는 각도. 정조준해도 줄지 않는다.
@export var pellet_spread_deg := 0.0

@export_group("Sound")
## 발사음. 비우면 합성음을 쓴다.
@export var shot_sound: AudioStream

@export_group("Model")
## 1인칭 모델(GLB). body / mag / action 부품과 muzzle 위치를 담고 있다. 비우면 임시 상자 모델.
@export var model: PackedScene
## 정조준할 때 화면 중앙에 올 조준선 높이(총열 축 기준, m).
@export var sight_height := 0.085
## 정조준할 때 눈에서 총 원점까지의 거리(m). 개머리판이 긴 총은 줄여서 눈을 뒤쪽에 둔다.
@export var aim_distance := 0.2
## 1인칭 손 위치(총 원점 기준, m). 오른손은 손잡이, 왼손은 총열 덮개 아래를 받친다.
@export var grip_point := Vector3(0.0, -0.1, 0.07)
@export var support_point := Vector3(0.0, -0.085, -0.28)
## 지향 사격 때 총 위치를 기본 자리에서 옮기는 양(m). 작은 권총은 위로, 가운데로 당긴다.
@export var hip_offset := Vector3.ZERO
## 왼팔 팔꿈치 자리와 왼손 비틀기(도). 소총은 손바닥을 위로 해 총열 덮개를 받치고(180),
## 권총은 오른손을 옆에서 감싼다.
@export var support_elbow := Vector3(-0.3, -0.15, 0.2)
@export var support_roll := 180.0
## 조준경이 화면을 가리는 총은 정조준 중에 모델을 숨긴다.
@export var hide_when_aimed := false

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
