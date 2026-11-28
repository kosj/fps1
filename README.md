# FPS1

Windows와 웹에서 서비스하는 6v6 멀티플레이 1인칭 슈터입니다. Godot 4.7로 개발합니다.

시작 화면에서 **봇 대전**(팀 데스매치 또는 점령전), 사격 연습장, 서버 접속 중 하나를 고릅니다.
팀 데스매치는 30킬, 점령전은 거점 A·B·C를 차지해 150점을 먼저 얻는 쪽이 이기고 둘 다 5분 제한입니다. Esc를 누르면 일시 정지 화면에서 감도를 바꾸거나 시작 화면으로 돌아갈 수 있습니다. 서버를 띄우면 여러 명이 접속해 대전할 수 있습니다. 캐릭터는 Varco 3D, 총기·엄폐물은 Blender 스크립트, 맵 재질은 Poly Haven CC0, 효과음은 ElevenLabs로 만들었습니다(아래 "에셋" 참고).

웹에서 바로 해 보기: https://kosj.github.io/fps1/ (화면을 클릭하면 마우스가 잠기고 조작이 시작됩니다)

## 실행

1. [Godot 4.7](https://godotengine.org/download)을 설치합니다.
2. 에디터에서 `project.godot`을 열고 F5를 누릅니다.

| 조작 | 키 |
| --- | --- |
| 이동 | W A S D |
| 달리기 | Shift (전진 중) |
| 점프 / 난간 넘기 | Space (난간 앞에서 누르면 넘기) |
| 앉기 / 슬라이딩 | Ctrl (달리는 중 누르면 슬라이딩) |
| 발사 / 정조준 | 마우스 왼쪽 / 오른쪽 |
| 재장전 | R |
| 수류탄 (목숨당 2개) | G |
| 무기 교체 | 1 주무기, 2 권총 (마우스 휠로도 가능) |
| 로드아웃 | 시작 화면이나 일시 정지 화면의 LOADOUT에서 주무기(소총, 기관단총, 산탄총, 저격총)를 고른다. 권총은 늘 함께 든다. 리스폰 직후 6초 안에 쏘기 전이면 바로, 아니면 다음 리스폰 때 바뀐다 |
| 성장 | 킬 100, 헤드샷 +50, 판 승리 500(무승부 300, 패배 200) 경험치. 레벨에 따라 주무기가 풀린다: 기관단총 2, 산탄총 3, 저격총 4. 기기마다 따로 저장된다 |
| 마우스 감도 | - 낮추기, = 높이기 (자동 저장) |
| 마우스 잠금 | 화면 클릭 |
| 마우스 해제 | Esc |

## 멀티플레이 실행

메뉴가 생기기 전까지는 명령줄 인자로 실행 방식을 정합니다. 인자는 `--` 뒤에 붙입니다.

```
# 서버 (화면 없이)
godot --headless -- --server --port=7777

# 클라이언트
godot -- --connect=127.0.0.1:7777
```

- 내보낸 Windows 빌드는 `fps1.exe -- --connect=호스트:포트`로 접속합니다.
- 웹 빌드는 주소 뒤에 `?connect=호스트:포트`를 붙입니다. HTTPS 페이지에서는 `?connect=wss://주소` 형식의 TLS 서버가 필요합니다.
- Linux 서버 빌드(`fps1-linux-server`)는 인자 없이 실행해도 서버로 동작합니다.
- 인자 없이 실행하면 시작 화면이 나옵니다. `--bots=7`을 붙이면 메뉴 없이 봇 7명과 바로 대전합니다.
- `--range`를 붙이면 더미를 쏘는 사격 연습장입니다.
- 서버에 `--bots=4`를 붙이면 빈자리를 봇으로 채웁니다.

구조는 권위 서버 방식입니다. 클라이언트는 자기 움직임을 먼저 보여 주고(예측) 서버 결과와 다르면 고쳐 계산하며(보정),
서버는 쏜 사람이 화면에서 보던 시점으로 상대 위치를 되감아 명중을 판정합니다(지연 보상, 최대 300ms).

## 경기 규칙과 설정

- 맞은 뒤 5초가 지나면 체력이 초당 25씩 회복됩니다.
- 리스폰 직후 1.5초 동안은 피해를 받지 않습니다. 먼저 쏘면 바로 풀립니다.
- 다른 플레이어의 총소리는 방향과 거리가 들립니다.
- 시작 화면에서 봇 난이도(Easy, Normal, Hard)와 저사양 그래픽(Low graphics)을 고를 수 있습니다. 휴대폰에서는 Easy와 저사양이 기본값입니다.
- 봇 대전은 일시 정지하면 실제로 멈춥니다. 네트워크 대전은 멈추지 않습니다.

## 휴대폰과 태블릿

웹 주소를 휴대폰에서 열면 터치 조작이 켜집니다. 가로 화면으로 돌려서 하세요.

- 화면 왼쪽: 누른 자리에 가상 스틱이 생깁니다. 끝까지 앞으로 밀면 달립니다.
- 화면 오른쪽: 끌어서 시선을 돌립니다. FIRE 버튼을 누른 채 끌어도 됩니다.
- 조준 보조: 조준선이 보이는 적 근처에 가면 시선 이동이 느려지고 적 쪽으로 살짝 끌립니다.
- 버튼: FIRE 발사, AIM 정조준(누를 때마다 전환), JUMP 점프와 난간 넘기, DUCK 앉기(달리는 중엔 슬라이딩), R 재장전, GUN 주무기/권총 교체, NADE 수류탄, 왼쪽 위 II 일시 정지

## 테스트

```
godot --headless --import
godot --headless --script res://tests/run_tests.gd
godot --headless --fixed-fps 60 res://tests/smoke/smoke.tscn
GODOT=godot tests/net/run_net_test.sh lagcomp
GODOT=godot tests/net/run_net_test.sh nolagcomp
GODOT=godot tests/net/run_net_test.sh prediction
```

- 단위 테스트: 이동, 무기, 판정, 입력 검증 같은 순수 계산
- 통합 테스트(smoke): 실제 플레이어 씬으로 걷기, 사격, 재장전, 슬라이딩, 난간 넘기
- 봇 대전 테스트: `godot --headless --fixed-fps 60 -- --spectate --bots=6 --exit-after=60 --expect-kills=3`
  - 균형 측정: `--seed=<n>`으로 봇 난수를 바꿔 여러 판의 `match over: a - b` 출력을 집계
- 네트워크 테스트: 서버와 봇 클라이언트를 실제 프로세스로 띄워 지연을 넣고 확인
  - `lagcomp`: 양방향 50ms 지연에서 좌우로 움직이는 상대를 맞히는지
  - `nolagcomp`: 지연 보상을 끄면 같은 조건에서 거의 못 맞히는지(테스트 자체의 검증)
  - `prediction`: 80ms 지연에서 달리기, 슬라이딩, 점프의 예측이 서버 결과와 일치하는지

## 빌드

`main` 브랜치에 푸시하거나 PR을 열면 GitHub Actions가 린트, 단위 테스트, 내보내기를 수행합니다.
결과물은 Actions 실행 페이지의 Artifacts에서 받습니다.

| 프리셋 | 렌더러 | 산출물 |
| --- | --- | --- |
| Windows Desktop | Forward+ | `fps1-windows` |
| Web | Compatibility (WebGL 2) | `fps1-web` |
| Linux Server | 헤드리스 | `fps1-linux-server` |

웹 빌드는 HTTPS 또는 localhost에서 열어야 합니다.

### 웹 배포

`main`에 병합될 때마다 웹 빌드가 `gh-pages` 브랜치에 올라갑니다.
저장소 Settings → Pages에서 Source를 "Deploy from a branch", 브랜치를 `gh-pages`로 지정하면 GitHub Pages 주소로 서비스됩니다.
게임 서버가 아직 배포되지 않았으므로 웹에서는 봇 대전만 됩니다. 대전을 하려면 `?connect=wss://서버주소`가 가리킬 TLS 게임 서버가 필요합니다.

## 폴더 구조

```
game/                 core, movement, player, weapons, combat, match, bots, net, ui, audio, fx, world
game/weapons/models/  총기와 1인칭 팔 GLB
game/player/models/   병사 GLB (동작 8종 포함)
game/audio/sfx/       효과음 OGG
maps/                 맵 씬(depot, compound), maps/catalog.gd(맵 목록), maps/arena_base.gd(대칭 맵 공통),
                      maps/textures(재질), maps/props(엄폐물 GLB)
tests/                단위 테스트, smoke, 네트워크 테스트, shots(화면 캡처)
tools/asset_pipeline/ 에셋 제작 스크립트 (Blender)
docs/                 기술 결정 기록, 에셋 품질 기준
```

## 에셋

| 에셋 | 만든 방법 | 다시 만들기 |
|---|---|---|
| 총기 5종(주무기 4, 권총) | Blender 스크립트 모델링 + 마모 텍스처 베이크 | `blender -b --python tools/asset_pipeline/build_weapons.py -- game/weapons/models` |
| 무기 아이콘 | 같은 스크립트의 직교 옆모습 렌더(배경 투명) | `... build_weapons.py -- <임시 폴더> --icons game/ui/icons` (잘라서 384x168로 줄인다) |
| 엄폐물 | Blender 스크립트 모델링(맵에서 쓰는 크기별) | `blender -b --python tools/asset_pipeline/build_props.py -- maps/props` |
| 병사 | Varco 3D: 이미지 → 3D → 리깅 → 소총 동작 8종 | `merge_character.py`로 동작별 GLB를 하나로 합침 |
| 1인칭 팔 | Varco 손가락 리깅에서 손가락을 굽혀 잘라냄 | `extract_arms.py` |
| 맵 재질 | Poly Haven CC0 (1K) | `maps/textures/README.md` |
| 효과음 | ElevenLabs 효과음 생성 후 잘라서 음량 맞춤 | `game/audio/sfx/README.md` |

AI로 만든 메시를 넣기 전에는 `tools/asset_pipeline/analyze.py`로 삼각형 수·UV·파일 크기를 재고,
기준은 `docs/asset_quality.md`를 따릅니다. 각진 물체는 AI 메시 대신 스크립트로 모델링합니다.

휴대폰 확인: `tests/web/phone_check.mjs`가 웹 빌드를 헤드리스 크롬의 휴대폰 에뮬레이션으로 열어 메뉴와 게임 화면을 찍습니다(사용법은 파일 머리말).

화면 확인: 창이 없는 환경에서도 `xvfb-run godot --rendering-driver opengl3 res://tests/shots/shots.tscn -- --out=build/shots`
로 무기별 지향/정조준 화면을 PNG로 저장할 수 있습니다.

## 테스트

```
godot --headless --import
godot --headless --script res://tests/run_tests.gd
godot --headless --fixed-fps 60 res://tests/smoke/smoke.tscn
GODOT=godot tests/net/run_net_test.sh lagcomp
GODOT=godot tests/net/run_net_test.sh nolagcomp
GODOT=godot tests/net/run_net_test.sh prediction
```

- 단위 테스트: 이동, 무기, 판정, 입력 검증 같은 순수 계산
- 통합 테스트(smoke): 실제 플레이어 씬으로 걷기, 사격, 재장전, 슬라이딩, 난간 넘기
- 봇 대전 테스트: `godot --headless --fixed-fps 60 -- --spectate --bots=6 --exit-after=60 --expect-kills=3`
  - 균형 측정: `--seed=<n>`으로 봇 난수를 바꿔 여러 판의 `match over: a - b` 출력을 집계
- 네트워크 테스트: 서버와 봇 클라이언트를 실제 프로세스로 띄워 지연을 넣고 확인
  - `lagcomp`: 양방향 50ms 지연에서 좌우로 움직이는 상대를 맞히는지
  - `nolagcomp`: 지연 보상을 끄면 같은 조건에서 거의 못 맞히는지(테스트 자체의 검증)
  - `prediction`: 80ms 지연에서 달리기, 슬라이딩, 점프의 예측이 서버 결과와 일치하는지

## 빌드

`main` 브랜치에 푸시하거나 PR을 열면 GitHub Actions가 린트, 단위 테스트, 내보내기를 수행합니다.
결과물은 Actions 실행 페이지의 Artifacts에서 받습니다.

| 프리셋 | 렌더러 | 산출물 |
| --- | --- | --- |
| Windows Desktop | Forward+ | `fps1-windows` |
| Web | Compatibility (WebGL 2) | `fps1-web` |
| Linux Server | 헤드리스 | `fps1-linux-server` |

웹 빌드는 HTTPS 또는 localhost에서 열어야 합니다.

### 웹 배포

`main`에 병합될 때마다 웹 빌드가 `gh-pages` 브랜치에 올라갑니다.
저장소 Settings → Pages에서 Source를 "Deploy from a branch", 브랜치를 `gh-pages`로 지정하면 GitHub Pages 주소로 서비스됩니다.
게임 서버가 아직 배포되지 않았으므로 웹에서는 봇 대전만 됩니다. 대전을 하려면 `?connect=wss://서버주소`가 가리킬 TLS 게임 서버가 필요합니다.

## 폴더 구조

```
game/             core, movement, player, weapons, combat, ui, audio, net, bots
maps/             맵 씬
art/              Blender에서 내보낸 GLB, 머티리얼
audio/            후처리를 마친 사운드
tests/            헤드리스 단위 테스트
tools/blender/    정리, 내보내기 자동화 스크립트
tools/audio/      ElevenLabs 프롬프트 매니페스트, 후처리 스크립트
server/           전용 서버 배포 설정
docs/             기술 결정 기록, 아트 바이블
```

## 코드 규칙

- 이동, 무기 같은 게임 규칙은 노드에 의존하지 않는 순수 계산으로 작성합니다(`game/movement/move_math.gd` 참고).
  서버, 클라이언트 예측, 봇, 테스트가 같은 코드를 쓰기 위해서입니다.
- 전역 `class_name` 대신 `preload` 상수로 스크립트를 참조합니다.
- 바이너리 에셋은 Git LFS로 관리합니다(`.gitattributes` 참고).
