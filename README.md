# FPS1

Windows와 웹에서 서비스하는 6v6 멀티플레이 1인칭 슈터입니다. Godot 4.7로 개발합니다.

시작 화면에서 **봇 대전**(팀 데스매치 또는 점령전), 사격 연습장, 서버 접속 중 하나를 고릅니다.
팀 데스매치는 30킬, 점령전은 거점 A·B·C를 차지해 150점을 먼저 얻는 쪽이 이기고 둘 다 5분 제한입니다. Esc를 누르면 일시 정지 화면에서 감도를 바꾸거나 시작 화면으로 돌아갈 수 있습니다. 서버를 띄우면 여러 명이 접속해 대전할 수 있습니다. 모델과 소리는 임시이고 메뉴 화면은 아직 없습니다.

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
| 무기 교체 | 1 소총, 2 기관단총, 3 산탄총, 4 저격총 (마우스 휠로도 가능) |
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
