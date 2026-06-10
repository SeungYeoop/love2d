-- net.lua — LÖVE 내장 enet(UDP) 래퍼. 싱글톤으로 씬 사이에서 연결을 유지한다.
-- 호스트와 클라이언트 모두 "단일 상대 peer" 모델로 다룬다.
local enet = require("enet")

local net = {
    PORT      = 22122,
    role      = nil,    -- "host" | "client" | nil
    host      = nil,    -- enet host 객체
    peer      = nil,    -- 상대 peer (host=클라이언트, client=서버)
    connected = false,
}

-- 방 열기(호스트). 성공 시 true, 실패 시 (false, err).
function net.startHost(port)
    net.close()
    local ok, h = pcall(enet.host_create, "0.0.0.0:" .. (port or net.PORT))
    if not ok or not h then return false, tostring(h) end
    net.role, net.host, net.peer, net.connected = "host", h, nil, false
    return true
end

-- 접속(클라이언트). connect는 비동기 — 이후 poll에서 "connect" 이벤트를 기다린다.
function net.join(ip, port)
    net.close()
    local ok, h = pcall(enet.host_create)
    if not ok or not h then return false, tostring(h) end
    net.role, net.host, net.connected = "client", h, false
    local ok2, peer = pcall(function() return h:connect(ip .. ":" .. (port or net.PORT)) end)
    if not ok2 or not peer then
        net.close()
        return false, tostring(peer)
    end
    net.peer = peer
    return true
end

-- 들어온 이벤트를 모아 리스트로 반환: {type="connect"|"disconnect"|"receive", data=?}
function net.poll()
    local events = {}
    if not net.host then return events end
    local e = net.host:service(0)
    while e do
        if e.type == "connect" then
            net.peer, net.connected = e.peer, true
            events[#events + 1] = { type = "connect" }
        elseif e.type == "disconnect" then
            net.connected = false
            events[#events + 1] = { type = "disconnect" }
        elseif e.type == "receive" then
            events[#events + 1] = { type = "receive", data = e.data }
        end
        e = net.host:service(0)
    end
    return events
end

-- 상대에게 전송. 스냅샷/입력은 최신값만 의미 있으므로 기본은 unreliable.
function net.send(data, mode)
    if net.peer and net.connected then
        local ok = pcall(function() net.peer:send(data, 0, mode or "unreliable") end)
        return ok
    end
    return false
end

function net.isConnected() return net.connected end
function net.isHost()      return net.role == "host" end

function net.close()
    pcall(function()
        if net.peer then net.peer:disconnect() end
        if net.host then net.host:flush() end
    end)
    net.role, net.host, net.peer, net.connected = nil, nil, nil, false
end

-- 같은 네트워크에서 상대에게 알려줄 내 LAN IP (luasocket 트릭). 실패 시 안내 문자열.
function net.localIP()
    local ok, socket = pcall(require, "socket")
    if not ok then return "127.0.0.1" end
    local ip
    pcall(function()
        local udp = socket.udp()
        udp:setpeername("8.8.8.8", 80)
        ip = udp:getsockname()
        udp:close()
    end)
    return ip or "127.0.0.1"
end

return net
