function love.conf(t)
    t.window.title       = "My Game"
    t.window.width       = 800
    t.window.height      = 600
    t.window.vsync       = 1
    t.window.resizable   = false
    t.window.msaa        = 4
    t.console            = false   -- Windows 전용: 콘솔 창 숨김
end
