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