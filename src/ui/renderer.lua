local Constants = require("src.constants")
local MathUtils = require("src.utils.math_utils")

local Renderer = {}
Renderer.__index = Renderer

function Renderer.new(cityMap, gangManager, combatManager)
    local self = setmetatable({}, Renderer)
    self.cityMap = cityMap
    self.gangManager = gangManager
    self.combatManager = combatManager

    self.hoveredTileX = nil
    self.hoveredTileY = nil
    self.pulseTimer = 0

    return self
end

function Renderer:update(dt)
    self.pulseTimer = (self.pulseTimer + dt * 4.0) % (math.pi * 2)
end

function Renderer:worldToScreen(wx, wy)
    local sx = (wx - self.cityMap.camX) * Constants.TILE_SIZE
    local sy = (wy - self.cityMap.camY) * Constants.TILE_SIZE
    return sx, sy
end

function Renderer:screenToWorld(sx, sy)
    if sx < 0 or sx >= Constants.VIEW_PIXELS or sy < 0 or sy >= Constants.VIEW_PIXELS then
        return nil, nil
    end
    local wx = math.floor(sx / Constants.TILE_SIZE + self.cityMap.camX)
    local wy = math.floor(sy / Constants.TILE_SIZE + self.cityMap.camY)
    return wx, wy
end

function Renderer:getPersonUnderMouse(mx, my)
    if mx < 0 or mx >= Constants.VIEW_PIXELS or my < 0 or my >= Constants.VIEW_PIXELS then
        return nil
    end
    local ts = Constants.TILE_SIZE
    local camX = self.cityMap.camX
    local camY = self.cityMap.camY

    -- First check by direct pixel distance to drawn character center
    for _, p in ipairs(self.cityMap.people) do
        if p.alive and not p.isPlayer then
            local cx = (p.drawX - camX) * ts + ts / 2
            local cy = (p.drawY - camY) * ts + ts / 2
            if MathUtils.dist(mx, my, cx, cy) <= 24 then
                return p
            end
        end
    end

    -- Fallback by tile coordinates
    local wx, wy = self:screenToWorld(mx, my)
    if wx and wy then
        local p = self.cityMap:getPersonAt(wx, wy)
        if p and p.alive and not p.isPlayer then
            return p
        end
    end
    return nil
end

function Renderer:draw(playerValidMoves, isCombat, attackModeOnly)
    love.graphics.push()

    -- 1. Scissor to 15x15 viewport
    love.graphics.setScissor(0, 0, Constants.VIEW_PIXELS, Constants.VIEW_PIXELS)

    -- 2. Draw Tiles
    self:drawTiles()

    -- 3. Draw Overlays (in combat, or when attack mode is toggled)
    if (isCombat or attackModeOnly) and playerValidMoves then
        self:drawMoveOverlays(playerValidMoves, attackModeOnly)
    end

    -- 4. Draw Characters & Target Indicators
    self:drawCharacters()

    -- 5. Draw Attack FX
    self:drawEffects()

    -- 6. Draw Combat Arena Lock Border
    if self.combatManager.active then
        self:drawArenaLockBorder()
    elseif attackModeOnly then
        self:drawAmbushModeBanner()
    end

    love.graphics.setScissor()
    love.graphics.pop()
end

