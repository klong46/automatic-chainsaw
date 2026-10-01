local MathUtils = {}

function MathUtils.clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

function MathUtils.dist(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function MathUtils.chebyshevDist(x1, y1, x2, y2)
    return math.max(math.abs(x2 - x1), math.abs(y2 - y1))
end

function MathUtils.manhattanDist(x1, y1, x2, y2)
    return math.abs(x2 - x1) + math.abs(y2 - y1)
end

-- Convert HSV (h in [0, 1], s in [0, 1], v in [0, 1]) to RGB [0, 1]
function MathUtils.hsvToRgb(h, s, v)
    if s <= 0 then
        return v, v, v
    end
    h = (h % 1.0) * 6.0
    local i = math.floor(h)
    local f = h - i
    local p = v * (1.0 - s)
    local q = v * (1.0 - s * f)
    local t = v * (1.0 - s * (1.0 - f))
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q
    end
end

function MathUtils.pickRandom(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[math.random(1, #tbl)]
end

function MathUtils.shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

function MathUtils.lerp(a, b, t)
    return a + (b - a) * t
end

return MathUtils
