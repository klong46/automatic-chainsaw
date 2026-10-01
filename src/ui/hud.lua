local Constants = require("src.constants")
local MathUtils = require("src.utils.math_utils")

local HUD = {}
HUD.__index = HUD

function HUD.new(cityMap, gangManager, combatManager, dialogueManager)
    local self = setmetatable({}, HUD)
    self.cityMap = cityMap
    self.gangManager = gangManager
    self.combatManager = combatManager
    self.dialogueManager = dialogueManager

    self.hoveredOption = nil
    self.restartButtonBounds = { x = 0, y = 0, w = 0, h = 0 }
    self.restartHovered = false

    self.ambushButtonBounds = { x = 0, y = 0, w = 0, h = 0 }
    self.ambushHovered = false

    return self
end

function HUD:draw(attackMode)
    local x = Constants.VIEW_PIXELS
    local y = 0
    local w = Constants.SIDEBAR_WIDTH
    local h = Constants.WINDOW_HEIGHT

    -- Sidebar background
    love.graphics.setColor(0.08, 0.09, 0.11, 1.0)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Left border line
    love.graphics.setColor(0.25, 0.28, 0.35, 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y, x, h)

    local curY = 12

    -- 1. TITLE
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("G A N G S", x + 16, curY)
    curY = curY + 22

    -- 2. PLAYER STATUS CARD
    curY = self:drawPlayerCard(x + 12, curY, w - 24)

    -- 3. SIDEBAR CONTENT (COMBAT LOG OR CONTROLS)
    if self.combatManager.active then
        curY = self:drawCombatPanel(x + 12, curY, w - 24)
    else
        curY = self:drawControlsPanel(x + 12, curY, w - 24, attackMode)
    end

    -- 4. 3 GANGS STATUS
    curY = self:drawGangsPanel(x + 12, curY, w - 24)

    -- 5. RESTART BUTTON
    self.restartButtonBounds = { x = x + 12, y = h - 170, w = w - 24, h = 28 }
    local rb = self.restartButtonBounds
    if self.restartHovered then
        love.graphics.setColor(0.7, 0.2, 0.2, 0.9)
    else
        love.graphics.setColor(0.25, 0.15, 0.18, 0.8)
    end
    love.graphics.rectangle("fill", rb.x, rb.y, rb.w, rb.h, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", rb.x, rb.y, rb.w, rb.h, 4, 4)
    love.graphics.print("[R] RESTART GAME", rb.x + 38, rb.y + 7)

    -- 6. MINIMAP AT BOTTOM
    self:drawMinimap(x + 12, h - 132, w - 24, 120)

    -- 7. DIALOGUE MODAL OVERLAY (Drawn prominently with clean layout)
    if self.dialogueManager.active then
        self:drawDialogueOverlay()
    end
end

function HUD:drawPlayerCard(px, py, pw)
    local player = self.cityMap.player
    if not player then return py end

    local gang = player.gangId and self.gangManager:getGang(player.gangId) or nil
    local trialGang = player.isInitiate and player.mission and self.gangManager:getGang(player.mission.sponsorGangId) or nil

    love.graphics.setColor(0.14, 0.16, 0.20, 1.0)
    love.graphics.rectangle("fill", px, py, pw, 88, 6, 6)

    -- Insignia or Normie circle
    if gang and gang.insignia then
        gang.insignia:draw(px + 22, py + 26, 16, gang.color)
    elseif trialGang and trialGang.insignia then
        trialGang.insignia:draw(px + 22, py + 26, 16, trialGang.color)
    else
        love.graphics.setColor(0.7, 0.7, 0.75, 1.0)
        love.graphics.circle("fill", px + 22, py + 26, 14)
    end

    -- Player Name
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(player.name, px + 46, py + 8)

    -- Class & Affiliation
    local classStr = player.class:upper()
    local rankStr
    if gang then
        rankStr = gang.name .. " Member"
        love.graphics.setColor(gang.color[1], gang.color[2], gang.color[3], 1)
    elseif player.isInitiate and trialGang then
        rankStr = trialGang.name .. " (Initiate)"
        love.graphics.setColor(trialGang.color[1], trialGang.color[2], trialGang.color[3], 1)
    else
        rankStr = "Neutral Citizen"
        love.graphics.setColor(0.65, 0.85, 1.0, 1)
    end
    love.graphics.print(classStr .. " | " .. rankStr, px + 46, py + 26)

    -- Active Mission Tracking Info
    if player.mission and not player.mission.completed then
        love.graphics.setColor(1.0, 0.35, 0.35, 1)
        love.graphics.print("HIT: Hunt " .. player.mission.targetName, px + 8, py + 48)

        local t = player.mission.target
        if t and t.alive then
            local dist = math.floor(MathUtils.dist(player.x, player.y, t.x, t.y))
            local dirX = t.x > player.x and "E" or (t.x < player.x and "W" or "")
            local dirY = t.y > player.y and "S" or (t.y < player.y and "N" or "")
            love.graphics.setColor(0.9, 0.8, 0.3, 1)
            love.graphics.print("Target: " .. dist .. " blocks away (" .. dirY .. dirX .. ")", px + 8, py + 66)
        else
            love.graphics.setColor(0.3, 1.0, 0.4, 1)
            love.graphics.print("Target dead! Speak to gang!", px + 8, py + 66)
        end
    else
        love.graphics.setColor(0.6, 0.7, 0.8, 1)
        love.graphics.print("Status: Free exploration", px + 8, py + 56)
    end

    return py + 96
end

function HUD:drawControlsPanel(px, py, pw, attackMode)
    love.graphics.setColor(0.12, 0.14, 0.18, 1.0)
    love.graphics.rectangle("fill", px, py, pw, 120, 6, 6)

    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.print("CONTROLS", px + 10, py + 8)

    love.graphics.setColor(0.8, 0.8, 0.85, 1)
    love.graphics.print("[WASD / Hold]: Move rapidly", px + 10, py + 24)
    love.graphics.print("[Q/E/Z/C]: Move diagonally", px + 10, py + 38)
    love.graphics.print("[Click NPC]: Talk directly", px + 10, py + 52)

    -- BLINDSIDE ATTACK BUTTON
    self.ambushButtonBounds = { x = px + 8, y = py + 74, w = pw - 16, h = 34 }
    local ab = self.ambushButtonBounds
    if attackMode then
        love.graphics.setColor(0.9, 0.15, 0.15, 0.95)
        love.graphics.rectangle("fill", ab.x, ab.y, ab.w, ab.h, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", ab.x, ab.y, ab.w, ab.h, 4, 4)
        love.graphics.printf("[F] CANCEL AMBUSH", ab.x, ab.y + 10, ab.w, "center")
    else
        if self.ambushHovered then
            love.graphics.setColor(0.65, 0.18, 0.18, 0.95)
        else
            love.graphics.setColor(0.35, 0.12, 0.14, 0.85)
        end
        love.graphics.rectangle("fill", ab.x, ab.y, ab.w, ab.h, 4, 4)
        love.graphics.setColor(1, 0.35, 0.35, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", ab.x, ab.y, ab.w, ab.h, 4, 4)
        love.graphics.printf("[F] BLINDSIDE ATTACK", ab.x, ab.y + 10, ab.w, "center")
    end

    return py + 128
end

function HUD:drawCombatPanel(px, py, pw)
    love.graphics.setColor(0.20, 0.08, 0.08, 1.0)
    love.graphics.rectangle("fill", px, py, pw, 128, 6, 6)

    love.graphics.setColor(1.0, 0.3, 0.3, 1)
    love.graphics.print("[!] IN COMBAT (Turn " .. self.combatManager.turnNumber .. ")", px + 10, py + 8)

    local curTurn = self.combatManager:getCurrentTurnPerson()
    if curTurn then
        love.graphics.setColor(1, 1, 1, 1)
        local turnMsg = curTurn.isPlayer and "YOUR TURN! Click/Move to act" or (curTurn.name .. "'s Turn...")
        love.graphics.print(turnMsg, px + 10, py + 26)
    end

    -- Recent Combat Log entries
    love.graphics.setColor(0.75, 0.75, 0.8, 1)
    local logY = py + 48
    for i = 1, math.min(5, #self.combatManager.combatLog) do
        local entry = self.combatManager.combatLog[i]
        love.graphics.print(entry, px + 10, logY)
        logY = logY + 15
    end

    return py + 136
end

function HUD:drawGangsPanel(px, py, pw)
    love.graphics.setColor(0.12, 0.13, 0.16, 1.0)
    love.graphics.rectangle("fill", px, py, pw, 142, 6, 6)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("CITY GANGS", px + 10, py + 8)

    local gY = py + 28
    for _, gang in ipairs(self.gangManager.gangs) do
        gang.insignia:draw(px + 20, gY + 14, 13, gang.color)

        if gang.defeated then
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
            love.graphics.print(gang.name .. " [WIPED OUT]", px + 42, gY)
        else
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(gang.name, px + 42, gY)
        end

        love.graphics.setColor(gang.color[1], gang.color[2], gang.color[3], 1.0)
        love.graphics.print(gang.class:upper() .. ": " .. gang.aliveCount .. " fighters", px + 42, gY + 16)

        gY = gY + 36
    end

    return py + 150
end

function HUD:drawMinimap(px, py, pw, ph)
    love.graphics.setColor(0.06, 0.07, 0.09, 1.0)
    love.graphics.rectangle("fill", px, py, pw, ph, 4, 4)
    love.graphics.setColor(0.2, 0.22, 0.26, 1.0)
    love.graphics.rectangle("line", px, py, pw, ph, 4, 4)

    local scaleX = pw / self.cityMap.width
    local scaleY = ph / self.cityMap.height

    for _, p in ipairs(self.cityMap.people) do
        if p.alive then
            local dotX = px + p.x * scaleX
            local dotY = py + p.y * scaleY
            if p.isPlayer then
                love.graphics.setColor(1, 0.9, 0.2, 1)
                love.graphics.circle("fill", dotX, dotY, 3)
            elseif self.cityMap.player and self.cityMap.player.mission and
                   (p == self.cityMap.player.mission.target or p.id == self.cityMap.player.mission.targetId) then
                love.graphics.setColor(1, 0.1, 0.1, 1)
                love.graphics.circle("fill", dotX, dotY, 3.5)
            elseif p.gangId then
                local g = self.gangManager:getGang(p.gangId)
                love.graphics.setColor(g.color[1], g.color[2], g.color[3], 0.8)
                love.graphics.rectangle("fill", dotX - 1, dotY - 1, 2, 2)
            else
                love.graphics.setColor(0.6, 0.6, 0.65, 0.5)
                love.graphics.rectangle("fill", dotX - 1, dotY - 1, 1, 1)
            end
        end
    end

    local camX = self.cityMap.camX
    local camY = self.cityMap.camY
    local boxX = px + camX * scaleX
    local boxY = py + camY * scaleY
    local boxW = Constants.VIEW_TILES * scaleX
    local boxH = Constants.VIEW_TILES * scaleY

    if self.combatManager.active then
        love.graphics.setColor(1, 0.2, 0.2, 0.9)
    else
        love.graphics.setColor(0.3, 0.8, 1, 0.8)
    end
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH)
end

function HUD:drawDialogueOverlay()
    local npc = self.dialogueManager.npc
    if not npc then return end

    local gang = npc.gangId and self.gangManager:getGang(npc.gangId) or nil

    local bx = 16
    local by = 480
    local bw = Constants.VIEW_PIXELS - 32
    local bh = 224

    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)

    local borderColor = gang and gang.color or { 0.7, 0.7, 0.75 }
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 0.9)
    love.graphics.setLineWidth(2.5)
    love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)

    local titleStr = "[TALK] " .. npc.name
    if gang then
        gang.insignia:draw(bx + 24, by + 22, 13, gang.color)
        titleStr = titleStr .. " (" .. gang.name .. " " .. npc.class:upper() .. ")"
    else
        love.graphics.setColor(0.7, 0.7, 0.75, 1)
        love.graphics.circle("fill", bx + 24, by + 22, 11)
        titleStr = titleStr .. " (Citizen Normie)"
    end

    love.graphics.setColor(1, 0.9, 0.3, 1)
    love.graphics.print(titleStr, bx + 46, by + 14)

    love.graphics.setColor(0.95, 0.95, 0.95, 1)
    local font = love.graphics.getFont()
    local textWidth = bw - 48
    love.graphics.printf(self.dialogueManager.dialogueText, bx + 24, by + 42, textWidth, "left")

    local _, wrappedLines = font:getWrap(self.dialogueManager.dialogueText, textWidth)
    local textHeight = #wrappedLines * font:getHeight()

    local optStartY = math.max(by + 48 + textHeight, by + 98)
    local buttonHeight = 26
    local buttonSpacing = 6

    self.dialogueManager.renderedOptionBounds = {}

    for i, opt in ipairs(self.dialogueManager.options) do
        local btnY = optStartY + (i - 1) * (buttonHeight + buttonSpacing)
        local btnBounds = { x = bx + 20, y = btnY, w = bw - 40, h = buttonHeight }
        table.insert(self.dialogueManager.renderedOptionBounds, btnBounds)

        local isHovered = (self.dialogueManager.hoveredOptionIndex == i)
        if isHovered then
            love.graphics.setColor(0.25, 0.45, 0.75, 0.9)
            love.graphics.rectangle("fill", btnBounds.x, btnBounds.y, btnBounds.w, btnBounds.h, 4, 4)
            love.graphics.setColor(1.0, 1.0, 0.4, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", btnBounds.x, btnBounds.y, btnBounds.w, btnBounds.h, 4, 4)
        else
            love.graphics.setColor(0.15, 0.18, 0.25, 0.8)
            love.graphics.rectangle("fill", btnBounds.x, btnBounds.y, btnBounds.w, btnBounds.h, 4, 4)
            love.graphics.setColor(0.5, 0.6, 0.75, 0.8)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", btnBounds.x, btnBounds.y, btnBounds.w, btnBounds.h, 4, 4)
            love.graphics.setColor(0.85, 0.9, 1.0, 1)
        end

        love.graphics.print(opt.text, btnBounds.x + 12, btnBounds.y + 6)
    end
end

function HUD:mousepressed(mx, my, button)
    if self.dialogueManager.active then
        if self.dialogueManager:mousepressed(mx, my, button) then
            return true
        end
        return true
    end

    -- Check ambush button
    local ab = self.ambushButtonBounds
    if mx >= ab.x and mx <= ab.x + ab.w and my >= ab.y and my <= ab.y + ab.h then
        return "toggle_ambush"
    end

    -- Check restart button
    local rb = self.restartButtonBounds
    if mx >= rb.x and mx <= rb.x + rb.w and my >= rb.y and my <= rb.y + rb.h then
        return "restart"
    end

    return false
end

function HUD:mousemoved(mx, my)
    if self.dialogueManager.active then
        self.dialogueManager:mousemoved(mx, my)
    end

    local ab = self.ambushButtonBounds
    self.ambushHovered = (mx >= ab.x and mx <= ab.x + ab.w and my >= ab.y and my <= ab.y + ab.h)

    local rb = self.restartButtonBounds
    self.restartHovered = (mx >= rb.x and mx <= rb.x + rb.w and my >= rb.y and my <= rb.y + rb.h)
end

return HUD
