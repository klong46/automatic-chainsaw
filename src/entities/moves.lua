local Constants = require("src.constants")

local Moves = {}

-- Helper to check if a tile is walkable and inside bounds (and within locked arena if active)
local function isTileWalkable(cityMap, x, y, arenaLock)
    if x < 1 or x > Constants.MAP_WIDTH or y < 1 or y > Constants.MAP_HEIGHT then
        return false
    end
    if arenaLock then
        if x < arenaLock.minX or x > arenaLock.maxX or y < arenaLock.minY or y > arenaLock.maxY then
            return false
        end
    end
    if cityMap:isWall(x, y) then
        return false
    end
    return true
end

-- Helper to raycast bullet for cowboy
function Moves.raycastBullet(cityMap, fromX, fromY, dir, arenaLock)
    local curX, curY = fromX + dir.dx, fromY + dir.dy
    local path = {}

    while true do
        if curX < 1 or curX > Constants.MAP_WIDTH or curY < 1 or curY > Constants.MAP_HEIGHT then
            break
        end
        if arenaLock then
            if curX < arenaLock.minX or curX > arenaLock.maxX or curY < arenaLock.minY or curY > arenaLock.maxY then
                break
            end
        end

        table.insert(path, { x = curX, y = curY })

        -- Check wall
        if cityMap:isWall(curX, curY) then
            return {
                hitType = "wall",
                x = curX,
                y = curY,
                path = path
            }
        end

        -- Check person
        local person = cityMap:getPersonAt(curX, curY)
        if person and person.alive then
            return {
                hitType = "person",
                target = person,
                x = curX,
                y = curY,
                path = path
            }
        end

        curX = curX + dir.dx
        curY = curY + dir.dy
    end

    return {
        hitType = "edge",
        x = curX - dir.dx,
        y = curY - dir.dy,
        path = path
    }
end

-- ==================== COWBOY ====================
-- Move 1 square (8 directions) or stay.
-- Shoot orthogonal (4 directions) or not shoot.
function Moves.getCowboyMoves(person, cityMap, arenaLock)
    local options = {}

    -- Possible move destinations: current pos + 8 adjacent directions
    local moveDests = { { x = person.x, y = person.y, moved = false } }
    for _, dir in ipairs(Constants.DIRS_8) do
        local nx, ny = person.x + dir.dx, person.y + dir.dy
        if isTileWalkable(cityMap, nx, ny, arenaLock) and not cityMap:getPersonAt(nx, ny) then
            table.insert(moveDests, { x = nx, y = ny, moved = true })
        end
    end

    -- For each move destination, can choose: no shoot, or shoot in 1 of 4 orthogonal directions
    for _, m in ipairs(moveDests) do
        -- Option: move only (no shoot)
        if m.moved then
            table.insert(options, {
                type = "cowboy_action",
                moveX = m.x,
                moveY = m.y,
                shootDir = nil,
                desc = "Move"
            })
        end

        -- Option: shoot from m.x, m.y
        for _, sDir in ipairs(Constants.DIRS_4) do
            table.insert(options, {
                type = "cowboy_action",
                moveX = m.x,
                moveY = m.y,
                shootDir = sDir,
                desc = m.moved and ("Move & Shoot " .. sDir.name) or ("Shoot " .. sDir.name)
            })
        end
    end

    return options
end

-- ==================== SAMURAI ====================
-- Move unlimited squares orthogonally (4 directions).
-- Attack any enemy adjacent (8 directions) from stop position.
function Moves.getSamuraiMoves(person, cityMap, arenaLock)
    local options = {}

    -- Determine all reachable stop positions (including staying put)
    local stopPositions = { { x = person.x, y = person.y, moved = false } }

    for _, dir in ipairs(Constants.DIRS_4) do
        local curX, curY = person.x + dir.dx, person.y + dir.dy
        while isTileWalkable(cityMap, curX, curY, arenaLock) do
            local occ = cityMap:getPersonAt(curX, curY)
            if occ and occ.alive then
                -- Blocked by someone, cannot occupy or jump over
                break
            end
            table.insert(stopPositions, { x = curX, y = curY, moved = true })
            curX = curX + dir.dx
            curY = curY + dir.dy
        end
    end

    -- From each stop position, can choose: no attack, or attack adjacent enemy
    for _, sp in ipairs(stopPositions) do
        -- Move only
        if sp.moved then
            table.insert(options, {
                type = "samurai_action",
                moveX = sp.x,
                moveY = sp.y,
                attackTarget = nil,
                desc = "Move"
            })
        end

        -- Look for adjacent enemies around sp
        for _, aDir in ipairs(Constants.DIRS_8) do
            local ax, ay = sp.x + aDir.dx, sp.y + aDir.dy
            local target = cityMap:getPersonAt(ax, ay)
            if target and target.alive and target ~= person then
                -- In combat, only attack opposing gang / enemy
                table.insert(options, {
                    type = "samurai_action",
                    moveX = sp.x,
                    moveY = sp.y,
                    attackTarget = target,
                    attackX = ax,
                    attackY = ay,
                    desc = sp.moved and "Move & Slash" or "Slash"
                })
            end
        end
    end

    return options
end

-- ==================== HORSEMAN ====================
-- Exactly like a queen in chess (8 directions, unlimited distance).
-- Attacks by occupying the enemy's square, killing them.
function Moves.getHorsemanMoves(person, cityMap, arenaLock)
    local options = {}

    for _, dir in ipairs(Constants.DIRS_8) do
        local curX, curY = person.x + dir.dx, person.y + dir.dy
        while isTileWalkable(cityMap, curX, curY, arenaLock) do
            local occ = cityMap:getPersonAt(curX, curY)
            if occ and occ.alive then
                if occ ~= person then
                    -- Attack by occupying enemy square!
                    table.insert(options, {
                        type = "horseman_action",
                        moveX = curX,
                        moveY = curY,
                        attackTarget = occ,
                        isCapture = true,
                        desc = "Charge & Capture"
                    })
                end
                break -- Ray blocked by person
            else
                -- Empty tile move
                table.insert(options, {
                    type = "horseman_action",
                    moveX = curX,
                    moveY = curY,
                    attackTarget = nil,
                    isCapture = false,
                    desc = "Queen Move"
                })
            end
            curX = curX + dir.dx
            curY = curY + dir.dy
        end
    end

    return options
end

-- ==================== NORMIE ====================
-- Move 1 square (8 directions) or stay. Cannot attack.
function Moves.getNormieMoves(person, cityMap, arenaLock)
    local options = {}

    for _, dir in ipairs(Constants.DIRS_8) do
        local nx, ny = person.x + dir.dx, person.y + dir.dy
        if isTileWalkable(cityMap, nx, ny, arenaLock) and not cityMap:getPersonAt(nx, ny) then
            table.insert(options, {
                type = "normie_action",
                moveX = nx,
                moveY = ny,
                attackTarget = nil,
                desc = "Walk"
            })
        end
    end

    return options
end

function Moves.getAvailableMoves(person, cityMap, arenaLock)
    if person.class == Constants.CLASS_COWBOY then
        return Moves.getCowboyMoves(person, cityMap, arenaLock)
    elseif person.class == Constants.CLASS_SAMURAI then
        return Moves.getSamuraiMoves(person, cityMap, arenaLock)
    elseif person.class == Constants.CLASS_HORSEMAN then
        return Moves.getHorsemanMoves(person, cityMap, arenaLock)
    else
        return Moves.getNormieMoves(person, cityMap, arenaLock)
    end
end

return Moves
