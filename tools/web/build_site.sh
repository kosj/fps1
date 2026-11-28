#!/usr/bin/env bash
# 웹 빌드 전체: Web 프리셋 내보내기(코드와 장면) → 에셋 팩 → GitHub Pages 모양으로 배치.
#
#   GODOT=godot tools/web/build_site.sh [출력 폴더=build/site] [버전=local] [이전 사이트 폴더]
#
# 이전 사이트 폴더를 주면, 해시가 같은 엔진·에셋 파일은 그쪽 것을 그대로 쓴다(브라우저 캐시 유지).
# 확인: (cd build/site && python3 -m http.server 8125) 후 http://127.0.0.1:8125/
set -euo pipefail
cd "$(dirname "$0")/../.."
godot=${GODOT:-godot}
out=${1:-build/site}
version=${2:-local}
previous=${3:-}

mkdir -p build/web
"$godot" --headless --export-release "Web" build/web/index.html
test -s build/web/index.pck
"$godot" --headless --script res://tools/web/make_asset_pack.gd -- "$PWD/build/assets.pck" \
  2>&1 | tee build/assets.log
hash=$(grep -oE 'ASSET_HASH [0-9a-f]+' build/assets.log | cut -d' ' -f2)
test -n "$hash"
reuse=()
if [ -n "$previous" ]; then reuse=(--reuse "$previous"); fi
python3 tools/web/stage_site.py --export build/web --assets build/assets.pck --asset-hash "$hash" \
  --version "$version" --out "$out" "${reuse[@]}"
