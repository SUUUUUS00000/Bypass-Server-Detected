local e1 = getfenv
local r1 = e1().raknet
local t1 = typeof
local s1 = true

local function d1(v1)
    if t1(r1) ~= "table" or t1(r1.desync) ~= "function" then
        warn("raknet.desync - not supported")
        return
    end
    
    if v1 == nil then
        s1 = not s1
    else
        s1 = v1
    end
    
    r1.desync(s1)
end

d1(true)
