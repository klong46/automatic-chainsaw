local Constants = require("src.constants")
local Moves = require("src.entities.moves")
local AIBrain = require("src.ai.ai_brain")

local CombatManager = {}
CombatManager.__index = CombatManager

function CombatManager.new(cityMap, gangManager)
    local self = setmetatable({}, CombatManager)
    self.cityMap = cityMap
    self.gangManager = gangManager

    self.active = false
    self.combatants = {}
    self.currentTurnIndex = 1
    self.turnNumber = 1
    self.combatLog = {}
    self.waitingForPlayer = false
    self.arenaLock = nil
    self.gameOver = false
    self.victory = false

    return self
end

function CombatManager:log(msg)
    table.insert(self.combatLog, 1, msg)
    if #self.combatLog > 25 then
        table.remove(self.combatLog)
    end
end

function CombatManager:startCombat(initiator, target)
    if self.active then return end

    -- Lock the current 15x15 screen
    local camX = math.floor(self.cityMap.camX)
    local camY = math.floor(self.cityMap.camY)
    self.cityMap:lockArena(camX, camY)
    self.arenaLock = self.cityMap.arenaLock
    self.active = true
    self.combatants = {}
    self.currentTurnIndex = 1
    self.turnNumber = 1

    -- Gather all living people inside the 15x15 locked arena
    for _, p in ipairs(self.cityMap.people) do
        if p.alive and
           p.x >= self.arenaLock.minX and p.x <= self.arenaLock.maxX and
           p.y >= self.arenaLock.minY and p.y <= self.arenaLock.maxY then
            table.insert(self.combatants, p)
        end
    end

    -- Sort turn queue: Player first, then others
    table.sort(self.combatants, function(a, b)
        if a.isPlayer then return true end
        if b.isPlayer then return false end
        return a.id < b.id
    end)

    self:log("[!] COMBAT ENGAGED! Arena locked (15x15)!")
    local initName = initiator and initiator.name or "Someone"
    local targName = target and target.name or "Someone"
    self:log(initName .. " clashed with " .. targName .. "!")

    self:startTurn()
end

function CombatManager:getCurrentTurnPerson()
    if not self.active or #self.combatants == 0 then return nil end
    return self.combatants[self.currentTurnIndex]
end

function CombatManager:startTurn()
    if not self.active then return end

    -- Check if combat has ended
    if self:checkCombatOver() then
        return
    end

    -- Clean up dead combatants
    local aliveCombatants = {}
    for _, c in ipairs(self.combatants) do
        if c.alive then
            table.insert(aliveCombatants, c)
        end
    end
    self.combatants = aliveCombatants

    if self.currentTurnIndex > #self.combatants then
        self.currentTurnIndex = 1
        self.turnNumber = self.turnNumber + 1
    end

    local current = self:getCurrentTurnPerson()
    if not current or not current.alive then
        self:nextTurn()
        return
    end

    if current.isPlayer then
        self.waitingForPlayer = true
    else
        self.waitingForPlayer = false
    end
end

function CombatManager:executePlayerAction(action)
    if not self.active or not self.waitingForPlayer then return false end
    local player = self.cityMap.player
    if not player or not player.alive then return false end

    self:performAction(player, action)
    self.waitingForPlayer = false
    self:nextTurn()
    return true
end

function CombatManager:updateAI(dt)
    if not self.active or self.waitingForPlayer then return end

    local person = self:getCurrentTurnPerson()
    if not person or not person.alive then
        self:nextTurn()
        return
    end

    -- Partition into allies and enemies
    local enemies = {}
    local allies = {}
    for _, other in ipairs(self.combatants) do
        if other.alive and other ~= person then
            if person.gangId and other.gangId == person.gangId then
                table.insert(allies, other)
            else
                table.insert(enemies, other)
            end
        end
    end

    local bestMove = AIBrain.findBestMove(person, enemies, allies, self.cityMap, self.arenaLock)
    if bestMove then
        self:performAction(person, bestMove)
    else
        self:log(person.name .. " holds position.")
    end

    self:nextTurn()
end

