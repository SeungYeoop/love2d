// main.js — 웹 클라이언트. WebSocket으로 서버에 입력을 보내고 스냅샷을 렌더링한다.
"use strict";

// ── 서버 주소 결정 ─────────────────────────────────────────
function serverUrl() {
  const p = new URLSearchParams(location.search);
  if (p.get("server")) return p.get("server");
  if (window.GAME_SERVER) return window.GAME_SERVER;
  if (location.protocol === "file:") return "ws://localhost:8080";
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  return `${proto}//${location.host}`;
}

// ── DOM ────────────────────────────────────────────────────
const $ = (id) => document.getElementById(id);
const menuEl   = $("menu");
const gameEl   = $("gameScreen");
const roomInput = $("room");
const playBtn  = $("playBtn");
const statusEl = $("status");
const canvas   = $("canvas");
const ctx      = canvas.getContext("2d");

// URL ?room=CODE 가 있으면 미리 채워준다 (친구 초대 링크).
const initialRoom = new URLSearchParams(location.search).get("room");
if (initialRoom) roomInput.value = initialRoom.toUpperCase();

// ── 상태 ───────────────────────────────────────────────────
const state = {
  ws: null,
  you: 0,          // 1 또는 2 (내 플레이어 번호)
  config: null,    // 서버가 보낸 정적 설정(arena, obstacles ...)
  snapshot: null,  // 최신 스냅샷
  inGame: false,
  message: null,   // 오버레이 안내 메시지(상대 퇴장 등)
  mouse: { x: 480, y: 360 },
  keys: {},
};

// ── 연결 / 매칭 ────────────────────────────────────────────
function connect(room) {
  let ws;
  try {
    ws = new WebSocket(serverUrl());
  } catch (e) {
    statusEl.textContent = "서버 주소가 올바르지 않습니다.";
    return;
  }
  state.ws = ws;
  playBtn.disabled = true;
  statusEl.textContent = "서버에 연결 중...";

  ws.onopen = () => {
    statusEl.textContent = "매칭 대기 중...";
    ws.send(JSON.stringify({ t: "join", room }));
  };

  ws.onmessage = (ev) => {
    let msg;
    try { msg = JSON.parse(ev.data); } catch { return; }
    handleMessage(msg);
  };

  ws.onclose = () => {
    if (state.inGame) {
      state.message = "서버 연결이 끊겼습니다.  [ESC] 메뉴로";
    } else {
      statusEl.textContent = "연결이 종료되었습니다.";
      playBtn.disabled = false;
    }
  };

  ws.onerror = () => {
    statusEl.textContent = "서버에 연결할 수 없습니다. (서버 주소/상태 확인)";
    playBtn.disabled = false;
  };
}

function handleMessage(msg) {
  switch (msg.t) {
    case "waiting":
      statusEl.textContent = `방 "${msg.room}" — 상대를 기다리는 중...`;
      break;
    case "full":
      statusEl.textContent = "그 방은 이미 2명이 차 있습니다. 다른 코드를 써보세요.";
      playBtn.disabled = false;
      break;
    case "start":
      state.you = msg.you;
      state.config = msg.config;
      state.message = null;
      enterGame();
      break;
    case "state":
      state.snapshot = msg.snapshot;
      break;
    case "opponent_left":
      state.message = "상대가 나갔습니다.  [ESC] 메뉴로";
      break;
  }
}

function enterGame() {
  state.inGame = true;
  menuEl.classList.add("hidden");
  gameEl.classList.remove("hidden");
}

function leaveGame() {
  state.inGame = false;
  state.snapshot = null;
  state.message = null;
  if (state.ws) { try { state.ws.close(); } catch {} state.ws = null; }
  gameEl.classList.add("hidden");
  menuEl.classList.remove("hidden");
  playBtn.disabled = false;
  statusEl.textContent = "";
}

