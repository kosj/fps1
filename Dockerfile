# 멀티플레이 서버 이미지 (Render 등 컨테이너 호스팅용).
# 내보내기 템플릿(1.2GB) 없이, Godot 실행 파일로 프로젝트를 그대로 화면 없이 돌린다.
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7-stable
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 \
    && curl -fsSL -o /tmp/godot.zip \
       "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /opt \
    && mv "/opt/Godot_v${GODOT_VERSION}_linux.x86_64" /usr/local/bin/godot \
    && rm /tmp/godot.zip \
    && apt-get purge -y curl unzip && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .
# 리소스를 미리 가져와 둔다(처음 실행할 때 시간이 걸리지 않게). 가져오기는 경고로도 0이 아닌 값을 낼 수 있다.
RUN godot --headless --import > /tmp/import.log 2>&1 || true; \
    test -d .godot/imported || (cat /tmp/import.log && exit 1)

# 호스팅 서비스가 정해 주는 포트($PORT)에서 듣는다. 봇 수는 BOTS, 모드는 MODE(tdm|dom)로 바꾼다.
ENV PORT=10000 BOTS=4 MODE=tdm
EXPOSE 10000
CMD ["sh", "-c", "exec godot --headless --path /app -- --server --port=${PORT} --bots=${BOTS} --mode=${MODE}"]
