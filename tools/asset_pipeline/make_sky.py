"""HDRI 하늘을 게임용 LDR 파노라마(JPG)로 만든다.

Poly Haven의 "puresky" HDRI(.hdr)를 받아
1. 가장 밝은 곳(해)의 위치를 찾아 출력하고(맵 스크립트의 SKY_SUN에 넣는다),
2. 노출과 색조를 곱한 뒤 ACES 근사로 톤매핑하고 sRGB 감마를 입히고,
3. 아래쪽 반구(땅에 가려 안 보이지만 주변광에 쓰인다)를 지평선 색에서 땅 색으로 내려가는
   그라데이션으로 바꿔
4. 2048x1024 JPG로 저장한다.

    python3 tools/asset_pipeline/make_sky.py sky.hdr maps/sky/name_sky.jpg \
        --exposure 1.0 --tint 1,1,1 --ground 120,118,112
"""

import argparse

import cv2
import numpy as np


def aces(color: np.ndarray) -> np.ndarray:
    """Narkowicz의 ACES 근사."""
    a, b, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
    return np.clip((color * (a * color + b)) / (color * (c * color + d) + e), 0.0, 1.0)


def find_sun(rgb: np.ndarray) -> tuple:
    """위쪽 반구에서 가장 밝은 곳의 (u, v). 작은 창으로 평균을 내 구름 가장자리의 점을 피한다."""
    height, width = rgb.shape[:2]
    lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    upper = cv2.blur(lum[: height // 2], (9, 9))
    y, x = np.unravel_index(np.argmax(upper), upper.shape)
    return (x + 0.5) / width, (y + 0.5) / height, float(upper.max())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("hdr")
    parser.add_argument("out")
    parser.add_argument("--exposure", type=float, default=1.0)
    parser.add_argument("--tint", default="1,1,1")
    parser.add_argument("--ground", default="120,118,112", help="땅 색(0~255, sRGB)")
    parser.add_argument("--width", type=int, default=2048)
    parser.add_argument("--quality", type=int, default=88)
    args = parser.parse_args()

    bgr = cv2.imread(args.hdr, cv2.IMREAD_UNCHANGED)
    if bgr is None:
        raise SystemExit("cannot read " + args.hdr)
    rgb = bgr[..., ::-1].astype(np.float32)
    u, v, peak = find_sun(rgb)
    elevation = (0.5 - v) * 180.0
    print("sun uv=(%.4f, %.4f) elevation=%.1f deg peak=%.1f" % (u, v, elevation, peak))

    tint = np.array([float(x) for x in args.tint.split(",")], dtype=np.float32)
    color = np.power(aces(rgb * args.exposure * tint), 1.0 / 2.2)
    width = args.width
    height = width // 2
    color = cv2.resize(color, (width, height), interpolation=cv2.INTER_AREA)

    # 아래쪽 반구: 지평선 바로 위 줄의 색에서 땅 색으로 부드럽게 내려간다.
    horizon_row = height // 2
    horizon = color[horizon_row - 4 : horizon_row].mean(axis=0)
    ground = np.array([float(x) for x in args.ground.split(",")], dtype=np.float32) / 255.0
    rows = np.arange(height - horizon_row, dtype=np.float32) / (height - horizon_row)
    blend = np.clip(rows / 0.12, 0.0, 1.0)
    blend = blend * blend * (3.0 - 2.0 * blend)
    lower = horizon[None, :, :] * (1.0 - blend[:, None, None]) + ground * blend[:, None, None]
    color[horizon_row:] = lower

    out = (np.clip(color, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    cv2.imwrite(args.out, out[..., ::-1], [cv2.IMWRITE_JPEG_QUALITY, args.quality])
    print("wrote", args.out)


if __name__ == "__main__":
    main()