function Renderer:drawTiles()
    local camX = math.floor(self.cityMap.camX)
    local camY = math.floor(self.cityMap.camY)

    for cy = 0, Constants.VIEW_TILES do
        for cx = 0, Constants.VIEW_TILES do
            local tx = camX + cx
            local ty = camY + cy
            local sx = (tx - self.cityMap.camX) * Constants.TILE_SIZE
            local sy = (ty - self.cityMap.camY) * Constants.TILE_SIZE

            if tx >= 1 and tx <= self.cityMap.width and ty >= 1 and ty <= self.cityMap.height then
                if self.cityMap:isWall(tx, ty) then
                    -- Building / Barrier
                    love.graphics.setColor(0.12, 0.12, 0.15, 1.0)
                    love.graphics.rectangle("fill", sx, sy, Constants.TILE_SIZE, Constants.TILE_SIZE)

                    -- Top/left highlight
                    love.graphics.setColor(0.25, 0.25, 0.30, 1.0)
                    love.graphics.setLineWidth(2)
                    love.graphics.line(sx, sy + Constants.TILE_SIZE, sx, sy, sx + Constants.TILE_SIZE, sy)

                    -- Dark inner shadow
                    love.graphics.setColor(0.06, 0.06, 0.08, 1.0)
                    love.graphics.line(sx + Constants.TILE_SIZE, sy, sx + Constants.TILE_SIZE, sy + Constants.TILE_SIZE, sx, sy + Constants.TILE_SIZE)
                else
                    -- City Street
                    local checker = ((tx + ty) % 2 == 0)
                    if checker then
                        love.graphics.setColor(0.20, 0.22, 0.25, 1.0)
                    else
                        love.graphics.setColor(0.23, 0.25, 0.28, 1.0)
                    end
                    love.graphics.rectangle("fill", sx, sy, Constants.TILE_SIZE, Constants.TILE_SIZE)

                    -- Subtle grid line
                    love.graphics.setColor(0.16, 0.17, 0.20, 0.6)
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle("line", sx, sy, Constants.TILE_SIZE, Constants.TILE_SIZE)
                end
            else
                -- Void outside world
                love.graphics.setColor(0.05, 0.05, 0.05, 1.0)
                love.graphics.rectangle("fill", sx, sy, Constants.TILE_SIZE, Constants.TILE_SIZE)
            end
        end
    end
end

function Renderer:drawMoveOverlays(moves, attacksOnly)
    for _, m in ipairs(moves) do
        local isAttack = (m.attackTarget ~= nil or m.shootDir ~= nil)
        local sx, sy = self:worldToScreen(m.moveX, m.moveY)

        if isAttack then
            -- Attack move: red tint
            love.graphics.setColor(1.0, 0.15, 0.15, 0.40)
            love.graphics.rectangle("fill", sx + 2, sy + 2, Constants.TILE_SIZE - 4, Constants.TILE_SIZE - 4, 4, 4)
            love.graphics.setColor(1.0, 0.25, 0.25, 0.95)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", sx + 2, sy + 2, Constants.TILE_SIZE - 4, Constants.TILE_SIZE - 4, 4, 4)

            -- If targeting an enemy directly, draw crosshairs
            if m.attackTarget then
                local tx, ty = self:worldToScreen(m.attackTarget.x, m.attackTarget.y)
                local tcx = tx + Constants.TILE_SIZE / 2
                local tcy = ty + Constants.TILE_SIZE / 2
                love.graphics.setColor(1.0, 0.2, 0.2, 0.9)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", tcx, tcy, 18)
                love.graphics.line(tcx - 22, tcy, tcx + 22, tcy)
                love.graphics.line(tcx, tcy - 22, tcx, tcy + 22)
            end
        elseif not attacksOnly then
            -- Movement tile (only in combat)
            love.graphics.setColor(0.2, 0.8, 0.6, 0.25)
            love.graphics.rectangle("fill", sx + 2, sy + 2, Constants.TILE_SIZE - 4, Constants.TILE_SIZE - 4, 4, 4)
            love.graphics.setColor(0.3, 0.9, 0.7, 0.7)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", sx + 2, sy + 2, Constants.TILE_SIZE - 4, Constants.TILE_SIZE - 4, 4, 4)
        end
    end
end

function Renderer:drawAmbushModeBanner()
    local vp = Constants.VIEW_PIXELS
    local pulse = (math.sin(self.pulseTimer * 3.0) + 1.0) * 0.5

    -- Banner at top of viewport
    love.graphics.setColor(0.7, 0.1, 0.1, 0.92)
    love.graphics.rectangle("fill", 0, 0, vp, 26)
    love.graphics.setColor(1.0, 0.3, 0.3, 0.8 + pulse * 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 0, 0, vp, 26)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("[!] BLINDSIDE AMBUSH: Click target/ray to attack first!  [ESC / F] to Cancel", 0, 6, vp, "center")
