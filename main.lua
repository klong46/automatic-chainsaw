local Constants = require("src.constants")
local CityMap = require("src.world.city_map")
local GangManager = require("src.gangs.gang_manager")
local CombatManager = require("src.combat.combat_manager")
local DialogueManager = require("src.dialogue.dialogue_manager")
local Person = require("src.entities.person")
local Moves = require("src.entities.moves")
local AIBrain = require("src.ai.ai_brain")
local Renderer = require("src.ui.renderer")
local HUD = require("src.ui.hud")
local MathUtils = require("src.utils.math_utils")

local gameState = Constants.STATE_NAME_ENTRY
local enteredName = ""
local defaultNames = { "Drifter", "Vagrant", "Reno", "Ghost", "Stray", "Raven", "Nomad", "Clyde", "Vera" }
local cursorTimer = 0

local cityMap
local gangManager
local combatManager
local dialogueManager
local renderer
local hud

local player
local playerValidMoves = {}
local aiTurnTimer = 0
local AI_TURN_DELAY = 0.18

-- Ambush / Blindside Attack Mode outside of combat
local attackMode = false

-- Key repeat timer for rapid movement while holding keys
local keyRepeatTimer = 0
local keyRepeatInitialDelay = 0.16
local keyRepeatInterval = 0.07
local isKeyRepeating = false

