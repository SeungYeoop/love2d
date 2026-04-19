-- main.lua — 진입점. 씬 등록과 LÖVE 콜백 위임만 담당한다.
local SM = require("src.scenes.scene_manager")

SM.register("title", require("src.scenes.title"))
SM.register("game",  require("src.scenes.game"))

function love.load()
    math.randomseed(os.time())
    SM.switch("title")
end

function love.update(dt)            SM.update(dt)           end
function love.draw()                SM.draw()               end
function love.keypressed(k, s, r)
    if k == "escape" and SM.current() and SM.current() == require("src.scenes.title") then
        love.event.quit()
    end
    SM.keypressed(k, s, r)
end
function love.keyreleased(k, s)     SM.keyreleased(k, s)    end
function love.mousepressed(x,y,b)   SM.mousepressed(x,y,b)  end
function love.mousereleased(x,y,b)  SM.mousereleased(x,y,b) end
function love.mousemoved(x,y,dx,dy) SM.mousemoved(x,y,dx,dy)end
function love.wheelmoved(x,y)       SM.wheelmoved(x,y)      end
function love.resize(w,h)           SM.resize(w,h)          end
