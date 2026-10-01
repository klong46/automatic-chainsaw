local Constants = require("src.constants")
local Personality = require("src.entities.personality")
local MathUtils = require("src.utils.math_utils")

local Person = {}
Person.__index = Person

local FIRST_NAMES = {
    "Jax", "Cole", "Reno", "Vance", "Kael", "Brant", "Silas", "Rowan",
    "Gage", "Marek", "Dax", "Jethro", "Orson", "Clyde", "Talon", "Bane",
    "Vera", "Nadia", "Sari", "Lyra", "Tessa", "Kira", "Roxie", "Maeve",
    "Juno", "Zara", "Faye", "Cleo", "Blythe", "Rhea", "Echo", "Cass"
}

local nextPersonId = 1

function Person.new(params)
    local self = setmetatable({}, Person)
    params = params or {}

    self.id = nextPersonId
    nextPersonId = nextPersonId + 1

    self.isPlayer = params.isPlayer or false
    self.name = params.name or (MathUtils.pickRandom(FIRST_NAMES) .. " " .. string.char(math.random(65, 90)) .. ".")
    self.x = params.x or 1
    self.y = params.y or 1
    self.drawX = self.x
    self.drawY = self.y

    self.class = params.class or Constants.CLASS_NORMIE
    self.gangId = params.gangId -- 1, 2, 3 or nil

    -- Player does NOT have AI personality traits; only NPCs have personality traits
    if self.isPlayer then
        self.personality = nil
        self.mission = nil       -- Active initiation / assassination mission
        self.isInitiate = false  -- True while completing initiation mission
    else
        self.personality = params.personality or Personality.getRandomTraits()
    end

    self.alive = true
    self.patrolId = params.patrolId

    -- Normie routine
    self.homeX = self.x
    self.homeY = self.y
    self.routineTimer = math.random(3, 8)

    -- Animation & FX
    self.attackEffect = nil
    self.flashTimer = 0

    return self
end

function Person:joinGang(gang)
    if not gang then return end
    self.gangId = gang.id
    self.class = gang.class
    self.isInitiate = false
    self.mission = nil
    self.flashTimer = 0.5
end

function Person:setInitiateTrial(gang, target)
    self.isInitiate = true
    self.trialGangId = gang.id
    self.class = gang.class -- Temporary access to weapons/class mechanics for the challenge
    self.mission = {
        sponsorGangId = gang.id,
        sponsorGangName = gang.name,
        targetId = target.id,
        targetName = target.name,
        targetGangId = target.gangId,
        targetClass = target.class,
        targetX = target.x,
        targetY = target.y,
        completed = false
    }
    self.flashTimer = 0.5
end

function Person:leaveGang()
    self.gangId = nil
    self.class = Constants.CLASS_NORMIE
    self.isInitiate = false
    self.mission = nil
    self.flashTimer = 0.5
end

function Person:update(dt)
    -- Smooth visual slide toward grid position
    local speed = 12.0
    self.drawX = MathUtils.lerp(self.drawX, self.x, math.min(1.0, dt * speed))
    self.drawY = MathUtils.lerp(self.drawY, self.y, math.min(1.0, dt * speed))

    if self.attackEffect then
        self.attackEffect.timer = self.attackEffect.timer - dt
        if self.attackEffect.timer <= 0 then
            self.attackEffect = nil
        end
    end

    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
    end
end

function Person:teleportTo(x, y)
    self.x = x
    self.y = y
    self.drawX = x
    self.drawY = y
end

return Person
