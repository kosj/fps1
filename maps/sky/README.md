# 하늘

Poly Haven의 CC0 HDRI(구름만 있는 "puresky")를 2K로 받아 ACES 근사로 톤매핑한 2048x1024 파노라마.
아래쪽 반구는 거울에 비친 하늘 대신 지평선 색에서 땅 색으로 내려가는 그라데이션으로 바꿨다.

| 파일 | 원본 | 노출, 색조 | 사진 속 해(u, v) |
|---|---|---|---|
| depot_sky.jpg | https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky | 0.9 | (0.5947, 0.2334), 고도 48도 |
| compound_sky.jpg | https://polyhaven.com/a/table_mountain_2_puresky | 2.2, 따뜻하게(1.12, 0.95, 0.78) | (0.6377, 0.4590), 고도 7도 |

맵 스크립트가 maps/dressing.gd의 use_sky로 사진 속 해의 방위에 태양 조명을 맞춘다.
