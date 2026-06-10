// smoketest.js — 서버를 띄우고 가짜 클라 2개를 매칭/교전시켜 파이프라인을 검증한다.
const { spawn } = require("child_process");
const WebSocket = require("ws");

const PORT = 8099;
const srv = spawn("node", ["index.js"], { env: { ...process.env, PORT }, cwd: __dirname });
srv.stdout.on("data", (d) => process.stdout.write("[srv] " + d));
srv.stderr.on("data", (d) => process.stderr.write("[srv:err] " + d));

const log = (...a) => console.log(...a);
let done = false;
function finish(code) {
  if (done) return; done = true;
  srv.kill();
  setTimeout(() => process.exit(code), 200);
}

setTimeout(() => {
  const results = { c1: { started: false, snaps: 0, you: 0 }, c2: { started: false, snaps: 0, you: 0 } };
  let lastSnap = null;

  function mkClient(name, onStart) {
    const ws = new WebSocket(`ws://localhost:${PORT}`);
    ws.on("open", () => ws.send(JSON.stringify({ t: "join", room: "TEST1" })));
    ws.on("message", (raw) => {
      const m = JSON.parse(raw);
      const r = results[name];
      if (m.t === "waiting") log(`[${name}] waiting in ${m.room}`);
      else if (m.t === "start") {
        r.started = true; r.you = m.you;
        log(`[${name}] START you=${m.you} obstacles=${m.config.obstacles.length}`);
        if (onStart) onStart(ws);
      } else if (m.t === "state") {
        r.snaps++; lastSnap = m.snapshot;
      } else if (m.t === "opponent_left") {
        log(`[${name}] opponent_left`);
      }
    });
    return ws;
  }

  // c1: 가만히 있다가 사격(오른쪽), c2: 접속 후 잠시 뒤 끊어 부전승 확인
  const c1 = mkClient("c1", (ws) => {
    const iv = setInterval(() => ws.send(JSON.stringify({ t: "input", dx: 0, dy: 0, aim: 0, shoot: true })), 33);
    c1._iv = iv;
  });
  let c2;
  setTimeout(() => { c2 = mkClient("c2"); }, 300);

  // 1.2초 뒤 상태 점검
  setTimeout(() => {
    log(`\n[check] c1.snaps=${results.c1.snaps} c2.snaps=${results.c2.snaps}`);
    log(`[check] phase=${lastSnap && lastSnap.phase} p1=(${lastSnap && lastSnap.players[0].x},${lastSnap && lastSnap.players[0].y}) bullets=${lastSnap && lastSnap.bullets.length}`);
    const ok1 = results.c1.started && results.c2.started && results.c1.you === 1 && results.c2.you === 2;
    const ok2 = results.c1.snaps > 10 && results.c2.snaps > 10;
    const ok3 = lastSnap && (lastSnap.phase === "countdown" || lastSnap.phase === "playing");
    log(`[check] matched=${ok1} snapshots=${ok2} sane_phase=${ok3}`);

    // c2 연결 종료 → 부전승(c1 승) 확인
    clearInterval(c1._iv);
    c2.close();
    setTimeout(() => {
      const ok4 = lastSnap && lastSnap.phase === "ended" && lastSnap.winner === 1;
      log(`[check] forfeit_win(c1)=${ok4} winner=${lastSnap && lastSnap.winner}`);
      const pass = ok1 && ok2 && ok3 && ok4;
      log(pass ? "\n>>> ALL CHECKS PASSED" : "\n>>> FAILURES");
      finish(pass ? 0 : 1);
    }, 400);
  }, 1200);
}, 600);

setTimeout(() => { log("timeout"); finish(1); }, 6000);
