-- lobby.lua — 방 만들기(host) / 참가(join) 화면. 연결되면 game 씬으로 넘어간다.
local SM   = require("src.scenes.scene_manager")
local net  = require("src.net.net")
local Font = require("src.ui.font")
local lobby = {}

function lobby.enter(mode)
    lobby.mode    = mode or "host"
    lobby.status  = ""
    lobby.error   = nil
    lobby.timer   = 0

    if lobby.mode == "host" then
        local ok, err = net.startHost(net.PORT)
        if not ok then
            lobby.error = "방을 열 수 없습니다: " .. tostring(err)
        else
            lobby.ip = net.localIP()
        end
    else -- join
        lobby.ipInput   = "127.0.0.1"
        lobby.connecting = false
    end
end

function lobby.update(dt)
    lobby.timer = lobby.timer + dt
    for _, e in ipairs(net.poll()) do
        if e.type == "connect" then
            -- 호스트=플레이어1, 클라이언트=플레이어2
            SM.switch("game", { role = (lobby.mode == "host") and 1 or 2 })
            return
        elseif e.type == "disconnect" then
            if lobby.mode == "join" then
                lobby.connecting = false
                lobby.error = "접속 실패 또는 연결이 끊겼습니다."
            end
        end
    end

    -- 클라이언트 접속 타임아웃
    if lobby.mode == "join" and lobby.connecting and lobby.timer > 6 then
        lobby.connecting = false
        lobby.error = "응답이 없습니다. IP/포트와 호스트 상태를 확인하세요."
        net.close()
    end
end

function lobby.draw()
    local W, H = love.graphics.getDimensions()
    love.graphics.clear(0.10, 0.11, 0.13)
    love.graphics.setFont(Font.get(20))

    if lobby.mode == "host" then
        love.graphics.setColor(0.95, 0.95, 1)
        love.graphics.setFont(Font.get(36))
        love.graphics.printf("방을 열었습니다", 0, H / 2 - 140, W, "center")
        love.graphics.setFont(Font.get(20))
        love.graphics.setColor(0.45, 0.85, 1)
        love.graphics.printf("상대를 기다리는 중" .. string.rep(".", (math.floor(lobby.timer * 2) % 4)),
            0, H / 2 - 80, W, "center")

        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.printf("내 IP:  " .. tostring(lobby.ip), 0, H / 2 - 20, W, "center")
        love.graphics.printf("포트:  " .. net.PORT,            0, H / 2 + 10, W, "center")
        love.graphics.setColor(0.6, 0.6, 0.65)
        love.graphics.printf("이 IP를 상대에게 알려주세요. (같은 PC 테스트는 127.0.0.1)",
            0, H / 2 + 60, W, "center")
    else
        love.graphics.setColor(0.95, 0.95, 1)
        love.graphics.setFont(Font.get(36))
        love.graphics.printf("참가할 호스트 IP 입력", 0, H / 2 - 140, W, "center")

        love.graphics.setColor(0.15, 0.16, 0.2)
        love.graphics.rectangle("fill", W / 2 - 160, H / 2 - 50, 320, 44, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(Font.get(26))
        local caret = (math.floor(lobby.timer * 2) % 2 == 0) and "_" or " "
        love.graphics.printf(lobby.ipInput .. caret, W / 2 - 150, H / 2 - 44, 300, "left")
        love.graphics.setFont(Font.get(20))

        love.graphics.setColor(0.6, 0.6, 0.65)
        if lobby.connecting then
            love.graphics.printf("접속 중...", 0, H / 2 + 20, W, "center")
        else
            love.graphics.printf("[Enter] 접속    [ESC] 취소", 0, H / 2 + 20, W, "center")
        end
        love.graphics.printf("숫자와 '.' 입력 · [Backspace] 지우기", 0, H / 2 + 50, W, "center")
    end

    if lobby.error then
        love.graphics.setColor(1, 0.4, 0.4)
        love.graphics.printf(lobby.error, 0, H - 80, W, "center")
    end
    love.graphics.setColor(0.5, 0.5, 0.55)
    love.graphics.printf("[ESC] 타이틀로", 0, H - 40, W, "center")
end

function lobby.textinput(t)
    if lobby.mode == "join" and not lobby.connecting then
        if t:match("[%d%.]") then
            lobby.ipInput = (lobby.ipInput .. t):sub(1, 21)
        end
    end
end

function lobby.keypressed(key)
    if key == "escape" then
        net.close()
        SM.switch("title")
        return
    end
    if lobby.mode == "join" and not lobby.connecting then
        if key == "backspace" then
            lobby.ipInput = lobby.ipInput:sub(1, -2)
        elseif key == "return" or key == "kpenter" then
            lobby.error = nil
            local ok, err = net.join(lobby.ipInput, net.PORT)
            if not ok then
                lobby.error = "접속 시작 실패: " .. tostring(err)
            else
                lobby.connecting = true
                lobby.timer = 0
            end
        end
    end
end

return lobby