end

function Renderer:drawCharacters()
    local camX = self.cityMap.camX
    local camY = self.cityMap.camY
    local ts = Constants.TILE_SIZE
    local player = self.cityMap.player

    for _, p in ipairs(self.cityMap.people) do
        if p.alive and
           p.drawX >= camX - 1 and p.drawX <= camX + Constants.VIEW_TILES + 1 and
           p.drawY >= camY - 1 and p.drawY <= camY + Constants.VIEW_TILES + 1 then

            local cx = (p.drawX - camX) * ts + ts / 2
            local cy = (p.drawY - camY) * ts + ts / 2

            local gang = p.gangId and self.gangManager:getGang(p.gangId) or nil
            local color = gang and gang.color or { 0.8, 0.8, 0.85 }

            -- Draw shadow
            love.graphics.setColor(0, 0, 0, 0.4)
            love.graphics.ellipse("fill", cx, cy + 14, 14, 6)

            -- Base body circle
            love.graphics.setColor(color[1], color[2], color[3], 1.0)
            love.graphics.circle("fill", cx, cy, 15)

            -- Distinct class silhouette
            self:drawClassSilhouette(p, cx, cy)

            -- Gang Insignia badge (white shapes on gang color)
            if gang and gang.insignia then
                gang.insignia:draw(cx, cy - 2, 7, color)
            end

            -- Player highlight ring
            if p.isPlayer then
                local glow = 0.7 + 0.3 * math.sin(self.pulseTimer)
                love.graphics.setColor(1.0, 0.85, 0.2, glow)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", cx, cy, 18)

                -- Arrow pointer above player
                love.graphics.setColor(1.0, 0.9, 0.2, 1.0)
                love.graphics.polygon("fill", cx - 4, cy - 24, cx + 4, cy - 24, cx, cy - 18)
            else
                -- Subtle border for NPCs
                love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
                love.graphics.setLineWidth(1.5)
                love.graphics.circle("line", cx, cy, 15)
            end

            -- Mission Assassination Target Marker
            if player and player.mission and not player.mission.completed and
               (p == player.mission.target or p.id == player.mission.targetId) then
                local targetPulse = 0.8 + 0.2 * math.sin(self.pulseTimer * 3)
                love.graphics.setColor(1.0, 0.1, 0.1, targetPulse)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", cx, cy, 22)
                -- Crosshairs
                love.graphics.line(cx - 26, cy, cx - 18, cy)
                love.graphics.line(cx + 18, cy, cx + 26, cy)
                love.graphics.line(cx, cy - 26, cx, cy - 18)
                love.graphics.line(cx, cy + 18, cx, cy + 26)

                -- Label above target
                love.graphics.setColor(1.0, 0.2, 0.2, 1.0)
                love.graphics.print("[TARGET]", cx - 22, cy - 36)
            end

            -- Combat turn indicator
            if self.combatManager.active and self.combatManager:getCurrentTurnPerson() == p then
                local pulse = 20 + 3 * math.sin(self.pulseTimer * 1.5)
                love.graphics.setColor(1.0, 0.2, 0.2, 0.9)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", cx, cy, pulse)
            end
        end
    end
end

function Renderer:drawClassSilhouette(p, cx, cy)
    love.graphics.setColor(0.15, 0.15, 0.18, 0.9)

    if p.class == Constants.CLASS_COWBOY then
        -- Cowboy hat: brim line + crown
        love.graphics.setLineWidth(3)
        love.graphics.line(cx - 13, cy - 7, cx + 13, cy - 7)
        love.graphics.rectangle("fill", cx - 6, cy - 14, 12, 7, 2, 2)
    elseif p.class == Constants.CLASS_SAMURAI then
        -- Katana slash line + kabuto crest
        love.graphics.polygon("fill", cx - 8, cy - 12, cx + 8, cy - 12, cx, cy - 17)
        love.graphics.setLineWidth(2)
        love.graphics.line(cx + 8, cy - 6, cx + 15, cy + 4)
    elseif p.class == Constants.CLASS_HORSEMAN then
        -- Queen crown points
        love.graphics.polygon("fill",
            cx - 10, cy - 8,
            cx - 8,  cy - 16,
            cx - 3,  cy - 10,
            cx,      cy - 17,
            cx + 3,  cy - 10,
            cx + 8,  cy - 16,
            cx + 10, cy - 8
        )
    else
        -- Normie citizen cap/dot
        love.graphics.circle("fill", cx, cy - 10, 4)
    end
