-- font.lua — 한글이 보이도록 맑은 고딕(malgun.ttf)을 크기별로 캐싱해 제공한다.
-- 폰트 파일이 없으면 LÖVE 기본 폰트로 안전하게 폴백한다(한글은 깨질 수 있음).
local Font = {}

local PATH  = "assets/fonts/malgun.ttf"
local HAS   = love.filesystem.getInfo(PATH) ~= nil
local cache = {}

function Font.get(size)
    size = size or 18
    if not cache[size] then
        if HAS then
            cache[size] = love.graphics.newFont(PATH, size)
        else
            cache[size] = love.graphics.newFont(size)
        end
    end
    return cache[size]
end

return Font
