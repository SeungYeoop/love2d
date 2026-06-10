# 배포 가이드 — 웹 1대1 배틀 (Vercel + Render)

이 게임은 두 부분으로 나뉩니다.

| 부분 | 역할 | 배포처 |
|------|------|--------|
| `web/`    | 브라우저 클라이언트 (HTML5 Canvas) | **Vercel** (정적) |
| `server/` | 실시간 권위 서버 (WebSocket)        | **Render** (또는 Railway/Fly 등 WS 지원 호스트) |

> ⚠️ **Vercel만으로는 안 됩니다.** Vercel은 항상 떠 있는 WebSocket 게임 서버를 돌릴 수 없어서,
> 실시간 서버는 반드시 WS를 지원하는 별도 호스트(Render 등)에 올려야 합니다.

---

## 1. 로컬에서 먼저 테스트

```bash
cd server
npm install
npm start            # http://localhost:8080
```

브라우저 탭 2개로 `http://localhost:8080` 접속 → 같은 방 코드 입력 → **입장/매칭**.
(서버가 개발 편의를 위해 `web/` 정적 파일도 같이 서빙합니다.)

---

## 2. 서버를 Render에 배포 (무료)

1. 이 저장소를 GitHub에 푸시한다.
2. [render.com](https://render.com) → **New → Web Service** → 이 저장소 선택.
3. 설정:
   - **Root Directory**: `server`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Instance Type**: Free
4. 배포되면 주소가 나온다 (예: `https://my-battle.onrender.com`).
   - WebSocket 주소는 `https` → `wss` 로 바꾼 것: `wss://my-battle.onrender.com`

> Render 무료 플랜은 15분간 접속이 없으면 잠들고, 다음 접속 시 ~30초 콜드 스타트가 있습니다.

---

## 3. 클라이언트를 Vercel에 배포

1. **`web/config.js`** 를 열어 서버 주소를 넣는다:
   ```js
   window.GAME_SERVER = "wss://my-battle.onrender.com";
   ```
   커밋 후 푸시.
2. [vercel.com](https://vercel.com) → **Add New → Project** → 이 저장소 import.
3. 설정에서 **Root Directory** 를 `web` 로 지정한다. (Framework Preset: Other, 빌드 명령 없음)
4. Deploy → `https://내-게임.vercel.app` 주소가 나온다.

이제 친구에게 그 Vercel 주소를 보내고, **둘이 같은 방 코드**를 입력하면 인터넷으로 1대1 대전이 됩니다.
초대 링크에 방 코드를 박아 보내도 됩니다: `https://내-게임.vercel.app/?room=FRIEND1`

---

## 빠른 점검

- 클라이언트가 서버에 연결 못 하면: `config.js` 의 `GAME_SERVER` 가 `wss://` 인지, Render 서버가 깨어 있는지 확인.
- "그 방은 이미 2명" → 방 코드를 바꾸세요(한 방은 2명까지).
- 서버 로직만 빠르게 검증하려면: `cd server && node smoketest.js`
