local Constants = require("src.constants")
local MathUtils = require("src.utils.math_utils")
local mapData = require("map_data")

local CityMap = {}
CityMap.__index = CityMap

function CityMap.new()
    local self = setmetatable({}, CityMap)
    self.width = mapData.width
    self.height = mapData.height
    self.gridData = mapData

    -- Occupancy table: [y][x] = person
    self.occupancy = {}
    for y = 1, self.height do
        self.occupancy[y] = {}
    end

    self.people = {}
    self.player = nil

    -- Camera (viewport in tiles)
    self.camX = 1
    self.camY = 1
    self.targetCamX = 1
    self.targetCamY = 1

    -- Combat Arena Lock
    self.arenaLock = nil -- { minX, minY, maxX, maxY }

    return self
end

function CityMap:isWall(x, y)
    return self.gridData:isWall(x, y)
end

function CityMap:getPersonAt(x, y)
    if x < 1 or x > self.width or y < 1 or y > self.height then return nil end
    local p = self.occupancy[y][x]
    if p and p.alive then return p end
    return nil
end

function CityMap:setPersonAt(x, y, person)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        self.occupancy[y][x] = person
    end
end

function CityMap:clearPersonAt(x, y)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        self.occupancy[y][x] = nil
    end
end

function CityMap:movePerson(person, toX, toY)
    self:clearPersonAt(person.x, person.y)
    person.x = toX
    person.y = toY
    self:setPersonAt(toX, toY, person)
end

function CityMap:addPerson(person)
    table.insert(self.people, person)
    self:setPersonAt(person.x, person.y, person)
    if person.isPlayer then
        self.player = person
        self:centerCameraOn(person.x, person.y, true)
    end
end

function CityMap:removePerson(person)
    self:clearPersonAt(person.x, person.y)
    person.alive = false
end

function CityMap:centerCameraOn(targetX, targetY, instant)
    -- 15 tiles view: center is offset by 7 tiles
    local desiredX = MathUtils.clamp(targetX - math.floor(Constants.VIEW_TILES / 2), 1, self.width - Constants.VIEW_TILES + 1)
    local desiredY = MathUtils.clamp(targetY - math.floor(Constants.VIEW_TILES / 2), 1, self.height - Constants.VIEW_TILES + 1)

    self.targetCamX = desiredX
    self.targetCamY = desiredY

    if instant then
        self.camX = desiredX
        self.camY = desiredY
    end
end

function CityMap:updateCamera(dt)
    if self.arenaLock then
        -- Camera is strictly locked to arena during combat
        self.camX = self.arenaLock.minX
        self.camY = self.arenaLock.minY
        return
    end

    if self.player then
        self:centerCameraOn(self.player.x, self.player.y, false)
        local lerpSpeed = 10.0
        self.camX = MathUtils.lerp(self.camX, self.targetCamX, math.min(1.0, dt * lerpSpeed))
        self.camY = MathUtils.lerp(self.camY, self.targetCamY, math.min(1.0, dt * lerpSpeed))
    end
end

function CityMap:lockArena(camX, camY)
    local clampedX = math.floor(MathUtils.clamp(camX, 1, self.width - Constants.VIEW_TILES + 1))
    local clampedY = math.floor(MathUtils.clamp(camY, 1, self.height - Constants.VIEW_TILES + 1))
    self.camX = clampedX
    self.camY = clampedY
    self.arenaLock = {
        minX = clampedX,
        minY = clampedY,
        maxX = clampedX + Constants.VIEW_TILES - 1,
        maxY = clampedY + Constants.VIEW_TILES - 1
    }
end

function CityMap:unlockArena()
    self.arenaLock = nil
end

-- Find a random unoccupied street tile in a sector
function CityMap:getRandomWalkableTile(minX, minY, maxX, maxY)
    minX = math.max(1, minX or 1)
    minY = math.max(1, minY or 1)
    maxX = math.min(self.width, maxX or self.width)
    maxY = math.min(self.height, maxY or self.height)

    for attempts = 1, 1000 do
        local rx = math.random(minX, maxX)
        local ry = math.random(minY, maxY)
        if not self:isWall(rx, ry) and not self:getPersonAt(rx, ry) then
            return rx, ry
        end
    end
    return nil, nil
end

return CityMap
