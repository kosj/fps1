# FPS1

Windows와 웹에서 서비스하는 6v6 멀티플레이 1인칭 슈터입니다. Godot 4.7로 개발합니다.

현재 단계는 **M1 건플레이 프로토타입**입니다. 그레이박스 사격장에서 소총 1종으로 사격, 재장전, 슬라이딩, 난간 넘기를 해 볼 수 있습니다. 모델과 소리는 임시입니다.

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
| 마우스 잠금 | 화면 클릭 |
| 마우스 해제 | Esc |

## 테스트

```
godot --headless --import
godot --headless --script res://tests/run_tests.gd
godot --headless --fixed-fps 60 res://tests/smoke/smoke.tscn
```

첫 줄은 순수 계산의 단위 테스트, 둘째 줄은 실제 플레이어 씬을 돌리는 통합 테스트입니다.

## 빌드

`main` 브랜치에 푸시하거나 PR을 열면 GitHub Actions가 린트, 단위 테스트, 내보내기를 수행합니다.
결과물은 Actions 실행 페이지의 Artifacts에서 받습니다.

| 프리셋 | 렌더러 | 산출물 |
| --- | --- | --- |
| Windows Desktop | Forward+ | `fps1-windows` |
| Web | Compatibility (WebGL 2) | `fps1-web` |
| Linux Server | 헤드리스 | `fps1-linux-server` |

웹 빌드는 HTTPS 또는 localhost에서 열어야 합니다.

## 폴더 구조

```
game/             core, movement, player, weapons, combat, ui, audio (이후 net, bots)
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
