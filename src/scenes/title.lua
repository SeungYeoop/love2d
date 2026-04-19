local SM    = require("src.scenes.scene_manager")
local title = {}

function title.draw()
    local W, H = love.graphics.getDimensions()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("MY GAME", 0, H / 2 - 50, W, "center")
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf("SPACE  to start", 0, H / 2 + 10, W, "center")
    love.graphics.printf("ESC    to quit",  0, H / 2 + 35, W, "center")
end

function title.keypressed(key)
    if key == "space" then SM.switch("game") end
end

return title
