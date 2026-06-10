-- scene_manager.lua
-- 사용법: SM.register("name", require("src.scenes.name"))
--         SM.switch("name")
local SM = {}

local scenes  = {}
local current = nil

function SM.register(name, scene)
    scenes[name] = scene
end

function SM.switch(name, ...)
    if current and current.leave then current.leave() end
    current = assert(scenes[name], "unknown scene: " .. name)
    if current.enter then current.enter(...) end
end

function SM.current() return current end

-- LÖVE 콜백 전달
function SM.update(dt)              if current and current.update       then current.update(dt)         end end
function SM.draw()                  if current and current.draw         then current.draw()              end end
function SM.keypressed(k, s, r)     if current and current.keypressed   then current.keypressed(k,s,r)   end end
function SM.keyreleased(k, s)       if current and current.keyreleased  then current.keyreleased(k,s)    end end
function SM.textinput(t)            if current and current.textinput    then current.textinput(t)        end end
function SM.quit()                  if current and current.quit         then current.quit()              end end
function SM.mousepressed(x,y,b)     if current and current.mousepressed then current.mousepressed(x,y,b) end end
function SM.mousereleased(x,y,b)    if current and current.mousereleased then current.mousereleased(x,y,b) end end
function SM.mousemoved(x,y,dx,dy)   if current and current.mousemoved   then current.mousemoved(x,y,dx,dy) end end
function SM.wheelmoved(x,y)         if current and current.wheelmoved   then current.wheelmoved(x,y)     end end
function SM.resize(w,h)             if current and current.resize       then current.resize(w,h)         end end

return SM
