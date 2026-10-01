local Constants = require("src.constants")
local Moves = require("src.entities.moves")
local MathUtils = require("src.utils.math_utils")
local Personality = require("src.entities.personality")

local AIBrain = {}

-- Check if an enemy can hit a target square (x, y)
local function isTileThreatenedBy(enemy, tx, ty, cityMap, arenaLock)
    if not enemy or not enemy.alive then return false end

    if enemy.class == Constants.CLASS_COWBOY then
        -- Cowboys shoot orthogonal straight lines
        for _, dir in ipairs(Constants.DIRS_4) do
            local ray = Moves.raycastBullet(cityMap, enemy.x, enemy.y, dir, arenaLock)
            if ray.hitType == "person" and ray.x == tx and ray.y == ty then
                return true
            end
        end
    elseif enemy.class == Constants.CLASS_SAMURAI then
        -- Samurai can move orthogonally to any square with line of sight and attack adjacent
        for _, dir in ipairs(Constants.DIRS_4) do
            local curX, curY = enemy.x + dir.dx, enemy.y + dir.dy
            while true do
                if curX < 1 or curX > Constants.MAP_WIDTH or curY < 1 or curY > Constants.MAP_HEIGHT then break end
                if arenaLock and (curX < arenaLock.minX or curX > arenaLock.maxX or curY < arenaLock.minY or curY > arenaLock.maxY) then break end
                if cityMap:isWall(curX, curY) then break end
                
                -- Check if tx, ty is adjacent to (curX, curY)
                if MathUtils.chebyshevDist(curX, curY, tx, ty) <= 1 then
                    return true
                end

                local occ = cityMap:getPersonAt(curX, curY)
                if occ and occ.alive and occ ~= enemy then break end
                curX = curX + dir.dx
                curY = curY + dir.dy
            end
        end
    elseif enemy.class == Constants.CLASS_HORSEMAN then
        -- Horseman queen move to tx, ty
        local dx = tx - enemy.x
        local dy = ty - enemy.y
        local adx = math.abs(dx)
        local ady = math.abs(dy)
        if adx == 0 or ady == 0 or adx == ady then
            local stepX = (dx == 0) and 0 or (dx / adx)
            local stepY = (dy == 0) and 0 or (dy / ady)
            local curX, curY = enemy.x + stepX, enemy.y + stepY
            local clear = true
            while curX ~= tx or curY ~= ty do
                if cityMap:isWall(curX, curY) then clear = false; break end
                local occ = cityMap:getPersonAt(curX, curY)
                if occ and occ.alive and occ ~= enemy then clear = false; break end
                curX = curX + stepX
                curY = curY + stepY
            end
            if clear and not cityMap:isWall(tx, ty) then
                return true
            end
        end
    end
    return false
end

-- Checks if any enemy is currently threatening an ally
local function isAllyThreatened(ally, enemies, cityMap, arenaLock)
    for _, e in ipairs(enemies) do
        if isTileThreatenedBy(e, ally.x, ally.y, cityMap, arenaLock) then
            return true, e
        end
    end
    return false, nil
end

-- Evaluate a single move for a person
function AIBrain.evaluateMove(move, person, enemies, allies, cityMap, arenaLock)
    local score = 0
    local destX = move.moveX
    local destY = move.moveY

    -- 1. Check if this move eliminates an enemy
    local killedEnemy = nil
    if move.shootDir then
        local ray = Moves.raycastBullet(cityMap, destX, destY, move.shootDir, arenaLock)
        if ray.hitType == "person" and ray.target and ray.target.alive and ray.target.gangId ~= person.gangId then
            killedEnemy = ray.target
            score = score + 120
        end
    elseif move.attackTarget and move.attackTarget.alive and move.attackTarget.gangId ~= person.gangId then
        killedEnemy = move.attackTarget
        score = score + 120
    end

    -- 2. Heroic trait: if an enemy is threatening a gangmate, huge bonus to eliminating that enemy!
    if killedEnemy then
        for _, ally in ipairs(allies) do
            if ally ~= person and ally.alive then
                local threatened, threatEnemy = isAllyThreatened(ally, { killedEnemy }, cityMap, arenaLock)
                if threatened then
                    if Personality.hasTrait(person, "heroic") then
                        score = score + 160 -- Heroic self-sacrifice bonus!
                    else
                        score = score + 50
                    end
                end
            end
        end
    end

    -- 3. Danger evaluation: is destination tile exposed to enemy counter-attack?
    local threatened = false
    for _, e in ipairs(enemies) do
        if e ~= killedEnemy and isTileThreatenedBy(e, destX, destY, cityMap, arenaLock) then
            threatened = true
            break
        end
    end

    if threatened then
        if Personality.hasTrait(person, "selfish") then
            score = score - 160 -- Selfish units hate exposure
        elseif Personality.hasTrait(person, "heroic") and killedEnemy then
            score = score - 20  -- Heroic accepts danger if they got an enemy
        else
            score = score - 80
        end
    else
        if Personality.hasTrait(person, "selfish") then
            score = score + 40  -- Selfish loves safety
        end
    end

    -- 4. Personality-driven positioning
    -- Distance to nearest enemy
    local nearestDist = 999
    for _, e in ipairs(enemies) do
        if e.alive and e ~= killedEnemy then
            local d = MathUtils.dist(destX, destY, e.x, e.y)
            if d < nearestDist then nearestDist = d end
        end
    end

    if Personality.hasTrait(person, "combative") then
        score = score + math.max(0, 30 - nearestDist * 3) -- bonus for closing in
    elseif Personality.hasTrait(person, "peaceful") then
        score = score + math.min(30, nearestDist * 3)    -- bonus for keeping distance
    end

    if Personality.hasTrait(person, "proud") then
        -- Proud hates running away
        local currentDist = 999
        for _, e in ipairs(enemies) do
            if e.alive then
                local d = MathUtils.dist(person.x, person.y, e.x, e.y)
                if d < currentDist then currentDist = d end
            end
        end
        if nearestDist > currentDist then
            score = score - 35 -- penalty for retreating
        end
    end

    if Personality.hasTrait(person, "intelligent") then
        -- Intelligent values cover: check if adjacent to a wall
        local hasWallCover = false
        for _, d in ipairs(Constants.DIRS_4) do
            if cityMap:isWall(destX + d.dx, destY + d.dy) then
                hasWallCover = true
                break
            end
        end
        if hasWallCover then
            score = score + 25
        end
    end

    return score
