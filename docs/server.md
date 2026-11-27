# 멀티플레이 서버 올리기 (Render 무료 요금제)

서버는 `Dockerfile` 하나로 만들어진다. Godot 실행 파일로 프로젝트를 화면 없이 돌리며,
호스팅 서비스가 정해 주는 포트(`PORT`)에서 WebSocket 접속을 받는다.

## 처음 한 번

1. https://render.com 에서 계정을 만든다(GitHub 계정으로 로그인하면 저장소 연결이 쉽다).
2. 대시보드에서 **New → Blueprint** 를 고르고 `kosj/fps1` 저장소를 연결한다.
3. Render가 저장소의 `render.yaml`을 읽어 `fps1-server` 서비스를 보여 준다. **Apply** 를 누른다.
4. 빌드가 끝나면 서비스 화면 위쪽에 `https://fps1-server-xxxx.onrender.com` 형태의 주소가 나온다.
5. 로그에 `server listening on port 10000`이 보이면 준비된 것이다.

Blueprint 대신 **New → Web Service** 로 직접 만들 때는 Runtime을 **Docker**, Instance Type을 **Free**,
Region을 **Singapore** 로 고른다.

## 접속하기

주소의 `https://`를 `wss://`로 바꿔서 쓴다.

- 링크로: `https://kosj.github.io/fps1/?connect=wss://fps1-server-xxxx.onrender.com`
  이 링크를 친구에게 보내면 메뉴 없이 바로 서버에 들어온다.
- 메뉴에서: 주소 칸에 `wss://fps1-server-xxxx.onrender.com` 을 넣고 **JOIN SERVER**.

## 설정

Render의 서비스 → **Environment** 에서 바꾼다. 바꾸면 서버가 다시 뜬다.

| 변수 | 기본값 | 뜻 |
|---|---|---|
| `BOTS` | 4 | 빈자리를 채우는 봇 수. 0이면 사람만 |
| `MODE` | tdm | `tdm`(팀전) 또는 `dom`(점령전) |

## 무료 요금제에서 알아둘 것

- 15분 동안 접속이 없으면 서버가 내려가고, 다음 접속 때 다시 뜨는 데 1분쯤 걸린다.
  첫 사람은 **JOIN SERVER** 후 잠시 기다리거나 한 번 더 눌러야 할 수 있다.
- Render가 무료 서비스를 언제든 다시 시작할 수 있어 경기가 끊길 수 있다.
- CPU가 약하다. 사람이 많아지거나 봇이 많으면 버벅일 수 있으니 `BOTS`를 줄여 본다.
- `main`에 새 커밋이 올라가면 서버도 자동으로 다시 빌드된다(진행 중인 경기는 끊긴다).

## 내 PC에서 돌려 보기

```
docker build -t fps1-server .
docker run -p 10000:10000 -e BOTS=2 fps1-server
```

같은 PC의 게임에서 주소 `127.0.0.1:10000`으로 접속한다.
