#!/usr/bin/env bash
# 네트워크 통합 테스트: 서버 1개와 봇 클라이언트 2개를 실제 프로세스로 띄운다.
# 양방향 50ms 지연을 넣고 다음을 확인한다.
#   - 두 클라이언트가 접속하고 스냅샷을 받는다
#   - 좌우로 움직이는 봇의 예측 보정 횟수가 적다(예측과 서버 결과가 일치)
#   - 사격 봇이 움직이는 상대를 맞힌다(지연 보상이 동작)
# 사용법: tests/net/run_net_test.sh [lagcomp|nolagcomp]
set -u
GODOT="${GODOT:-godot}"
VARIANT="${1:-lagcomp}"
PORT="${PORT:-7788}"
MAP="res://maps/test_flat/test_flat.tscn"
OUT="build/net-test-$VARIANT"
mkdir -p "$OUT"

SERVER_FLAGS="--server --port=$PORT --map=$MAP --exit-after=17 --expect-players=2"
SHOOTER_FLAGS="--expect-hit-ratio=0.4"
if [ "$VARIANT" = "nolagcomp" ]; then
  # 지연 보상을 끄면 같은 조건에서 거의 맞지 않아야 한다. 테스트가 실제로 지연 보상을 검증하는지 확인한다.
  SERVER_FLAGS="$SERVER_FLAGS --no-lagcomp"
  SHOOTER_FLAGS="--max-hit-ratio=0.3"
fi

"$GODOT" --headless -- $SERVER_FLAGS > "$OUT/server.log" 2>&1 &
SERVER_PID=$!
sleep 3
"$GODOT" --headless -- --connect=127.0.0.1:$PORT --map=$MAP --bot=strafer \
  --net-delay-ms=50 --exit-after=12 --max-corrections=40 > "$OUT/strafer.log" 2>&1 &
STRAFER_PID=$!
sleep 1
"$GODOT" --headless -- --connect=127.0.0.1:$PORT --map=$MAP --bot=shooter \
  --net-delay-ms=50 --exit-after=10 --expect-remote-moving $SHOOTER_FLAGS > "$OUT/shooter.log" 2>&1 &
SHOOTER_PID=$!

STATUS=0
wait $STRAFER_PID || STATUS=1
wait $SHOOTER_PID || STATUS=1
wait $SERVER_PID || STATUS=1

for name in server strafer shooter; do
  echo "----- $name ($VARIANT)"
  grep -E "NETSTATS|NETTEST|ERROR|error|joined|connected" "$OUT/$name.log" || true
  if grep -q "SCRIPT ERROR" "$OUT/$name.log"; then
    echo "script error in $name"
    grep -A4 "SCRIPT ERROR" "$OUT/$name.log" | head -40
    STATUS=1
  fi
done
exit $STATUS