// ── 입력 전송 (30Hz) ───────────────────────────────────────
function readInput() {
  const k = state.keys;
  const dx = (k["d"] || k["arrowright"] ? 1 : 0) - (k["a"] || k["arrowleft"] ? 1 : 0);
  const dy = (k["s"] || k["arrowdown"] ? 1 : 0) - (k["w"] || k["arrowup"] ? 1 : 0);

  let aim = 0;
  const snap = state.snapshot;
  if (snap) {
    const me = snap.players[state.you - 1];
    aim = Math.atan2(state.mouse.y - me.y, state.mouse.x - me.x);
  }
  const shoot = !!state.mouse.down || !!k[" "];
  return { t: "input", dx, dy, aim, shoot };
}

setInterval(() => {
  if (state.inGame && state.snapshot && state.ws && state.ws.readyState === 1) {
    state.ws.send(JSON.stringify(readInput()));
  }
}, 1000 / 30);

// ── 이벤트 ─────────────────────────────────────────────────
playBtn.addEventListener("click", () => {
  const room = (roomInput.value || "PLAY").trim().toUpperCase();
  connect(room);
});
roomInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter") playBtn.click();
});

window.addEventListener("keydown", (e) => {
  const key = e.key.toLowerCase();
  state.keys[key] = true;
  if (!state.inGame) return;

  if (key === "escape") leaveGame();
  if (key === "r" && state.snapshot && state.snapshot.phase === "ended" && !state.message) {
    if (state.ws && state.ws.readyState === 1) state.ws.send(JSON.stringify({ t: "rematch" }));
  }
  if ([" ", "arrowup", "arrowdown", "arrowleft", "arrowright"].includes(key)) e.preventDefault();
});
window.addEventListener("keyup", (e) => { state.keys[e.key.toLowerCase()] = false; });

function updateMouse(e) {
  const rect = canvas.getBoundingClientRect();
  state.mouse.x = (e.clientX - rect.left) * (canvas.width / rect.width);
  state.mouse.y = (e.clientY - rect.top) * (canvas.height / rect.height);
}
canvas.addEventListener("mousemove", updateMouse);
canvas.addEventListener("mousedown", (e) => { updateMouse(e); state.mouse.down = true; e.preventDefault(); });
window.addEventListener("mouseup", () => { state.mouse.down = false; });
canvas.addEventListener("contextmenu", (e) => e.preventDefault());

// ── 렌더링 ─────────────────────────────────────────────────
const COL = {
  me: "#4cd972", enemy: "#f25a5a", dead: "#666a72",
  wall: "#525666", bullet: "#ffe659", zone: "#59b3ff",
};

function roundRect(x, y, w, h, r) {
  ctx.beginPath();
  if (ctx.roundRect) ctx.roundRect(x, y, w, h, r);
  else ctx.rect(x, y, w, h);
}