function CombatManager:performAction(person, action)
    -- 1. Execute movement if destination changed
    if action.moveX and action.moveY then
        if action.moveX ~= person.x or action.moveY ~= person.y then
            self.cityMap:movePerson(person, action.moveX, action.moveY)
        end
    end

    -- 2. Execute attack
    if action.shootDir then
        -- Cowboy shooting
        local ray = Moves.raycastBullet(self.cityMap, person.x, person.y, action.shootDir, self.arenaLock)
        person.attackEffect = {
            type = "shoot",
            timer = 0.28,
            path = ray.path,
            fromX = person.x,
            fromY = person.y,
            targetX = ray.x,
            targetY = ray.y
        }
        if ray.hitType == "person" and ray.target and ray.target.alive then
            self:log("[SHOT] " .. person.name .. " shot and eliminated " .. ray.target.name .. "!")
            self:killPerson(ray.target, person)
        elseif ray.hitType == "wall" then
            self:log("[MISS] " .. person.name .. "'s shot struck a building wall.")
        end
    elseif action.attackTarget then
        if action.isCapture then
            -- Horseman queen capture
            person.attackEffect = {
                type = "charge",
                timer = 0.28,
                fromX = action.fromX or person.x,
                fromY = action.fromY or person.y,
                targetX = action.moveX,
                targetY = action.moveY
            }
            self:log("[CHARGE] " .. person.name .. " captured and trampled " .. action.attackTarget.name .. "!")
            self:killPerson(action.attackTarget, person)
        else
            -- Samurai slash
            person.attackEffect = {
                type = "slash",
                timer = 0.25,
                targetX = action.attackTarget.x,
                targetY = action.attackTarget.y
            }
            self:log("[SLASH] " .. person.name .. " sliced down " .. action.attackTarget.name .. "!")
            self:killPerson(action.attackTarget, person)
        end
    else
        self:log(person.name .. " " .. (action.desc or "moved") .. ".")
    end
end

function CombatManager:killPerson(victim, killer)
    self.cityMap:removePerson(victim)

    -- Check Initiation Mission
    local player = self.cityMap.player
    if player and player.mission then
        if victim.id == player.mission.targetId or victim == player.mission.target then
            player.mission.completed = true
            if player.isInitiate then
                local sponsor = self.gangManager:getGang(player.mission.sponsorGangId)
                if sponsor then
                    player:joinGang(sponsor)
                    self:log("[INITIATION SUCCESS] " .. victim.name .. " eliminated! You are now a full member of " .. sponsor.name .. "!")
                end
            end
        end
    end

    if victim.isPlayer then
        self:log("[FATAL] YOU WERE ELIMINATED!")
        self.gameOver = true
    end

    local defeated, gang = self.gangManager:onMemberKilled(victim)
    if defeated and gang then
        self:log("[GANG WIPED OUT] " .. gang.name .. " has been completely defeated!")
    end
end

function CombatManager:nextTurn()
    self.currentTurnIndex = self.currentTurnIndex + 1
    self:startTurn()
end

function CombatManager:checkCombatOver()
    if not self.active then return true end

    -- Check if player is dead
    if self.cityMap.player and not self.cityMap.player.alive then
        self:endCombat("You fell in combat.")
        self.gameOver = true
        return true
    end

    -- Check factions alive in the arena
    local factionsAlive = {}
    local livingCount = 0

    for _, c in ipairs(self.combatants) do
        if c.alive then
            livingCount = livingCount + 1
            local fKey = c.isPlayer and ("player_" .. (c.gangId or 0)) or ("gang_" .. (c.gangId or 0))
            factionsAlive[fKey] = true
        end
    end

    local uniqueFactionCount = 0
    for _ in pairs(factionsAlive) do
        uniqueFactionCount = uniqueFactionCount + 1
    end

    -- Combat ends if 1 or 0 hostile factions remain
    if uniqueFactionCount <= 1 or livingCount <= 1 then
        self:endCombat("Combat resolved! Arena unlocked.")
        return true
    end

    return false
end

function CombatManager:endCombat(message)
    self.active = false
    self.cityMap:unlockArena()
    self.arenaLock = nil
    self.waitingForPlayer = false
    self:log("[ARENA OPEN] " .. message)
end

return CombatManager
