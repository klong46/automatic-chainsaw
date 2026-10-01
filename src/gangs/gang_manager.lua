local MathUtils = require("src.utils.math_utils")
local Insignia = require("src.gangs.insignia")
local Constants = require("src.constants")

local GangManager = {}
GangManager.__index = GangManager

local PREFIX_TOKENS = {
    "Brun", "Kert", "Vand", "Morg", "Zor", "Reth", "Skal", "Drak",
    "Vor", "Geld", "Brak", "Gorn", "Thal", "Krag", "Veld", "Skarn",
    "Khor", "Grim", "Tor", "Mal", "Krell", "Brog", "Rond", "Harn",
    "Skar", "Zorn", "Vex", "Drog", "Gor", "Karn"
}

local MEDIAL_TOKENS = {
    "ker", "rok", "lan", "var", "mor", "ten", "gar", "dor",
    "zan", "kin", "ven", "tar", "mar", "den", "rin", "zen",
    "kas", "mon", "ber", "gath", "val", "cor", "sen", "drak"
}

local SUFFIX_TOKENS = {
    "ts", "ons", "ers", "iks", "ens", "ox", "ars", "ax",
    "ix", "or", "um", "eth", "ex", "ash", "ant", "ard",
    "os", "ians", "oids", "ites"
}

local function generateGangName()
    local p = MathUtils.pickRandom(PREFIX_TOKENS)
    local m = MathUtils.pickRandom(MEDIAL_TOKENS)
    local s = MathUtils.pickRandom(SUFFIX_TOKENS)
    return p .. m .. s
end

function GangManager.new()
    local self = setmetatable({}, GangManager)
    self.gangs = {}
    self:initGangs()
    return self
end

function GangManager:initGangs()
    self.gangs = {}

    -- 1. Base color picked randomly on the color wheel [0, 1)
    local baseHue = math.random()

    -- 2. Fixed attack type per gang
    local gangClasses = {
        Constants.CLASS_COWBOY,
        Constants.CLASS_SAMURAI,
        Constants.CLASS_HORSEMAN
    }

    local usedNames = {}

    for i = 1, 3 do
        -- Spaced 1/3 apart on the color wheel
        local hue = (baseHue + (i - 1) / 3.0) % 1.0
        local r, g, b = MathUtils.hsvToRgb(hue, 0.88, 0.95)

        -- Generate unique name
        local name
        repeat
            name = generateGangName()
        until not usedNames[name]
        usedNames[name] = true

        local gang = {
            id = i,
            name = name,
            class = gangClasses[i],
            color = { r, g, b },
            hue = hue,
            insignia = Insignia.new(),
            members = {},
            initialCount = 0,
            aliveCount = 0,
            defeated = false,
            playerReputation = 0, -- -100 to 100 (neutral at 0)
            temporaryAllyId = nil  -- can team up with another gang against the odd gang out
        }
        table.insert(self.gangs, gang)
    end
end

function GangManager:getGang(gangId)
    return self.gangs[gangId]
end

function GangManager:registerMember(gangId, person)
    local gang = self:getGang(gangId)
    if gang then
        table.insert(gang.members, person)
        gang.initialCount = gang.initialCount + 1
        gang.aliveCount = gang.aliveCount + 1
    end
end

function GangManager:onMemberKilled(person)
    if not person or not person.gangId then return end
    local gang = self:getGang(person.gangId)
    if gang and not gang.defeated then
        gang.aliveCount = math.max(0, gang.aliveCount - 1)
        if gang.aliveCount == 0 then
            gang.defeated = true
            return true, gang -- just defeated
        end
    end
    return false, gang
end

function GangManager:getActiveGangsCount()
    local count = 0
    for _, g in ipairs(self.gangs) do
        if not g.defeated then count = count + 1 end
    end
    return count
end

function GangManager:findRivalTarget(sponsorGangId)
    local candidates = {}
    for _, g in ipairs(self.gangs) do
        if g.id ~= sponsorGangId and not g.defeated then
            for _, m in ipairs(g.members) do
                if m.alive and not m.isPlayer then
                    table.insert(candidates, m)
                end
            end
        end
    end
    if #candidates > 0 then
        return candidates[math.random(1, #candidates)]
    end
    return nil
end

-- Evaluates diplomacy / teaming up against the leading or odd gang out
function GangManager:updateAlliances()
    local active = {}
    for _, g in ipairs(self.gangs) do
        if not g.defeated then
            table.insert(active, g)
        end
    end

    -- If all 3 are active, find the strongest gang and have the other two potentially align
    if #active == 3 then
        table.sort(active, function(a, b) return a.aliveCount > b.aliveCount end)
        local topGang = active[1]
        local weaker1 = active[2]
        local weaker2 = active[3]

        -- Weaker two may form temporary alliance against topGang
        weaker1.temporaryAllyId = weaker2.id
        weaker2.temporaryAllyId = weaker1.id
        topGang.temporaryAllyId = nil
    else
        for _, g in ipairs(self.gangs) do
            g.temporaryAllyId = nil
        end
    end
end

return GangManager