function drawPlayer(p, color, R) {
  if (!p.alive) color = COL.dead;
  // 총구
  ctx.strokeStyle = "#e6e6e6"; ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(p.x, p.y);
  ctx.lineTo(p.x + Math.cos(p.angle) * (R + 10), p.y + Math.sin(p.angle) * (R + 10));
  ctx.stroke();
  // 몸체
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.arc(p.x, p.y, R, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = "rgba(0,0,0,0.35)"; ctx.lineWidth = 2; ctx.stroke();
  if (!p.alive) {
    ctx.strokeStyle = "rgba(255,255,255,0.85)"; ctx.lineWidth = 3;
    const r = R * 0.6;
    ctx.beginPath();
    ctx.moveTo(p.x - r, p.y - r); ctx.lineTo(p.x + r, p.y + r);
    ctx.moveTo(p.x + r, p.y - r); ctx.lineTo(p.x - r, p.y + r);
    ctx.stroke();
  }
}

function bar(x, y, w, h, frac, color, label) {
  ctx.fillStyle = "rgba(0,0,0,0.5)"; ctx.fillRect(x - 2, y - 2, w + 4, h + 4);
  ctx.fillStyle = "#26282e"; ctx.fillRect(x, y, w, h);
  ctx.fillStyle = color; ctx.fillRect(x, y, w * Math.max(0, frac), h);
  ctx.fillStyle = "#fff"; ctx.font = "16px 'Malgun Gothic', sans-serif";
  ctx.textAlign = "left"; ctx.textBaseline = "alphabetic";
  ctx.fillText(label, x, y - 6);
}

function centerText(text, y, size, color) {
  ctx.fillStyle = color; ctx.textAlign = "center"; ctx.textBaseline = "middle";
  ctx.font = `bold ${size}px 'Malgun Gothic', sans-serif`;
  ctx.fillText(text, canvas.width / 2, y);
}

function render() {
  requestAnimationFrame(render);
  if (!state.inGame || !state.config) return;

  const cfg = state.config;
  const W = canvas.width, H = canvas.height;
  const snap = state.snapshot;

  ctx.fillStyle = "#1a1c20"; ctx.fillRect(0, 0, W, H);

  if (!snap) { centerText("매칭 완료 — 시작 중...", H / 2, 28, "#fff"); return; }

  const z = snap.zone;

  // 안전지대 밖 위험 표시 (원 바깥만 붉게)
  ctx.save();
  ctx.beginPath();
  ctx.rect(0, 0, W, H);
  ctx.arc(z.cx, z.cy, z.r, 0, Math.PI * 2);
  ctx.clip("evenodd");
  ctx.fillStyle = "rgba(150,28,32,0.28)";
  ctx.fillRect(0, 0, W, H);
  ctx.restore();

  // 안전지대 경계
  ctx.strokeStyle = COL.zone; ctx.lineWidth = 3;
  ctx.beginPath(); ctx.arc(z.cx, z.cy, z.r, 0, Math.PI * 2); ctx.stroke();

  // 엄폐물
  for (const o of cfg.obstacles) {
    ctx.fillStyle = COL.wall; roundRect(o.x, o.y, o.w, o.h, 4); ctx.fill();
    ctx.strokeStyle = "rgba(0,0,0,0.35)"; ctx.lineWidth = 2; ctx.stroke();
  }

  // 총알
  ctx.fillStyle = COL.bullet;
  for (const b of snap.bullets) {
    ctx.beginPath(); ctx.arc(b.x, b.y, cfg.bulletR, 0, Math.PI * 2); ctx.fill();
  }

  // 플레이어 (상대 먼저)
  const myIdx = state.you - 1, enIdx = 1 - myIdx;
  drawPlayer(snap.players[enIdx], COL.enemy, cfg.playerR);
  drawPlayer(snap.players[myIdx], COL.me, cfg.playerR);

  // HUD
  const me = snap.players[myIdx], en = snap.players[enIdx];
  bar(16, 30, 240, 16, me.hp / cfg.maxHp, COL.me, "YOU  " + Math.ceil(me.hp));
  bar(W - 256, 30, 240, 16, en.hp / cfg.maxHp, COL.enemy, "ENEMY  " + Math.ceil(en.hp));

  // 카운트다운
  if (snap.phase === "countdown") {
    ctx.fillStyle = "rgba(0,0,0,0.45)"; ctx.fillRect(0, 0, W, H);
    centerText(String(Math.max(1, Math.ceil(snap.countdown))), H / 2 - 30, 150, "#fff");
    centerText("WASD 이동 · 마우스 조준 · 좌클릭/스페이스 사격", H / 2 + 90, 22, "#e6e6f0");
  }

  // 종료
  if (snap.phase === "ended") {
    ctx.fillStyle = "rgba(0,0,0,0.55)"; ctx.fillRect(0, 0, W, H);
    let msg, col;
    if (snap.winner === state.you) { msg = "YOU WIN"; col = COL.me; }
    else if (snap.winner === 0)    { msg = "DRAW"; col = "#fff"; }
    else                           { msg = "YOU LOSE"; col = COL.enemy; }
    centerText(msg, H / 2 - 40, 96, col);
    if (!state.message)
      centerText("[R] 재대결    [ESC] 메뉴로", H / 2 + 50, 24, "#dcdce6");
  }

  // 오버레이 메시지 (상대 퇴장/연결 끊김)
  if (state.message) centerText(state.message, H - 60, 22, "#ffd166");
}
requestAnimationFrame(render);
