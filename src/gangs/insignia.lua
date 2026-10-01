local Insignia = {}
Insignia.__index = Insignia

-- Helper generators for basic polygon shapes centered around (ox, oy) with radius r
local function generateStar(ox, oy, r, points, innerRatio, rot)
    local verts = {}
    points = points or 5
    innerRatio = innerRatio or 0.45
    rot = rot or 0
    local step = math.pi / points
    for i = 0, (points * 2) - 1 do
        local rad = (i % 2 == 0) and r or (r * innerRatio)
        local angle = rot + i * step
        table.insert(verts, ox + math.cos(angle) * rad)
        table.insert(verts, oy + math.sin(angle) * rad)
    end
    return verts
end

local function generateRegularPolygon(ox, oy, r, sides, rot)
    local verts = {}
    sides = sides or 4
    rot = rot or 0
    local step = (math.pi * 2) / sides
    for i = 0, sides - 1 do
        local angle = rot + i * step
        table.insert(verts, ox + math.cos(angle) * r)
        table.insert(verts, oy + math.sin(angle) * r)
    end
    return verts
end

local function generateCross(ox, oy, w, h)
    local hw = w / 2
    local hh = h / 2
    local tw = w / 6
    local th = h / 6
    return {
        ox - tw, oy - hh,
        ox + tw, oy - hh,
        ox + tw, oy - th,
        ox + hw, oy - th,
        ox + hw, oy + th,
        ox + tw, oy + th,
        ox + tw, oy + hh,
        ox - tw, oy + hh,
        ox - tw, oy + th,
        ox - hw, oy + th,
        ox - hw, oy - th,
        ox - tw, oy - th
    }
end

local function generateChevron(ox, oy, w, h, thickness)
    thickness = thickness or (h * 0.3)
    return {
        ox, oy - h/2,
        ox + w/2, oy + h/2 - thickness,
        ox + w/2, oy + h/2,
        ox, oy - h/2 + thickness,
        ox - w/2, oy + h/2,
        ox - w/2, oy + h/2 - thickness
    }
end

function Insignia.new()
    local self = setmetatable({}, Insignia)
    self.polygons = {}
    
    local numShapes = math.random(3, 4)
    local shapeTypes = { "triangle", "diamond", "star", "pentagon", "hexagon", "cross", "chevron" }

    for i = 1, numShapes do
        local sType = shapeTypes[math.random(1, #shapeTypes)]
        local ox = (math.random() - 0.5) * 0.4
        local oy = (math.random() - 0.5) * 0.4
        local r = 0.3 + math.random() * 0.45
        local rot = math.random() * math.pi * 2
        local verts = {}

        if sType == "triangle" then
            verts = generateRegularPolygon(ox, oy, r, 3, rot)
        elseif sType == "diamond" then
            verts = generateRegularPolygon(ox, oy, r, 4, rot)
        elseif sType == "pentagon" then
            verts = generateRegularPolygon(ox, oy, r, 5, rot)
        elseif sType == "hexagon" then
            verts = generateRegularPolygon(ox, oy, r, 6, rot)
        elseif sType == "star" then
            verts = generateStar(ox, oy, r, math.random(4, 6), 0.4, rot)
        elseif sType == "cross" then
            verts = generateCross(ox, oy, r * 1.5, r * 1.5)
        elseif sType == "chevron" then
            verts = generateChevron(ox, oy, r * 1.6, r * 1.2, r * 0.35)
        end

        local drawMode = (math.random() < 0.65) and "fill" or "line"
        table.insert(self.polygons, {
            verts = verts,
            mode = drawMode,
            lineWidth = math.random(2, 3)
        })
    end

    return self
end

function Insignia:draw(cx, cy, radius, gangColor)
    -- Background shield / circle with gang color
    love.graphics.setColor(gangColor[1], gangColor[2], gangColor[3], 1.0)
    love.graphics.circle("fill", cx, cy, radius)

    -- Border ring
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, radius)

    -- Draw the 3-4 white polygons
    for _, poly in ipairs(self.polygons) do
        local transformed = {}
        for j = 1, #poly.verts, 2 do
            local vx = poly.verts[j]
            local vy = poly.verts[j + 1]
            table.insert(transformed, cx + vx * radius)
            table.insert(transformed, cy + vy * radius)
        end
        if #transformed >= 6 then
            love.graphics.setColor(1, 1, 1, 0.95)
            if poly.mode == "line" then
                love.graphics.setLineWidth(poly.lineWidth)
                love.graphics.polygon("line", transformed)
            else
                love.graphics.polygon("fill", transformed)
            end
        end
    end
end

return Insignia
