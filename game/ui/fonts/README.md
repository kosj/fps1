# UI 글꼴

| 파일 | 원본 | 라이선스 | 쓰는 곳 |
| --- | --- | --- | --- |
| RobotoCondensed-Medium.ttf, RobotoCondensed-Bold.ttf | Roboto 가변 글꼴(Google Fonts)을 폭 75로 고정 | SIL OFL 1.1 (`OFL-Roboto.txt`) | 기본 글꼴, 버튼, HUD 숫자 |
| Anton-Regular.ttf | Anton (Google Fonts) | SIL OFL 1.1 (`OFL-Anton.txt`) | 큰 제목, 승패, 점수 |
| icons.ttf | Font Awesome Free 7 Solid에서 쓰는 아이콘 48개만 | 아이콘 CC BY 4.0, 글꼴 SIL OFL 1.1 (`LICENSE-FontAwesome.txt`) | 버튼과 HUD 아이콘 |

모두 라틴 문자와 쓰는 기호만 남겨 크기를 줄였습니다(각 10~32 KB).
다시 만들기: `python3 tools/ui/make_fonts.py <Roboto[wdth,wght].ttf> <Anton-Regular.ttf> <fa-solid-900.woff2> <all.css> game/ui/fonts`
(아이콘 이름과 코드는 출력되는 목록을 `game/ui/ui_style.gd`의 `ICONS`에 넣습니다.)

Icons: Font Awesome Free by Fonticons, Inc. — https://fontawesome.com, CC BY 4.0.
