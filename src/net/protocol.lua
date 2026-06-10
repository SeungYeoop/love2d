-- protocol.lua — 네트워크 직렬화.
-- 호스트는 월드 스냅샷을 보내고, 클라이언트는 입력을 보낸다.
-- 숫자는 정수로 반올림해 문자열로 압축한다. 구분자: ';' 와 ','
local P = {}

local PHASE_TO_ID = { waiting = 0, countdown = 1, playing = 2, ended = 3 }
local ID_TO_PHASE = { [0] = "waiting", [1] = "countdown", [2] = "playing", [3] = "ended" }

local function round(n) return math.floor(n + 0.5) end

-- 빈 필드까지 보존하는 split (plain find)
local function split(s, sep)
    local out, start = {}, 1
    local i = string.find(s, sep, start, true)
    while i do
        out[#out + 1] = string.sub(s, start, i - 1)
        start = i + #sep
        i = string.find(s, sep, start, true)
    end
    out[#out + 1] = string.sub(s, start)
    return out
end

-- ── 입력 (클라이언트 → 호스트) ─────────────────────────────
-- I;dx;dy;aim(rad*1000);shoot
function P.encodeInput(inp)
    return table.concat({
        "I",
        round(inp.dx),
        round(inp.dy),
        round(inp.aim * 1000),
        inp.shoot and 1 or 0,
    }, ";")
end

function P.decodeInput(str)
    local p = split(str, ";")
    if p[1] ~= "I" then return nil end
    return {
        dx    = tonumber(p[2]) or 0,
        dy    = tonumber(p[3]) or 0,
        aim   = (tonumber(p[4]) or 0) / 1000,
        shoot = (tonumber(p[5]) or 0) == 1,
    }
end

-- ── 스냅샷 (호스트 → 클라이언트) ───────────────────────────
-- S;phase,winner,countdown*100;p1...;p2...;zone;bullets
local function encPlayer(pl)
    return table.concat({
        round(pl.x), round(pl.y), round(pl.hp), round(pl.angle * 1000),
    }, ",")
end

function P.encodeSnapshot(state)
    local head = table.concat({
        PHASE_TO_ID[state.phase] or 0,
        state.winner or 0,
        round((state.countdown or 0) * 100),
    }, ",")

    local zone = table.concat({
        round(state.zone.cx), round(state.zone.cy), round(state.zone.r),
    }, ",")

    local bt = {}
    for _, b in ipairs(state.bullets) do
        bt[#bt + 1] = round(b.x)
        bt[#bt + 1] = round(b.y)
    end

    return table.concat({
        "S",
        head,
        encPlayer(state.players[1]),
        encPlayer(state.players[2]),
        zone,
        table.concat(bt, ","),
    }, ";")
end

local function decPlayer(str)
    local p = split(str, ",")
    local hp = tonumber(p[3]) or 0
    return {
        x     = tonumber(p[1]) or 0,
        y     = tonumber(p[2]) or 0,
        hp    = hp,
        angle = (tonumber(p[4]) or 0) / 1000,
        alive = hp > 0,
    }
end

-- 클라이언트가 그릴 수 있는 view 테이블을 돌려준다 (월드와 동일한 필드명).
function P.decodeSnapshot(str)
    local p = split(str, ";")
    if p[1] ~= "S" then return nil end

    local head = split(p[2], ",")
    local zone = split(p[5], ",")

    local bullets = {}
    if p[6] and p[6] ~= "" then
        local nums = split(p[6], ",")
        for i = 1, #nums - 1, 2 do
            bullets[#bullets + 1] = {
                x = tonumber(nums[i]) or 0,
                y = tonumber(nums[i + 1]) or 0,
            }
        end
    end

    return {
        phase     = ID_TO_PHASE[tonumber(head[1])] or "waiting",
        winner    = tonumber(head[2]) or 0,
        countdown = (tonumber(head[3]) or 0) / 100,
        players   = { decPlayer(p[3]), decPlayer(p[4]) },
        bullets   = bullets,
        zone      = {
            cx = tonumber(zone[1]) or 0,
            cy = tonumber(zone[2]) or 0,
            r  = tonumber(zone[3]) or 0,
        },
    }
end

return P
