extends RefCounted
## 네트워크 공통 상수. 서버와 클라이언트가 같은 값을 써야 한다.

const DEFAULT_PORT := 7777
const TICK_RATE := 60
## 서버가 스냅샷을 보내는 간격(틱). 2틱이면 초당 30회.
const SNAPSHOT_INTERVAL := 2
## 다른 플레이어를 이만큼 과거 시점으로 보간해 그린다(틱). 6틱은 100ms.
const INTERP_TICKS := 6
## 지연 보상으로 되감을 수 있는 최대 틱. 18틱은 300ms.
const MAX_REWIND_TICKS := 18
## 서버가 플레이어별로 쌓아 두는 입력의 최대 개수.
const MAX_QUEUE := 12
## 예측 위치와 서버 위치가 이보다 더 벌어지면 보정한다(m).
const RECONCILE_TOLERANCE := 0.02
const RESPAWN_TIME := 3.0
const MAX_HEALTH := 100.0
const FLAG_LOW := 1
const FLAG_ALIVE := 2
