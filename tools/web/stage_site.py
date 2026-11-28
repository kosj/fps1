"""웹 빌드를 GitHub Pages에 올릴 모양으로 배치한다.

휴대폰이 새 빌드마다 받는 양을 줄이려고 세 덩어리로 나눈다.

    site/index.html                  최신 빌드로 넘겨 주는 페이지
    site/v/<빌드>/index.html, .pck   빌드마다 바뀌는 작은 본 팩(코드와 장면)
    site/engine/<해시>/index.wasm    엔진(Godot 버전이 같으면 그대로)
    site/assets/<해시>.pck           텍스처·모델·소리(바뀌지 않으면 그대로)

엔진과 에셋 팩은 내용 해시로 이름을 붙여, 바뀌지 않았으면 주소도 같아 브라우저 캐시를 그대로 쓴다.
--reuse에 이전 사이트 폴더를 주면 같은 이름의 파일을 그쪽에서 가져온다(가져오기 결과가 매번
바이트 단위로 같지 않아도 캐시가 깨지지 않게).

    python3 tools/web/stage_site.py --export build/web --assets build/assets.pck \
        --asset-hash <make_asset_pack.gd가 출력한 해시> --version <커밋> --out build/site [--reuse old]
"""

import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

ENGINE_FILES = ["index.js", "index.wasm", "index.audio.worklet.js", "index.audio.position.worklet.js"]
VERSION_FILES = ["index.pck", "index.png", "index.icon.png", "index.apple-touch-icon.png"]
# 페이지는 에셋 팩을 assets.pck라는 이름으로 미리 받아 두고, 엔진이 시작하기 전까지 기다린다.
# 게임 쪽에서는 game/core/asset_pack.gd가 가장 먼저 이 팩을 끼워 넣는다.
PRELOAD = """
const ASSET_PACK = %s;
const assetsReady = engine.preloadFile(ASSET_PACK, 'assets.pck');
const startEngine = engine.start.bind(engine);
engine.start = (override) => assetsReady.then(() => startEngine(override));
"""
REDIRECT = """<!doctype html>
<meta charset="utf-8">
<meta http-equiv="cache-control" content="no-cache">
<title>FPS1</title>
<script>location.replace("v/%s/index.html" + location.search)</script>
"""


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def place(source: Path, target: Path, reuse: Path | None, relative: str) -> None:
    """target에 파일을 둔다. 이전 사이트에 같은 이름이 있으면 그 바이트를 그대로 쓴다."""
    target.parent.mkdir(parents=True, exist_ok=True)
    previous = reuse / relative if reuse else None
    shutil.copyfile(previous if previous and previous.is_file() else source, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", required=True, type=Path, help="Web 프리셋으로 내보낸 폴더")
    parser.add_argument("--assets", required=True, type=Path)
    parser.add_argument("--asset-hash", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--reuse", type=Path)
    args = parser.parse_args()

    out: Path = args.out
    if out.exists():
        shutil.rmtree(out)
    engine_id = sha(args.export / "index.wasm")[:16]
    asset_id = args.asset_hash[:16]
    engine_rel = f"engine/{engine_id}"
    asset_rel = f"assets/{asset_id}.pck"
    version_dir = out / "v" / args.version

    for name in ENGINE_FILES:
        place(args.export / name, out / engine_rel / name, args.reuse, f"{engine_rel}/{name}")
    place(args.assets, out / asset_rel, args.reuse, asset_rel)
    for name in VERSION_FILES:
        version_dir.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(args.export / name, version_dir / name)

    html = (args.export / "index.html").read_text(encoding="utf-8")
    match = re.search(r"const GODOT_CONFIG = (\{.*?\});", html)
    if not match:
        raise SystemExit("GODOT_CONFIG not found in index.html")
    config = json.loads(match.group(1))
    up = "../../"
    config["executable"] = f"{up}{engine_rel}/index"
    config["mainPack"] = "index.pck"
    config["fileSizes"] = {
        "index.pck": (version_dir / "index.pck").stat().st_size,
        f"{up}{engine_rel}/index.wasm": (out / engine_rel / "index.wasm").stat().st_size,
        f"{up}{asset_rel}": (out / asset_rel).stat().st_size,
    }
    html = html.replace(match.group(0), "const GODOT_CONFIG = %s;" % json.dumps(config))
    html = html.replace('<script src="index.js"></script>', f'<script src="{up}{engine_rel}/index.js"></script>')
    anchor = "const engine = new Engine(GODOT_CONFIG);"
    if anchor not in html or f"{up}{engine_rel}/index.js" not in html:
        raise SystemExit("unexpected index.html layout")
    html = html.replace(anchor, anchor + PRELOAD % json.dumps(f"{up}{asset_rel}"))
    (version_dir / "index.html").write_text(html, encoding="utf-8")

    (out / "index.html").write_text(REDIRECT % args.version, encoding="utf-8")
    (out / ".nojekyll").touch()
    sizes = {
        "engine": (out / engine_rel / "index.wasm").stat().st_size,
        "assets": (out / asset_rel).stat().st_size,
        "main pack": (version_dir / "index.pck").stat().st_size,
    }
    print("site:", out, " ".join("%s=%.1fMB" % (k, v / 1e6) for k, v in sizes.items()))
    print("engine:", engine_rel, "assets:", asset_rel)


if __name__ == "__main__":
    main()
