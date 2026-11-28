"""UI 글꼴을 만든다: 필요한 글자만 남겨 웹 다운로드를 줄이고, 가변 글꼴에서 굵기·폭을 고정한다.

- Roboto Condensed Medium/Bold: Roboto 가변 글꼴(wdth, wght)에서 wdth 75로 뽑는다(OFL).
- Anton: 큰 제목과 결과 화면 숫자(OFL).
- icons.ttf: Font Awesome Free Solid에서 쓰는 아이콘만(아이콘 CC BY 4.0, 글꼴 OFL).
  아이콘 이름과 코드는 game/ui/ui_style.gd의 ICONS에 적는다.

    python3 tools/ui/make_fonts.py <roboto 가변 ttf> <anton ttf> <fa-solid-900.woff2> <all.css> game/ui/fonts

WOFF2를 풀려면 파이썬 brotli 모듈이 필요하다. 없으면 이 폴더의 brotli_shim.py를 brotli.py라는 이름으로
PYTHONPATH에 두면 Node 내장 zlib으로 푼다.
"""

import re
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ICONS = (
    "location-crosshairs crosshairs angles-up angles-down rotate right-left gun bomb bolt hand-fist "
    "pause table-list skull play users bullseye gear power-off lock check chevron-right chevron-left "
    "user trophy medal star xmark volume-high music display mobile-screen flag wifi clock "
    "map-location-dot person-rifle burst heart-pulse shield-halved person-running eye sliders "
    "keyboard circle-info arrow-up arrow-down right-from-bracket ranking-star"
).split()
LATIN = list(range(0x20, 0x7F)) + list(range(0xA0, 0x100))
PUNCTUATION = [0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2026, 0x00D7, 0x2212,
               0x2190, 0x2191, 0x2192, 0x2193, 0x25B2, 0x25BC]


def keep(font: TTFont, unicodes: list, features: list) -> TTFont:
    options = subset.Options()
    options.layout_features = features
    options.name_IDs = ["*"]
    options.notdef_outline = True
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    font.flavor = None
    return font


def main() -> None:
    roboto, anton, awesome, css, out = sys.argv[1:6]
    for weight, name in [(500, "Medium"), (700, "Bold")]:
        font = instancer.instantiateVariableFont(TTFont(roboto), {"wdth": 75, "wght": weight})
        keep(font, LATIN + PUNCTUATION, ["kern", "liga", "tnum", "lnum", "case"])
        font.save(f"{out}/RobotoCondensed-{name}.ttf")
    keep(TTFont(anton), LATIN + PUNCTUATION, ["kern", "liga", "tnum", "lnum"]).save(f"{out}/Anton-Regular.ttf")
    codes = dict(re.findall(r'\.fa-([a-z0-9-]+)\s*\{\s*--fa:\s*"\\?([0-9a-fA-F]+)"', open(css).read()))
    wanted = [int(codes[name], 16) for name in ICONS]
    keep(TTFont(awesome), wanted, []).save(f"{out}/icons.ttf")
    for name in ICONS:
        print(f'\t"{name}": 0x{codes[name]},')


if __name__ == "__main__":
    main()
