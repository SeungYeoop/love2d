-- game.lua — 실제 대전. 호스트는 월드를 시뮬레이션하고, 클라이언트는 스냅샷을 렌더링한다.
local SM    = require("src.scenes.scene_manager")
local net   = require("src.net.net")
local proto = require("src.net.protocol")
local World = require("src.game.world")
local render = require("src.game.render")

local game = {}

local SNAP_INTERVAL  = 0.05   -- 호스트 스냅샷 전송 주기 (20/s)
local INPUT_INTERVAL = 0.033  -- 클라이언트 입력 전송 주기 (30/s)

function game.enter(args)
    game.role   = (args and args.role) or 1   -- 1=호스트, 2=클라이언트
    game.isHost = game.role == 1
    game.sendTimer = 0
    game.lost   = nil   -- 상대 연결 끊김 안내

    if game.isHost then
        game.world = World.new()
    else
        game.view = nil   -- 첫 스냅샷 도착 전
    end
end

-- 내 화면 위치(px,py)를 기준으로 로컬 입력을 만든다.
local function readInput(px, py)
    local kb = love.keyboard
    local dx = (kb.isDown("right", "d") and 1 or 0) - (kb.isDown("left", "a") and 1 or 0)
    local dy = (kb.isDown("down", "s")  and 1 or 0) - (kb.isDown("up", "w")   and 1 or 0)
    local mx, my = love.mouse.getPosition()
    local aim = math.atan2(my - py, mx - px)
    local shoot = love.mouse.isDown(1) or kb.isDown("space")
    return { dx = dx, dy = dy, aim = aim, shoot = shoot }
end

function game.update(dt)
    if game.isHost then
        local w = game.world
        -- 호스트 본인(=플레이어1) 입력
        local p1 = w.players[1]
        w.players[1].input = readInput(p1.x, p1.y)

        -- 네트워크 수신: 클라이언트 입력 / 연결 끊김
        for _, e in ipairs(net.poll()) do
            if e.type == "receive" then
                local inp = proto.decodeInput(e.data)
                if inp then w.players[2].input = inp end
            elseif e.type == "disconnect" then
                if w.phase ~= "ended" then World.forceWin(w, 1) end
                game.lost = "상대가 나갔습니다."
            end
        end

        World.update(w, dt)

        -- 스냅샷 전송
        game.sendTimer = game.sendTimer + dt
        if game.sendTimer >= SNAP_INTERVAL then
            game.sendTimer = game.sendTimer - SNAP_INTERVAL
            net.send(proto.encodeSnapshot(w))
        end
    else
        -- 클라이언트: 스냅샷 수신
        for _, e in ipairs(net.poll()) do
            if e.type == "receive" then
                local snap = proto.decodeSnapshot(e.data)
                if snap then game.view = snap end
            elseif e.type == "disconnect" then
                game.lost = "호스트와의 연결이 끊겼습니다."
            end
        end

        -- 입력 전송 (내 위치는 스냅샷의 플레이어2에서 가져온다)
        if game.view then
            local me = game.view.players[2]
            game.sendTimer = game.sendTimer + dt
            if game.sendTimer >= INPUT_INTERVAL then
                game.sendTimer = game.sendTimer - INPUT_INTERVAL
                net.send(proto.encodeInput(readInput(me.x, me.y)))
            end
        end
    end
end

function game.draw()
    local W, H = love.graphics.getDimensions()
    local view = game.isHost and game.world or game.view

    if not view then
        love.graphics.clear(0.10, 0.11, 0.13)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("호스트에 연결 중...", 0, H / 2 - 10, W, "center")
        return
    end

    render.draw(view, game.role, game.isHost)

    if game.lost then
        love.graphics.setColor(1, 0.85, 0.4)
        love.graphics.printf(game.lost .. "  [ESC] 나가기", 0, H - 50, W, "center")
    end
end

function game.keypressed(key)
    if key == "escape" then
        net.close()
        SM.switch("title")
    elseif key == "r" and game.isHost
        and game.world.phase == "ended" and not game.lost then
        game.world = World.new()  -- 재대결 — 클라이언트는 스냅샷으로 자동 동기화
    end
end

return game
