-- 2D 벡터 유틸
-- 사용: local V = require("src.utils.vector")
--       local v = V(3, 4)   →  v:length() == 5
local V = {}
V.__index = V

setmetatable(V, { __call = function(_, x, y) return V.new(x, y) end })

function V.new(x, y)     return setmetatable({ x = x or 0, y = y or 0 }, V) end

function V:__add(o)      return V.new(self.x + o.x,  self.y + o.y)  end
function V:__sub(o)      return V.new(self.x - o.x,  self.y - o.y)  end
function V:__mul(s)      return V.new(self.x * s,     self.y * s)    end
function V:__div(s)      return V.new(self.x / s,     self.y / s)    end
function V:__unm()       return V.new(-self.x,        -self.y)       end
function V:__eq(o)       return self.x == o.x and self.y == o.y      end
function V:__tostring()  return "(" .. self.x .. ", " .. self.y .. ")" end

function V:length()      return math.sqrt(self.x^2 + self.y^2)      end
function V:lengthSq()    return self.x^2 + self.y^2                  end
function V:dist(o)       return (self - o):length()                  end
function V:dot(o)        return self.x*o.x + self.y*o.y              end
function V:cross(o)      return self.x*o.y - self.y*o.x              end
function V:angle()       return math.atan2(self.y, self.x)           end
function V:clone()       return V.new(self.x, self.y)                end

function V:normalize()
    local l = self:length()
    return l > 0 and (self / l) or V.new(0, 0)
end

function V:lerp(o, t)
    return V.new(self.x + (o.x - self.x) * t,
                 self.y + (o.y - self.y) * t)
end

function V.fromAngle(a, len)
    len = len or 1
    return V.new(math.cos(a) * len, math.sin(a) * len)
end

return V