end

-- 2-Ply Lookahead Beam Search (Pick top 3 moves, then top 3 counter-moves)
function AIBrain.findBestMove(person, enemies, allies, cityMap, arenaLock)
    local allMoves = Moves.getAvailableMoves(person, cityMap, arenaLock)
    if #allMoves == 0 then return nil end

    -- Score all Ply 1 moves
    local scoredPly1 = {}
    for _, move in ipairs(allMoves) do
        local s = AIBrain.evaluateMove(move, person, enemies, allies, cityMap, arenaLock)
        table.insert(scoredPly1, { move = move, score = s })
    end

    -- Sort descending
    table.sort(scoredPly1, function(a, b) return a.score > b.score end)

    -- Take top 3
    local top3 = {}
    for i = 1, math.min(3, #scoredPly1) do
        table.insert(top3, scoredPly1[i])
    end

    -- Ply 2: For each of the top 3, evaluate the opponent's best counter-moves
    local bestFinalScore = -math.huge
    local chosenMove = top3[1].move

    for _, candidate in ipairs(top3) do
        local m = candidate.move
        local baseScore = candidate.score

        -- Find the primary enemy who would counter-attack
        local worstCounter = 0
        local closestEnemy = nil
        local minDist = 999
        for _, e in ipairs(enemies) do
            if e.alive and e ~= m.attackTarget then
                local d = MathUtils.dist(m.moveX, m.moveY, e.x, e.y)
                if d < minDist then
                    minDist = d
                    closestEnemy = e
                end
            end
        end

        if closestEnemy then
            local enemyMoves = Moves.getAvailableMoves(closestEnemy, cityMap, arenaLock)
            local scoredEnemyMoves = {}
            for _, em in ipairs(enemyMoves) do
                -- From enemy's perspective, person is an enemy
                local es = AIBrain.evaluateMove(em, closestEnemy, { person }, enemies, cityMap, arenaLock)
                table.insert(scoredEnemyMoves, es)
            end
            table.sort(scoredEnemyMoves, function(a, b) return a > b end)

            -- Average of top 3 counter-moves
            local counterSum = 0
            local count = math.min(3, #scoredEnemyMoves)
            for j = 1, count do
                counterSum = counterSum + scoredEnemyMoves[j]
            end
            if count > 0 then
                worstCounter = counterSum / count
            end
        end

        local finalScore = baseScore - (0.6 * worstCounter)
        if finalScore > bestFinalScore then
            bestFinalScore = finalScore
            chosenMove = m
        end
    end

    return chosenMove
end

-- Non-combat roaming behavior (patrols stay together, normies wander)
function AIBrain.updateRoamAction(person, cityMap, gangManager)
    if not person.alive then return end

    if person.class == Constants.CLASS_NORMIE then
        -- Normies wander casually around their area
        if math.random() < 0.35 then
            local dir = MathUtils.pickRandom(Constants.DIRS_8)
            local nx, ny = person.x + dir.dx, person.y + dir.dy
            if not cityMap:isWall(nx, ny) and not cityMap:getPersonAt(nx, ny) then
                -- Keep near home
                if MathUtils.dist(nx, ny, person.homeX, person.homeY) < 12 then
                    cityMap:movePerson(person, nx, ny)
                end
            end
        end
        return
    end

    -- Gang member roaming
    -- Move in direction of patrol or wander along streets
    if math.random() < 0.45 then
        local dir = MathUtils.pickRandom(Constants.DIRS_8)
        local nx, ny = person.x + dir.dx, person.y + dir.dy
        if not cityMap:isWall(nx, ny) and not cityMap:getPersonAt(nx, ny) then
            cityMap:movePerson(person, nx, ny)
        end
    end
end

return AIBrain
