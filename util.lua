function clamp(val, min, max)
    if (val < min) then
        return min
    end
    if (val > max) then
        return max
    end
    return val
end

function rounddown(val, multiple)
    return val - val % multiple
end

function roundup(val, multiple)
    return rounddown(val + multiple - 0.01, multiple)
end

function aabb(x0,y0,w0,h0,x1,y1,w1,h1)
    local r0 = x0 + w0
    local r1 = x1 + w1
    local b0 = y0 + h0
    local b1 = y1 + h1
    if (r0 < x1 or r1 < x0) then
        return false
    end
    if (b0 < y1 or b1 < y0) then
        return false
    end
    return true
end

function dist(x0,y0,x1,y1)
    return sqrt((x1-x0)*(x1-x0) + (y1-y0)*(y1-y0))
end

function vlen(v)
    return sqrt(v.x*v.x + v.y*v.y)
end