local SM   = require("src.scenes.scene_manager")
local game = {}

local SPEED      = 250
local PLAYER_R   = 20
local STAR_R     = 12
local CATCH_DIST = PLAYER_R + STAR_R

local function spawnStar()
    local W, H = love.graphics.getDimensions()
    game.sx = math.random(STAR_R + 10, W - STAR_R - 10)
    game.sy = math.random(STAR_R + 10, H - STAR_R - 10)
end

function game.enter()
    local W, H = love.graphics.getDimensions()
    game.x, game.y = W / 2, H / 2
    game.score     = 0
    spawnStar()
end

function game.update(dt)
    local W, H = love.graphics.getDimensions()

    if love.keyboard.isDown("right", "d") then game.x = game.x + SPEED * dt end
    if love.keyboard.isDown("left",  "a") then game.x = game.x - SPEED * dt end
    if love.keyboard.isDown("down",  "s") then game.y = game.y + SPEED * dt end
    if love.keyboard.isDown("up",    "w") then game.y = game.y - SPEED * dt end

    -- 경계 클램프
    game.x = math.max(PLAYER_R, math.min(W - PLAYER_R, game.x))
    game.y = math.max(PLAYER_R, math.min(H - PLAYER_R, game.y))

    -- 별 획득
    local dx, dy = game.x - game.sx, game.y - game.sy
    if math.sqrt(dx * dx + dy * dy) < CATCH_DIST then
        game.score = game.score + 1
        spawnStar()
    end
end

function game.draw()
    -- 별
    love.graphics.setColor(1, 1, 0)
    love.graphics.circle("fill", game.sx, game.sy, STAR_R)

    -- 플레이어
    love.graphics.setColor(0.3, 0.7, 1)
    love.graphics.circle("fill", game.x, game.y, PLAYER_R)

    -- HUD
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Score: " .. game.score, 10, 10)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("WASD / Arrows  |  R: restart  |  ESC: title", 10, 30)
end

function game.keypressed(key)
    if key == "r"      then game.enter()         end
    if key == "escape" then SM.switch("title")   end
end

return game
