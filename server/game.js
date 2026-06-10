// game.js — 권위(authoritative) 게임 시뮬레이션. 서버에서만 실행한다.
// LÖVE 버전 src/game/world.lua 를 그대로 JS로 옮긴 것.

const ARENA_W = 960;
const ARENA_H = 720;

const PLAYER_SPEED  = 230;
const PLAYER_R      = 16;
const MAX_HP        = 100;
const BULLET_SPEED  = 520;
const BULLET_R      = 4;
const BULLET_DMG    = 12;
const BULLET_LIFE   = 1.4;
const FIRE_COOLDOWN = 0.26;
const COUNTDOWN     = 3.0;

const ZONE_START  = 640;
const ZONE_MIN    = 90;
const ZONE_SHRINK = 16;   // px/초
const ZONE_DMG    = 9;    // hp/초

// 엄폐물 (이동/총알 차단) — 두 플레이어에게 대칭
const OBSTACLES = [
  { x: 300, y: 120, w: 40,  h: 160 },
  { x: 620, y: 120, w: 40,  h: 160 },
  { x: 300, y: 440, w: 40,  h: 160 },
  { x: 620, y: 440, w: 40,  h: 160 },
  { x: 440, y: 300, w: 80,  h: 120 },
  { x: 130, y: 340, w: 130, h: 40  },
  { x: 700, y: 340, w: 130, h: 40  },
];

// 클라이언트가 렌더링에 쓸 정적 설정 (매치 시작 때 1회 전송)
const CONFIG = {
  arenaW: ARENA_W, arenaH: ARENA_H,
  playerR: PLAYER_R, bulletR: BULLET_R, maxHp: MAX_HP,
  obstacles: OBSTACLES,
};

const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);

function hitsObstacle(cx, cy, r) {
  for (const o of OBSTACLES) {
    const nx = clamp(cx, o.x, o.x + o.w);
    const ny = clamp(cy, o.y, o.y + o.h);
    const ddx = cx - nx, ddy = cy - ny;
    if (ddx * ddx + ddy * ddy < r * r) return true;
  }
  return false;
}

const dist2 = (ax, ay, bx, by) => {
  const dx = ax - bx, dy = ay - by;
  return dx * dx + dy * dy;
};

function makePlayer(x, y, angle) {
  return {
    x, y, hp: MAX_HP, angle, alive: true, cooldown: 0,
    input: { dx: 0, dy: 0, aim: angle, shoot: false },
  };
}

class Game {
  constructor() { this.reset(); }

  reset() {
    this.phase = "countdown";
    this.winner = 0;
    this.countdown = COUNTDOWN;
    this.playTime = 0;
    this.players = [
      makePlayer(90,          ARENA_H / 2, 0),
      makePlayer(ARENA_W - 90, ARENA_H / 2, Math.PI),
    ];
    this.bullets = [];
    this.zone = { cx: ARENA_W / 2, cy: ARENA_H / 2, r: ZONE_START };
  }

  // id: 0|1 (플레이어 인덱스)
  setInput(id, input) {
    const p = this.players[id];
    if (p) p.input = input;
  }

  _spawnBullet(p, ownerId) {
    const dx = Math.cos(p.angle), dy = Math.sin(p.angle);
    this.bullets.push({
      x: p.x + dx * (PLAYER_R + BULLET_R + 2),
      y: p.y + dy * (PLAYER_R + BULLET_R + 2),
      vx: dx * BULLET_SPEED,
      vy: dy * BULLET_SPEED,
      owner: ownerId,
      life: BULLET_LIFE,
    });
  }

  _movePlayer(p, dt) {
    let dx = p.input.dx, dy = p.input.dy;
    const len = Math.sqrt(dx * dx + dy * dy);
    if (len > 0) { dx /= len; dy /= len; }
    const step = PLAYER_SPEED * dt;

    const nx = p.x + dx * step;
    if (!hitsObstacle(nx, p.y, PLAYER_R)) p.x = nx;
    const ny = p.y + dy * step;
    if (!hitsObstacle(p.x, ny, PLAYER_R)) p.y = ny;

    p.x = clamp(p.x, PLAYER_R, ARENA_W - PLAYER_R);
    p.y = clamp(p.y, PLAYER_R, ARENA_H - PLAYER_R);
  }

  update(dt) {
    if (this.phase === "countdown") {
      this.countdown -= dt;
      if (this.countdown <= 0) this.phase = "playing";
      return;
    }
    if (this.phase !== "playing") return;

    this.playTime += dt;
    this.zone.r = Math.max(ZONE_MIN, ZONE_START - ZONE_SHRINK * this.playTime);

    for (let id = 0; id < this.players.length; id++) {
      const p = this.players[id];
      if (!p.alive) continue;
      this._movePlayer(p, dt);
      p.angle = p.input.aim;
      p.cooldown -= dt;
      if (p.input.shoot && p.cooldown <= 0) {
        this._spawnBullet(p, id);
        p.cooldown = FIRE_COOLDOWN;
      }
      const d = Math.sqrt(dist2(p.x, p.y, this.zone.cx, this.zone.cy));
      if (d > this.zone.r - PLAYER_R) p.hp -= ZONE_DMG * dt;
      if (p.hp <= 0) { p.hp = 0; p.alive = false; }
    }

    for (let i = this.bullets.length - 1; i >= 0; i--) {
      const b = this.bullets[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;

      let dead = false;
      if (b.life <= 0 || b.x < 0 || b.x > ARENA_W || b.y < 0 || b.y > ARENA_H) {
        dead = true;
      } else if (hitsObstacle(b.x, b.y, BULLET_R)) {
        dead = true;
      } else {
        for (let id = 0; id < this.players.length; id++) {
          const p = this.players[id];
          if (p.alive && id !== b.owner) {
            const rr = PLAYER_R + BULLET_R;
            if (dist2(b.x, b.y, p.x, p.y) < rr * rr) {
              p.hp -= BULLET_DMG;
              if (p.hp <= 0) { p.hp = 0; p.alive = false; }
              dead = true;
              break;
            }
          }
        }
      }
      if (dead) this.bullets.splice(i, 1);
    }

    const a1 = this.players[0].alive, a2 = this.players[1].alive;
    if (!a1 || !a2) {
      this.phase = "ended";
      if (a1 && !a2) this.winner = 1;
      else if (a2 && !a1) this.winner = 2;
      else this.winner = 0;
    }
  }

  forceWin(winnerId) {
    this.phase = "ended";
    this.winner = winnerId;
  }

  // 클라이언트로 보낼 스냅샷 (좌표 정수 반올림)
  snapshot() {
    const r = Math.round;
    return {
      phase: this.phase,
      winner: this.winner,
      countdown: Math.max(0, this.countdown),
      players: this.players.map((p) => ({
        x: r(p.x), y: r(p.y), hp: r(p.hp), angle: p.angle, alive: p.alive,
      })),
      bullets: this.bullets.map((b) => ({ x: r(b.x), y: r(b.y) })),
      zone: { cx: r(this.zone.cx), cy: r(this.zone.cy), r: r(this.zone.r) },
    };
  }
}

module.exports = { Game, CONFIG };