function love.load()
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")
    gameState = Constants.STATE_NAME_ENTRY
    enteredName = defaultNames[math.random(1, #defaultNames)]
end

function startNewGame(playerName)
    if not playerName or playerName:match("^%s*$") then
        playerName = defaultNames[math.random(1, #defaultNames)]
    end

    attackMode = false
    keyRepeatTimer = 0
    isKeyRepeating = false

    cityMap = CityMap.new()
    gangManager = GangManager.new()
    combatManager = CombatManager.new(cityMap, gangManager)
    dialogueManager = DialogueManager.new(gangManager, combatManager)

    renderer = Renderer.new(cityMap, gangManager, combatManager)
    hud = HUD.new(cityMap, gangManager, combatManager, dialogueManager)

    spawnWorld(playerName)
    updatePlayerValidMoves()
    gameState = Constants.STATE_ROAM
end

function spawnWorld(playerName)
    -- 1. Spawn Player in a central street area
    local px, py = cityMap:getRandomWalkableTile(80, 80, 120, 120)
    if not px then px, py = cityMap:getRandomWalkableTile(1, 1, 200, 200) end

    player = Person.new({
        name = playerName,
        x = px,
        y = py,
        class = Constants.CLASS_NORMIE,
        gangId = nil,
        isPlayer = true
    })
    cityMap:addPerson(player)

    -- 2. Spawn 3 Gangs in distinct city sectors (~25 members each in 3-4 patrols of 5-8)
    local sectors = {
        { minX = 15, minY = 15, maxX = 75, maxY = 75 },   -- NW
        { minX = 125, minY = 15, maxX = 185, maxY = 75 },  -- NE
        { minX = 125, minY = 125, maxX = 185, maxY = 185 } -- SE
    }

    for gangId = 1, 3 do
        local gang = gangManager:getGang(gangId)
        local sec = sectors[gangId]
        local membersToSpawn = 25
        local patrolId = 1

        while membersToSpawn > 0 do
            local groupSize = math.min(membersToSpawn, math.random(6, 8))
            local lx, ly = cityMap:getRandomWalkableTile(sec.minX, sec.minY, sec.maxX, sec.maxY)
            if lx then
                for i = 1, groupSize do
                    local sx, sy = cityMap:getRandomWalkableTile(lx - 4, ly - 4, lx + 4, ly + 4)
                    if not sx then sx, sy = lx, ly end
                    if sx and not cityMap:getPersonAt(sx, sy) then
                        local member = Person.new({
                            class = gang.class,
                            gangId = gang.id,
                            x = sx,
                            y = sy,
                            patrolId = patrolId
                        })
                        cityMap:addPerson(member)
                        gangManager:registerMember(gang.id, member)
                        membersToSpawn = membersToSpawn - 1
                    end
                end
            end
            patrolId = patrolId + 1
        end
    end

    -- 3. Spawn Normies scattered in city streets (~25 normies)
    for i = 1, 25 do
        local nx, ny = cityMap:getRandomWalkableTile(20, 20, 180, 180)
        if nx and not cityMap:getPersonAt(nx, ny) then
            local normie = Person.new({
                class = Constants.CLASS_NORMIE,
                gangId = nil,
                x = nx,
                y = ny
            })
            cityMap:addPerson(normie)
        end
    end
end

function updatePlayerValidMoves()
    if not player or not player.alive then
        playerValidMoves = {}
        return
    end

    local arenaLock = combatManager.active and combatManager.arenaLock or nil
    playerValidMoves = Moves.getAvailableMoves(player, cityMap, arenaLock)
end

local function getHeldMovementVector()
    local dx, dy = 0, 0
    if love.keyboard.isDown("w", "up") then dy = dy - 1 end
    if love.keyboard.isDown("s", "down") then dy = dy + 1 end
    if love.keyboard.isDown("a", "left") then dx = dx - 1 end
    if love.keyboard.isDown("d", "right") then dx = dx + 1 end

    -- Check diagonal keys Q, E, Z, C
    if love.keyboard.isDown("q") then dx = -1; dy = -1 end
    if love.keyboard.isDown("e") then dx = 1; dy = -1 end
    if love.keyboard.isDown("z") then dx = -1; dy = 1 end
    if love.keyboard.isDown("c") then dx = 1; dy = 1 end

    if dx ~= 0 or dy ~= 0 then
        return dx, dy
    end
    return nil, nil
end

function love.update(dt)
    cursorTimer = cursorTimer + dt

    if gameState == Constants.STATE_NAME_ENTRY then
        return
    end

    cityMap:updateCamera(dt)
    renderer:update(dt)

    -- Update visual interpolation and animation timers for everyone
    for _, p in ipairs(cityMap.people) do
        if p.alive then
            p:update(dt)
        end
    end

    -- Rapid continuous movement when holding down movement keys in Roam mode
    if gameState == Constants.STATE_ROAM and not dialogueManager.active and not combatManager.active and not attackMode then
        local hx, hy = getHeldMovementVector()
        if hx and hy then
            keyRepeatTimer = keyRepeatTimer + dt
            local threshold = isKeyRepeating and keyRepeatInterval or keyRepeatInitialDelay
            if keyRepeatTimer >= threshold then
                keyRepeatTimer = 0
                isKeyRepeating = true
                tryMovePlayer(hx, hy)
            end
        else
            keyRepeatTimer = 0
            isKeyRepeating = false
        end
    else
        keyRepeatTimer = 0
        isKeyRepeating = false
    end

    -- Process AI turns in combat with pacing delay
    if combatManager.active then
        if not combatManager.waitingForPlayer then
            aiTurnTimer = aiTurnTimer + dt
            if aiTurnTimer >= AI_TURN_DELAY then
                aiTurnTimer = 0
                combatManager:updateAI(dt)
                updatePlayerValidMoves()
            end
        end
    end

    -- Check Game Over condition
    if (player and not player.alive) or combatManager.gameOver then
        gameState = Constants.STATE_GAMEOVER
        return
    end

    -- Check Victory condition
    if player and player.gangId and not player.isInitiate then
        local activeCount = gangManager:getActiveGangsCount()
        local playerGang = gangManager:getGang(player.gangId)
        if activeCount == 1 and playerGang and not playerGang.defeated then
            gameState = Constants.STATE_VICTORY
            return
        end
    end

    -- Update gang alliances
    gangManager:updateAlliances()
end

function love.draw()
    if gameState == Constants.STATE_NAME_ENTRY then
        drawNameEntryScreen()
        return
    end

    local inCombatTurn = (combatManager.active and combatManager.waitingForPlayer)
    renderer:draw(playerValidMoves, inCombatTurn, attackMode)
    hud:draw(attackMode)

    if gameState == Constants.STATE_GAMEOVER then
        drawGameOverOverlay()
    elseif gameState == Constants.STATE_VICTORY then
        drawVictoryOverlay()
    end
end

function drawNameEntryScreen()
    love.graphics.setColor(0.06, 0.07, 0.09, 1.0)
    love.graphics.rectangle("fill", 0, 0, Constants.WINDOW_WIDTH, Constants.WINDOW_HEIGHT)

    local cx = Constants.WINDOW_WIDTH / 2
    local cy = Constants.WINDOW_HEIGHT / 2

    love.graphics.setColor(0.12, 0.14, 0.18, 1.0)
    love.graphics.rectangle("fill", cx - 240, cy - 160, 480, 320, 8, 8)
    love.graphics.setColor(0.3, 0.35, 0.45, 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx - 240, cy - 160, 480, 320, 8, 8)

    love.graphics.setColor(1.0, 0.85, 0.2, 1.0)
    love.graphics.printf("G A N G S", cx - 200, cy - 130, 400, "center")
    love.graphics.setColor(0.7, 0.75, 0.85, 1.0)
    love.graphics.printf("Turn-Based City Warfare", cx - 200, cy - 105, 400, "center")

    love.graphics.setColor(0.9, 0.9, 0.9, 1.0)
    love.graphics.printf("ENTER YOUR CHARACTER NAME:", cx - 200, cy - 50, 400, "center")

    local boxW = 280
    local boxH = 40
    local boxX = cx - boxW / 2
    local boxY = cy - 20

    love.graphics.setColor(0.05, 0.06, 0.08, 1.0)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 4, 4)
    love.graphics.setColor(0.4, 0.6, 0.9, 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 4, 4)

    local showCursor = (cursorTimer % 0.8 < 0.4)
    local cursorStr = showCursor and "_" or " "
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(enteredName .. cursorStr, boxX + 10, boxY + 12, boxW - 20, "center")

    local btnY = cy + 45
    love.graphics.setColor(0.2, 0.5, 0.35, 1.0)
    love.graphics.rectangle("fill", cx - 90, btnY, 180, 38, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", cx - 90, btnY, 180, 38, 6, 6)
    love.graphics.printf("[ ENTER ] START GAME", cx - 90, btnY + 11, 180, "center")

    love.graphics.setColor(0.6, 0.65, 0.75, 1.0)
    love.graphics.printf("[TAB] Randomize Name    |    [BACKSPACE] Delete", cx - 200, cy + 105, 400, "center")
end

function drawGameOverOverlay()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, Constants.WINDOW_WIDTH, Constants.WINDOW_HEIGHT)

    local cx = Constants.WINDOW_WIDTH / 2
    local cy = Constants.WINDOW_HEIGHT / 2

    love.graphics.setColor(0.25, 0.06, 0.06, 0.95)
    love.graphics.rectangle("fill", cx - 220, cy - 110, 440, 220, 8, 8)
    love.graphics.setColor(1.0, 0.2, 0.2, 1.0)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", cx - 220, cy - 110, 440, 220, 8, 8)

    love.graphics.setColor(1.0, 0.2, 0.2, 1.0)
    love.graphics.printf("YOU HAVE BEEN ELIMINATED", cx - 200, cy - 80, 400, "center")

    love.graphics.setColor(0.9, 0.9, 0.9, 1.0)
    love.graphics.printf("The streets of the city showed no mercy.", cx - 200, cy - 50, 400, "center")

    local btnY = cy + 20
    love.graphics.setColor(0.6, 0.15, 0.15, 1.0)
    love.graphics.rectangle("fill", cx - 110, btnY, 220, 44, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx - 110, btnY, 220, 44, 6, 6)
    love.graphics.printf("[R] RESTART NEW GAME", cx - 110, btnY + 14, 220, "center")
end

function drawVictoryOverlay()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, Constants.WINDOW_WIDTH, Constants.WINDOW_HEIGHT)

    local cx = Constants.WINDOW_WIDTH / 2
    local cy = Constants.WINDOW_HEIGHT / 2

    love.graphics.setColor(0.08, 0.22, 0.12, 0.95)
    love.graphics.rectangle("fill", cx - 240, cy - 110, 480, 220, 8, 8)
    love.graphics.setColor(0.2, 0.9, 0.4, 1.0)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", cx - 240, cy - 110, 480, 220, 8, 8)

    love.graphics.setColor(1.0, 0.9, 0.2, 1.0)
    love.graphics.printf("CITY DOMINATION COMPLETE!", cx - 220, cy - 80, 440, "center")

    local playerGang = gangManager:getGang(player.gangId)
    local gName = playerGang and playerGang.name or "Your Gang"
    love.graphics.setColor(0.9, 0.95, 0.9, 1.0)
    love.graphics.printf(player.name .. " and the " .. gName .. " have conquered the entire city!", cx - 220, cy - 50, 440, "center")

    local btnY = cy + 20
    love.graphics.setColor(0.15, 0.55, 0.25, 1.0)
    love.graphics.rectangle("fill", cx - 110, btnY, 220, 44, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx - 110, btnY, 220, 44, 6, 6)
    love.graphics.printf("[R] PLAY AGAIN", cx - 110, btnY + 14, 220, "center")
end

-- Execute a player turn / step in the world
function stepWorld()
    if not combatManager.active then
        for _, p in ipairs(cityMap.people) do
            if p.alive and not p.isPlayer then
                AIBrain.updateRoamAction(p, cityMap, gangManager)
            end
        end
    end
    updatePlayerValidMoves()
end

function toggleAttackMode()
    if combatManager.active or dialogueManager.active then return end

    if player.class == Constants.CLASS_NORMIE and not player.isInitiate then
        combatManager:log("[NOTE] Normies cannot attack. Join a gang first!")
        attackMode = false
        return
    end

    attackMode = not attackMode
    updatePlayerValidMoves()
    if attackMode then
        combatManager:log("[AMBUSH] Blindside mode activated! Select target to strike.")
    else
        combatManager:log("[ROAM] Normal movement restored.")
    end
end

-- Execute blindside attack out of combat
function executeBlindsideAttack(action)
    local victim = nil
    if action.shootDir then
        local ray = Moves.raycastBullet(cityMap, action.moveX or player.x, action.moveY or player.y, action.shootDir, nil)
        if ray.hitType == "person" and ray.target and ray.target.alive then
            victim = ray.target
        end
    elseif action.attackTarget then
        victim = action.attackTarget
    end

    attackMode = false

    -- Start combat with the victim
    combatManager:startCombat(player, victim)

    -- Player strikes first immediately!
    combatManager:performAction(player, action)

    -- Advance turn to opponents
    combatManager.waitingForPlayer = false
    combatManager:nextTurn()
    updatePlayerValidMoves()
end

function tryMovePlayer(dx, dy)
    if not player or not player.alive then return end
    if dialogueManager.active then return end

    -- If in attack mode, directional key can be used to shoot for Cowboys or attack adjacent
    if attackMode then
        if player.class == Constants.CLASS_COWBOY then
            for _, m in ipairs(playerValidMoves) do
                if m.moveX == player.x and m.moveY == player.y and m.shootDir and m.shootDir.dx == dx and m.shootDir.dy == dy then
                    executeBlindsideAttack(m)
                    return
                end
            end
        end
        return
    end

    local targetX = player.x + dx
    local targetY = player.y + dy

    -- Check if combat arena restricts movement
    if combatManager.active and combatManager.arenaLock then
        local lock = combatManager.arenaLock
        if targetX < lock.minX or targetX > lock.maxX or targetY < lock.minY or targetY > lock.maxY then
            combatManager:log("Blocked! Arena boundary is sealed.")
            return
        end
    end

    local occupant = cityMap:getPersonAt(targetX, targetY)

    if combatManager.active then
        if not combatManager.waitingForPlayer then return end

        for _, m in ipairs(playerValidMoves) do
            if m.moveX == targetX and m.moveY == targetY and not m.shootDir then
                combatManager:executePlayerAction(m)
                updatePlayerValidMoves()
                return
            end
        end

        -- Horseman capture
        if player.class == Constants.CLASS_HORSEMAN and occupant and occupant ~= player then
            for _, m in ipairs(playerValidMoves) do
                if m.attackTarget == occupant and m.isCapture then
                    combatManager:executePlayerAction(m)
                    updatePlayerValidMoves()
                    return
                end
            end
        end

        -- Cowboy orthogonal shot without moving
        if player.class == Constants.CLASS_COWBOY then
            for _, m in ipairs(playerValidMoves) do
                if m.moveX == player.x and m.moveY == player.y and m.shootDir and m.shootDir.dx == dx and m.shootDir.dy == dy then
                    combatManager:executePlayerAction(m)
                    updatePlayerValidMoves()
                    return
                end
            end
        end

        combatManager:log("Invalid combat action.")
    else
        -- Roam mode
        if occupant then
            dialogueManager:startDialogue(player, occupant)
        elseif not cityMap:isWall(targetX, targetY) then
            cityMap:movePerson(player, targetX, targetY)
            stepWorld()
        end
    end
end

function love.textinput(text)
    if gameState == Constants.STATE_NAME_ENTRY then
        if #enteredName < 16 and text:match("[%w%s%._%-]") then
            enteredName = enteredName .. text
        end
    end
end

function love.keypressed(key)
    if gameState == Constants.STATE_NAME_ENTRY then
        if key == "return" or key == "kpenter" then
            startNewGame(enteredName)
        elseif key == "backspace" then
            enteredName = enteredName:sub(1, -2)
        elseif key == "tab" then
            enteredName = defaultNames[math.random(1, #defaultNames)]
        end
        return
    end

    if gameState == Constants.STATE_GAMEOVER or gameState == Constants.STATE_VICTORY then
        if key == "r" or key == "return" or key == "space" then
            gameState = Constants.STATE_NAME_ENTRY
        end
        return
    end

    -- Dialogue key selection
    if dialogueManager.active then
        if key == "1" then dialogueManager:selectOption(1)
        elseif key == "2" then dialogueManager:selectOption(2)
        elseif key == "3" then dialogueManager:selectOption(3)
        elseif key == "4" then dialogueManager:selectOption(4)
        elseif key == "escape" or key == "space" then dialogueManager:closeDialogue()
        end
        return
    end

    -- Ambush / Attack Mode Toggle key (F)
    if key == "f" then
        toggleAttackMode()
        return
    end

    if attackMode and key == "escape" then
        attackMode = false
        combatManager:log("[ROAM] Ambush cancelled.")
        return
    end

    -- Movement / Action keys
    if key == "up" or key == "w" then tryMovePlayer(0, -1)
    elseif key == "down" or key == "s" then tryMovePlayer(0, 1)
    elseif key == "left" or key == "a" then tryMovePlayer(-1, 0)
    elseif key == "right" or key == "d" then tryMovePlayer(1, 0)
    elseif key == "q" then tryMovePlayer(-1, -1)
    elseif key == "e" then tryMovePlayer(1, -1)
    elseif key == "z" then tryMovePlayer(-1, 1)
    elseif key == "c" then tryMovePlayer(1, 1)
    elseif key == "space" then
        if combatManager.active and combatManager.waitingForPlayer then
            combatManager:executePlayerAction({ moveX = player.x, moveY = player.y, desc = "waited" })
        else
            stepWorld()
        end
    elseif key == "r" then
        gameState = Constants.STATE_NAME_ENTRY
    end
end

function love.mousepressed(mx, my, button)
    if button ~= 1 then return end

    if gameState == Constants.STATE_NAME_ENTRY then
        local cx = Constants.WINDOW_WIDTH / 2
        local cy = Constants.WINDOW_HEIGHT / 2
        local btnY = cy + 45
        if mx >= cx - 90 and mx <= cx + 90 and my >= btnY and my <= btnY + 38 then
            startNewGame(enteredName)
        end
        return
    end

    if gameState == Constants.STATE_GAMEOVER or gameState == Constants.STATE_VICTORY then
        gameState = Constants.STATE_NAME_ENTRY
        return
    end

    -- Check HUD click
    local hudAction = hud:mousepressed(mx, my, button)
    if hudAction == "restart" then
        gameState = Constants.STATE_NAME_ENTRY
        return
    elseif hudAction == "toggle_ambush" then
        toggleAttackMode()
        return
    elseif hudAction == true then
        return
    end

    if dialogueManager.active then return end

    -- Check for direct character click under mouse
    local clickedPerson = renderer:getPersonUnderMouse(mx, my)

    -- 1. ATTACK MODE (Ambush blindside)
    if attackMode then
        -- Check if clicked on a valid attack option
        if clickedPerson and clickedPerson.alive and clickedPerson ~= player then
            for _, m in ipairs(playerValidMoves) do
                if m.attackTarget == clickedPerson then
                    executeBlindsideAttack(m)
                    return
                end
            end
        end

        local wx, wy = renderer:screenToWorld(mx, my)
        if wx and wy then
            -- Cowboy line of fire click
            if player.class == Constants.CLASS_COWBOY then
                for _, dir in ipairs(Constants.DIRS_4) do
                    local ray = Moves.raycastBullet(cityMap, player.x, player.y, dir, nil)
                    for _, pt in ipairs(ray.path) do
                        if pt.x == wx and pt.y == wy then
                            for _, m in ipairs(playerValidMoves) do
                                if m.moveX == player.x and m.moveY == player.y and m.shootDir and m.shootDir.dx == dir.dx and m.shootDir.dy == dir.dy then
                                    executeBlindsideAttack(m)
                                    return
                                end
                            end
                        end
                    end
                end
            end

            -- Click on any attack tile
            for _, m in ipairs(playerValidMoves) do
                if (m.attackTarget or m.shootDir) and m.moveX == wx and m.moveY == wy then
                    executeBlindsideAttack(m)
                    return
                end
            end
        end

        combatManager:log("[AMBUSH] Click a valid red target or line of fire, or [F] to cancel.")
        return
    end

    -- 2. COMBAT MODE
    if combatManager.active then
        if not combatManager.waitingForPlayer then return end

        if clickedPerson and clickedPerson.alive and clickedPerson ~= player then
            for _, m in ipairs(playerValidMoves) do
                if m.attackTarget == clickedPerson then
                    combatManager:executePlayerAction(m)
                    updatePlayerValidMoves()
                    return
                end
            end
        end

        local wx, wy = renderer:screenToWorld(mx, my)
        if not wx or not wy then return end

        for _, m in ipairs(playerValidMoves) do
            if m.moveX == wx and m.moveY == wy then
                combatManager:executePlayerAction(m)
                updatePlayerValidMoves()
                return
            end
        end

        -- Cowboy line of fire
        if player.class == Constants.CLASS_COWBOY then
            for _, dir in ipairs(Constants.DIRS_4) do
                local ray = Moves.raycastBullet(cityMap, player.x, player.y, dir, combatManager.arenaLock)
                for _, pt in ipairs(ray.path) do
                    if pt.x == wx and pt.y == wy then
                        for _, m in ipairs(playerValidMoves) do
                            if m.moveX == player.x and m.moveY == player.y and m.shootDir and m.shootDir.dx == dir.dx and m.shootDir.dy == dir.dy then
                                combatManager:executePlayerAction(m)
                                updatePlayerValidMoves()
                                return
                            end
                        end
                    end
                end
            end
        end
        return
    end

    -- 3. ROAM MODE
    -- If clicked directly on an NPC, talk to them immediately!
    if clickedPerson and clickedPerson.alive and clickedPerson ~= player then
        dialogueManager:startDialogue(player, clickedPerson)
        return
    end

    -- Otherwise, step 1 tile toward clicked world position
    local wx, wy = renderer:screenToWorld(mx, my)
    if wx and wy then
        local targetPerson = cityMap:getPersonAt(wx, wy)
        if targetPerson and targetPerson ~= player then
            dialogueManager:startDialogue(player, targetPerson)
        else
            local dx = MathUtils.clamp(wx - player.x, -1, 1)
            local dy = MathUtils.clamp(wy - player.y, -1, 1)
            tryMovePlayer(dx, dy)
        end
    end
end

function love.mousemoved(mx, my)
    if hud then
        hud:mousemoved(mx, my)
    end
end
