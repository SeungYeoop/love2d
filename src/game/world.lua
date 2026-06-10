-- world.lua — 권위(authoritative) 게임 시뮬레이션. 호스트만 update를 돌린다.
-- 클라이언트는 이 모듈을 시뮬레이션엔 쓰지 않고, 상수/엄폐물 정의만 공유한다.
local World = {}

-- 아레나는 창과 무관하게 고정 좌표계를 쓴다(호스트/클라이언트 동일).
World.ARENA_W = 960
World.ARENA_H = 720

local W, H = World.ARENA_W, World.ARENA_H

-- 게임 밸런스 상수
local PLAYER_SPEED  = 230
local PLAYER_R      = 16
local MAX_HP        = 100
local BULLET_SPEED  = 520
local BULLET_R      = 4
local BULLET_DMG    = 12
local BULLET_LIFE   = 1.4
local FIRE_COOLDOWN = 0.26
local COUNTDOWN     = 3.0

-- 안전지대(zone): 중앙에서 서서히 축소, 바깥은 초당 피해
local ZONE_START  = 640
local ZONE_MIN    = 90
local ZONE_SHRINK = 16      -- px/초
local ZONE_DMG    = 9       -- hp/초

World.PLAYER_R = PLAYER_R
World.BULLET_R = BULLET_R
World.MAX_HP   = MAX_HP

-- 엄폐물 (이동/총알 차단). 두 플레이어에게 대칭이 되도록 배치.
World.OBSTACLES = {
    { x = 300, y = 120, w = 40,  h = 160 },
    { x = 620, y = 120, w = 40,  h = 160 },
    { x = 300, y = 440, w = 40,  h = 160 },
    { x = 620, y = 440, w = 40,  h = 160 },
    { x = 440, y = 300, w = 80,  h = 120 },  -- 중앙 블록
    { x = 130, y = 340, w = 130, h = 40  },
    { x = 700, y = 340, w = 130, h = 40  },
}

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi else return v end
end

-- 원(cx,cy,r)이 어떤 엄폐물과 겹치는가?
local function hitsObstacle(cx, cy, r)
    for _, o in ipairs(World.OBSTACLES) do
        local nx = clamp(cx, o.x, o.x + o.w)
        local ny = clamp(cy, o.y, o.y + o.h)
        local ddx, ddy = cx - nx, cy - ny
        if ddx * ddx + ddy * ddy < r * r then return true end
    end
    return false
end

local function mkPlayer(x, y, angle)
    return {
        x = x, y = y, hp = MAX_HP, angle = angle, alive = true, cooldown = 0,
        input = { dx = 0, dy = 0, aim = angle, shoot = false },
    }
end

function World.new()
    return {
        phase     = "countdown",
        winner    = 0,
        countdown = COUNTDOWN,
        playTime  = 0,
        players   = {
            mkPlayer(90,     H / 2, 0),         -- p1: 좌측, 우측을 봄
            mkPlayer(W - 90, H / 2, math.pi),   -- p2: 우측, 좌측을 봄
        },
        bullets   = {},
        zone      = { cx = W / 2, cy = H / 2, r = ZONE_START },
    }
end

local function spawnBullet(state, p, owner)
    local dx, dy = math.cos(p.angle), math.sin(p.angle)
    state.bullets[#state.bullets + 1] = {
        x = p.x + dx * (PLAYER_R + BULLET_R + 2),
        y = p.y + dy * (PLAYER_R + BULLET_R + 2),
        vx = dx * BULLET_SPEED,
        vy = dy * BULLET_SPEED,
        owner = owner,
        life = BULLET_LIFE,
    }
end

local function movePlayer(p, dt)
    local dx, dy = p.input.dx, p.input.dy
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then dx, dy = dx / len, dy / len end
    local step = PLAYER_SPEED * dt

    -- 축 분리 이동 — 엄폐물에 막히면 해당 축만 취소
    local nx = p.x + dx * step
    if not hitsObstacle(nx, p.y, PLAYER_R) then p.x = nx end
    local ny = p.y + dy * step
    if not hitsObstacle(p.x, ny, PLAYER_R) then p.y = ny end

    p.x = clamp(p.x, PLAYER_R, W - PLAYER_R)
    p.y = clamp(p.y, PLAYER_R, H - PLAYER_R)
end

local function dist2(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return dx * dx + dy * dy
end

function World.update(state, dt)
    if state.phase == "countdown" then
        state.countdown = state.countdown - dt
        if state.countdown <= 0 then state.phase = "playing" end
        return
    end
    if state.phase ~= "playing" then return end  -- ended → 정지

    state.playTime = state.playTime + dt
    state.zone.r = math.max(ZONE_MIN, ZONE_START - ZONE_SHRINK * state.playTime)

    -- 플레이어
    for _, p in ipairs(state.players) do
        if p.alive then
            movePlayer(p, dt)
            p.angle = p.input.aim
            p.cooldown = p.cooldown - dt
            if p.input.shoot and p.cooldown <= 0 then
                spawnBullet(state, p, p)
                p.cooldown = FIRE_COOLDOWN
            end
            -- 안전지대 밖 피해
            local d = math.sqrt(dist2(p.x, p.y, state.zone.cx, state.zone.cy))
            if d > state.zone.r - PLAYER_R then
                p.hp = p.hp - ZONE_DMG * dt
            end
            if p.hp <= 0 then p.hp = 0; p.alive = false end
        end
    end

    -- 총알
    for i = #state.bullets, 1, -1 do
        local b = state.bullets[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt

        local dead = false
        if b.life <= 0 or b.x < 0 or b.x > W or b.y < 0 or b.y > H then
            dead = true
        elseif hitsObstacle(b.x, b.y, BULLET_R) then
            dead = true
        else
            for _, p in ipairs(state.players) do
                if p.alive and p ~= b.owner then
                    local rr = PLAYER_R + BULLET_R
                    if dist2(b.x, b.y, p.x, p.y) < rr * rr then
                        p.hp = p.hp - BULLET_DMG
                        if p.hp <= 0 then p.hp = 0; p.alive = false end
                        dead = true
                        break
                    end
                end
            end
        end

        if dead then table.remove(state.bullets, i) end
    end

    -- 승패 판정
    local a1, a2 = state.players[1].alive, state.players[2].alive
    if not a1 or not a2 then
        state.phase = "ended"
        if a1 and not a2 then state.winner = 1
        elseif a2 and not a1 then state.winner = 2
        else state.winner = 0 end  -- 무승부
    end
end

-- 상대가 나가서 즉시 승부를 끝낼 때 사용 (winner = 살아남은 쪽)
function World.forceWin(state, winnerId)
    state.phase = "ended"
    state.winner = winnerId
end

return World
