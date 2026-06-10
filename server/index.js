// index.js — WebSocket 권위 서버 + 방 코드 매칭.
// 로컬 개발 시에는 web/ 정적 파일도 함께 서빙한다(http://localhost:8080).
const http = require("http");
const fs = require("fs");
const path = require("path");
const { WebSocketServer } = require("ws");
const { Game, CONFIG } = require("./game");

const PORT     = process.env.PORT || 8080;
const TICK_HZ  = 30;
const TICK_DT  = 1 / TICK_HZ;
const WEB_DIR  = path.join(__dirname, "..", "web");

// ── 정적 파일 서빙 (로컬 편의용) ────────────────────────────
const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js":   "text/javascript; charset=utf-8",
  ".css":  "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
};

const server = http.createServer((req, res) => {
  if (req.url === "/health") { res.writeHead(200); res.end("ok"); return; }

  let urlPath = decodeURIComponent(req.url.split("?")[0]);
  if (urlPath === "/") urlPath = "/index.html";
  const filePath = path.join(WEB_DIR, path.normalize(urlPath));
  if (!filePath.startsWith(WEB_DIR)) { res.writeHead(403); res.end(); return; }

  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end("Not found"); return; }
    res.writeHead(200, { "Content-Type": MIME[path.extname(filePath)] || "application/octet-stream" });
    res.end(data);
  });
});

// ── 방(매칭) 관리 ──────────────────────────────────────────
const rooms = new Map(); // code -> { players: [ws, ws], game, loop }

function send(ws, obj) {
  if (ws && ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}

function startMatch(room) {
  room.game = new Game();
  room.players.forEach((ws, i) => {
    ws.playerId = i;              // 0 또는 1
    send(ws, { t: "start", you: i + 1, config: CONFIG });
  });

  room.loop = setInterval(() => {
    const g = room.game;
    g.update(TICK_DT);
    const snap = g.snapshot();
    for (const ws of room.players) send(ws, { t: "state", snapshot: snap });
  }, 1000 / TICK_HZ);
}

function endRoom(room, reason) {
  if (!room) return;
  if (room.loop) clearInterval(room.loop);
  for (const ws of room.players) {
    if (reason) send(ws, { t: reason });
  }
  rooms.delete(room.code);
}

const wss = new WebSocketServer({ server });

wss.on("connection", (ws) => {
  ws.room = null;

  ws.on("message", (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }

    if (msg.t === "join") {
      const code = (msg.room || "PLAY").toString().toUpperCase().slice(0, 12);
      let room = rooms.get(code);

      if (!room) {
        room = { code, players: [ws], game: null, loop: null };
        rooms.set(code, room);
        ws.room = room;
        send(ws, { t: "waiting", room: code });
      } else if (room.players.length === 1) {
        room.players.push(ws);
        ws.room = room;
        console.log(`[match] room "${code}" 시작 (2/2)`);
        startMatch(room);
      } else {
        send(ws, { t: "full" }); // 방이 가득 참
      }
    }

    else if (msg.t === "input" && ws.room && ws.room.game && ws.playerId != null) {
      ws.room.game.setInput(ws.playerId, {
        dx: Math.sign(msg.dx || 0),
        dy: Math.sign(msg.dy || 0),
        aim: +msg.aim || 0,
        shoot: !!msg.shoot,
      });
    }

    else if (msg.t === "rematch" && ws.room && ws.room.game) {
      if (ws.room.game.phase === "ended") ws.room.game.reset();
    }
  });

  ws.on("close", () => {
    const room = ws.room;
    if (!room) return;
    // 상대가 남아 있으면 부전승 처리 후 방 종료
    const other = room.players.find((p) => p !== ws);
    if (room.game && room.game.phase !== "ended" && other && other.playerId != null) {
      room.game.forceWin(other.playerId + 1);
    }
    if (room.loop) clearInterval(room.loop);
    if (other) {
      // 종료 상태를 마지막으로 한 번 더 전송한 뒤 안내
      if (room.game) send(other, { t: "state", snapshot: room.game.snapshot() });
      send(other, { t: "opponent_left" });
    }
    rooms.delete(room.code);
  });
});

server.listen(PORT, () => {
  console.log(`Battle server on :${PORT}  (ws + static web/)`);
});