end

function Renderer:drawEffects()
    local ts = Constants.TILE_SIZE
    local camX = self.cityMap.camX
    local camY = self.cityMap.camY

    for _, p in ipairs(self.cityMap.people) do
        if p.attackEffect then
            local fx = p.attackEffect
            if fx.type == "shoot" then
                -- Cowboy bullet tracer line
                local fromX = (fx.fromX - camX) * ts + ts/2
                local fromY = (fx.fromY - camY) * ts + ts/2
                local toX = (fx.targetX - camX) * ts + ts/2
                local toY = (fx.targetY - camY) * ts + ts/2

                love.graphics.setColor(1.0, 0.8, 0.1, 0.9)
                love.graphics.setLineWidth(4)
                love.graphics.line(fromX, fromY, toX, toY)

                -- Bullet head spark
                love.graphics.setColor(1.0, 1.0, 0.6, 1.0)
                love.graphics.circle("fill", toX, toY, 8)
            elseif fx.type == "slash" then
                -- Samurai slash arc
                local tx = (fx.targetX - camX) * ts + ts/2
                local ty = (fx.targetY - camY) * ts + ts/2
                love.graphics.setColor(0.3, 0.9, 1.0, 0.9)
                love.graphics.setLineWidth(4)
                love.graphics.arc("line", "open", tx, ty, 20, -0.8, 2.4)
            elseif fx.type == "charge" then
                -- Horseman queen dash trail
                local fromX = (fx.fromX - camX) * ts + ts/2
                local fromY = (fx.fromY - camY) * ts + ts/2
                local toX = (fx.targetX - camX) * ts + ts/2
                local toY = (fx.targetY - camY) * ts + ts/2
                love.graphics.setColor(1.0, 0.3, 0.7, 0.8)
                love.graphics.setLineWidth(5)
                love.graphics.line(fromX, fromY, toX, toY)
                love.graphics.circle("fill", toX, toY, 12)
            end
        end
    end
end

function Renderer:drawArenaLockBorder()
    local vp = Constants.VIEW_PIXELS
    local pulse = (math.sin(self.pulseTimer * 2.0) + 1.0) * 0.5

    -- Danger red pulsating boundary
    love.graphics.setColor(1.0, 0.15, 0.15, 0.6 + pulse * 0.4)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle("line", 3, 3, vp - 6, vp - 6)

    -- Barricade headers
    love.graphics.setColor(0.75, 0.08, 0.08, 0.95)
    love.graphics.rectangle("fill", 0, 0, vp, 24)
    love.graphics.rectangle("fill", 0, vp - 24, vp, 24)

    -- Vector Warning Triangles
    local function drawWarningIcon(ix, iy)
        love.graphics.setColor(1.0, 0.85, 0.1, 1.0)
        love.graphics.polygon("fill", ix, iy - 7, ix + 7, iy + 6, ix - 7, iy + 6)
        love.graphics.setColor(0, 0, 0, 1.0)
        love.graphics.rectangle("fill", ix - 1, iy - 2, 2, 4)
        love.graphics.rectangle("fill", ix - 1, iy + 3, 2, 2)
    end

    drawWarningIcon(110, 12)
    drawWarningIcon(vp - 110, 12)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("[!] ARENA LOCKED (15x15) - FIGHT TO THE DEATH [!]", 145, 5)
    love.graphics.print("[!] PERIMETER SEALED - DESTROY ALL RIVALS [!]", 165, vp - 18)
end

return Renderer
