local SM    = require("src.scenes.scene_manager")
local Font  = require("src.ui.font")
local title = {}

function title.draw()
    local W, H = love.graphics.getDimensions()
    love.graphics.clear(0.10, 0.11, 0.13)

    love.graphics.setColor(0.95, 0.95, 1)
    love.graphics.setFont(Font.get(56))
    love.graphics.printf("TOP-DOWN BATTLE", 0, H / 2 - 200, W, "center")
    love.graphics.setColor(0.45, 0.85, 1)
    love.graphics.setFont(Font.get(28))
    love.graphics.printf("1 vs 1  ·  온라인", 0, H / 2 - 130, W, "center")

    love.graphics.setFont(Font.get(20))
    love.graphics.setColor(0.85, 0.85, 0.9)
    love.graphics.printf("[H]  방 만들기 (호스트)",   0, H / 2 - 30, W, "center")
    love.graphics.printf("[J]  방에 참가하기 (클라이언트)", 0, H / 2,      W, "center")
    love.graphics.printf("[ESC]  종료",               0, H / 2 + 30, W, "center")

    love.graphics.setColor(0.5, 0.5, 0.55)
    love.graphics.printf("같은 네트워크(LAN)에서 한 명이 방을 만들고, 다른 한 명이 그 IP로 참가하세요.",
        0, H - 60, W, "center")
end

function title.keypressed(key)
    if     key == "h"      then SM.switch("lobby", "host")
    elseif key == "j"      then SM.switch("lobby", "join")
    elseif key == "escape" then love.event.quit() end
end

return title
