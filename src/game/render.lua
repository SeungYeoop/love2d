-- render.lua — view 테이블을 받아 화면을 그린다.
-- view 필드는 호스트 월드 / 클라이언트 스냅샷이 동일하게 갖는다:
--   phase, winner, countdown, players[{x,y,hp,angle,alive}], bullets[{x,y}], zone{cx,cy,r}
local World = require("src.game.world")
local Font  = require("src.ui.font")
local R = {}

local COL = {
    me     = { 0.30, 0.85, 0.45 },
    enemy  = { 0.95, 0.35, 0.35 },
    dead   = { 0.40, 0.40, 0.45 },
    wall   = { 0.32, 0.34, 0.40 },
    bullet = { 1.00, 0.90, 0.35 },
    zone   = { 0.35, 0.70, 1.00 },
}

local function bar(x, y, w, h, frac, color, label)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 4)
    love.graphics.setColor(0.15, 0.15, 0.18)
    love.graphics.rectangle("fill", x, y, w, h, 3)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, w * math.max(0, frac), h, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(label, x, y - 18)
end

local function drawPlayer(p, color)
    if not p.alive then color = COL.dead end
    -- 조준 방향 총구
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setLineWidth(4)
    love.graphics.line(p.x, p.y,
        p.x + math.cos(p.angle) * (World.PLAYER_R + 10),
        p.y + math.sin(p.angle) * (World.PLAYER_R + 10))
    -- 몸체
    love.graphics.setColor(color)
    love.graphics.circle("fill", p.x, p.y, World.PLAYER_R)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", p.x, p.y, World.PLAYER_R)
    if not p.alive then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setLineWidth(3)
        local r = World.PLAYER_R * 0.6
        love.graphics.line(p.x - r, p.y - r, p.x + r, p.y + r)
        love.graphics.line(p.x + r, p.y - r, p.x - r, p.y + r)
    end
end

-- view, 내 플레이어 id(1|2), 호스트 여부
function R.draw(view, myId, isHost)
    local AW, AH = World.ARENA_W, World.ARENA_H

    love.graphics.setFont(Font.get(18))  -- HUD 기본 크기로 시작

    -- 배경
    love.graphics.clear(0.10, 0.11, 0.13)

    -- 안전지대: 바깥쪽 위험 지역을 스텐실로 붉게
    local z = view.zone
    love.graphics.stencil(function()
        love.graphics.circle("fill", z.cx, z.cy, z.r, 64)
    end, "replace", 1)
    love.graphics.setStencilTest("notequal", 1)
    love.graphics.setColor(0.55, 0.10, 0.12, 0.28)
    love.graphics.rectangle("fill", 0, 0, AW, AH)
    love.graphics.setStencilTest()

    love.graphics.setColor(COL.zone[1], COL.zone[2], COL.zone[3], 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", z.cx, z.cy, z.r, 64)

    -- 엄폐물
    for _, o in ipairs(World.OBSTACLES) do
        love.graphics.setColor(COL.wall)
        love.graphics.rectangle("fill", o.x, o.y, o.w, o.h, 4)
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", o.x, o.y, o.w, o.h, 4)
    end

    -- 총알
    love.graphics.setColor(COL.bullet)
    for _, b in ipairs(view.bullets) do
        love.graphics.circle("fill", b.x, b.y, World.BULLET_R)
    end

    -- 플레이어 (상대 먼저, 내 캐릭터 위에)
    local enemyId = (myId == 1) and 2 or 1
    drawPlayer(view.players[enemyId], COL.enemy)
    drawPlayer(view.players[myId],    COL.me)

    -- ── HUD ──────────────────────────────────────────────
    local me, en = view.players[myId], view.players[enemyId]
    bar(16, 28, 240, 16, me.hp / World.MAX_HP, COL.me, "YOU  " .. math.ceil(me.hp))
    bar(AW - 256, 28, 240, 16, en.hp / World.MAX_HP, COL.enemy, "ENEMY  " .. math.ceil(en.hp))

    love.graphics.setColor(0.7, 0.7, 0.75)
    love.graphics.printf(isHost and "HOST" or "CLIENT", 0, 6, AW, "center")

    -- 카운트다운
    if view.phase == "countdown" then
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", 0, 0, AW, AH)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(Font.get(150))
        love.graphics.printf(tostring(math.max(1, math.ceil(view.countdown))),
            0, AH / 2 - 120, AW, "center")
        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.setFont(Font.get(22))
        love.graphics.printf("WASD 이동 · 마우스 조준 · 좌클릭/스페이스 사격",
            0, AH / 2 + 80, AW, "center")
        love.graphics.setFont(Font.get(18))
    end

    -- 종료 배너
    if view.phase == "ended" then
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", 0, 0, AW, AH)
        local msg, col
        if view.winner == myId then        msg, col = "YOU WIN", COL.me
        elseif view.winner == 0 then        msg, col = "DRAW",    { 1, 1, 1 }
        else                                msg, col = "YOU LOSE", COL.enemy end
        love.graphics.setColor(col)
        love.graphics.setFont(Font.get(96))
        love.graphics.printf(msg, 0, AH / 2 - 90, AW, "center")
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.setFont(Font.get(22))
        local hint = isHost and "[R] 재대결    [ESC] 나가기" or "[ESC] 나가기 (호스트가 재대결을 시작할 수 있음)"
        love.graphics.printf(hint, 0, AH / 2 + 40, AW, "center")
        love.graphics.setFont(Font.get(18))
    end
end

return R
