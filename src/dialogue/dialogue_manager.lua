local Personality = require("src.entities.personality")

local DialogueManager = {}
DialogueManager.__index = DialogueManager

function DialogueManager.new(gangManager, combatManager)
    local self = setmetatable({}, DialogueManager)
    self.gangManager = gangManager
    self.combatManager = combatManager

    self.active = false
    self.npc = nil
    self.dialogueText = ""
    self.options = {}
    self.renderedOptionBounds = {}
    self.hoveredOptionIndex = nil

    return self
end

function DialogueManager:startDialogue(player, npc)
    self.active = true
    self.player = player
    self.npc = npc
    self:generateDialogueState("initial")
end

function DialogueManager:closeDialogue()
    self.active = false
    self.npc = nil
    self.options = {}
    self.renderedOptionBounds = {}
    self.hoveredOptionIndex = nil
end

function DialogueManager:generateDialogueState(state)
    local npc = self.npc
    local player = self.player
    local gang = npc.gangId and self.gangManager:getGang(npc.gangId) or nil
    self.options = {}

    if not gang then
        -- Talking to another Normie
        self.dialogueText = "Hey there, neighbor! Keep your head down; the gang wars are tearing the city apart. The " ..
            self.gangManager.gangs[1].name .. ", " .. self.gangManager.gangs[2].name .. ", and " .. self.gangManager.gangs[3].name .. " are everywhere."
        table.insert(self.options, { text = "1. Ask for survival advice", action = function()
            self.dialogueText = "Normies can move in any direction, but we can't fight back! If you talk to a gang member, they might give you an initiation challenge to join."
            self.options = { { text = "1. Understood, stay safe.", action = function() self:closeDialogue() end } }
        end })
        table.insert(self.options, { text = "2. Bid farewell", action = function() self:closeDialogue() end })
        return
    end

    -- Check if player has an active initiation mission for this gang
    local hasMissionForThisGang = (player.mission and player.mission.sponsorGangId == gang.id)
    local isSameGang = (player.gangId == gang.id and not player.isInitiate)

    if state == "initial" then
        if isSameGang then
            local greeting = ""
            if Personality.hasTrait(npc, "heroic") then
                greeting = "Greetings, comrade! We fight side by side under the banner of " .. gang.name .. "!"
            elseif Personality.hasTrait(npc, "proud") then
                greeting = "Stand proud, fellow fighter. Our gang's honor shall conquer this city!"
            else
                greeting = "Good to see a familiar face from " .. gang.name .. ". Watch your six out there."
            end
            self.dialogueText = greeting

            table.insert(self.options, { text = "1. Ask about our gang's war status", action = function()
                self.dialogueText = "We have " .. gang.aliveCount .. " fighters still breathing. Rival gangs are on the prowl!"
                self.options = { { text = "1. For the gang!", action = function() self:closeDialogue() end } }
            end })
            table.insert(self.options, { text = "2. Part ways", action = function() self:closeDialogue() end })
            return
        end

        -- Check pending initiation mission
        if hasMissionForThisGang then
            local targetPerson = self.player.mission.target
            local targetDead = (not targetPerson or not targetPerson.alive or self.player.mission.completed)

            if targetDead then
                self.dialogueText = "Word travels fast! You hunted down and eliminated " .. self.player.mission.targetName .. "! You have proven your mettle beyond any doubt."
                table.insert(self.options, { text = "1. Swear the oath & officially join " .. gang.name .. "!", action = function()
                    player:joinGang(gang)
                    self.dialogueText = "Welcome home! You are now a full-fledged " .. gang.class:upper() .. " of " .. gang.name .. "!"
                    self.options = { { text = "1. Ready for war!", action = function() self:closeDialogue() end } }
                end })
            else
                self.dialogueText = "What are you doing back here already? " .. self.player.mission.targetName .. " of the " .. self.player.mission.targetGangName .. " is still breathing! Go finish the job!"
                table.insert(self.options, { text = "1. I'm on it.", action = function() self:closeDialogue() end })
                table.insert(self.options, { text = "2. Abandon initiation trial", action = function()
                    player:leaveGang()
                    self.dialogueText = "Pathetic. Drop our trial gear and get out of our sight."
                    self.options = { { text = "1. Leave", action = function() self:closeDialogue() end } }
                end })
            end
            return
        end

        -- Standard Greeting from rival or potential sponsor
        local greeting = ""
        if Personality.hasTrait(npc, "combative") then
            greeting = "What are you staring at? Make one wrong move and you'll end up face down on this pavement!"
        elseif Personality.hasTrait(npc, "charming") then
            greeting = "Well, look who wandered into our turf. Interested in the power and prestige of " .. gang.name .. "?"
        elseif Personality.hasTrait(npc, "shy") then
            greeting = "H-halt... This street belongs to " .. gang.name .. ". Please don't cause any trouble..."
        elseif Personality.hasTrait(npc, "proud") then
            greeting = "Bow your head before " .. gang.name .. "! We rule these blocks."
        else
            greeting = "Halt. You are speaking with a member of " .. gang.name .. ". State your purpose."
        end
        self.dialogueText = greeting

        -- Options
        if player.gangId == nil or player.isInitiate then
            table.insert(self.options, { text = "1. Ask to join " .. gang.name, action = function()
                self:generateDialogueState("challenge_request")
            end })
        else
            table.insert(self.options, { text = "1. Offer to defect and join " .. gang.name, action = function()
                self:generateDialogueState("defect_request")
            end })
        end

        table.insert(self.options, { text = "2. Insult and provoke them", action = function()
            self:generateDialogueState("offended")
        end })

        table.insert(self.options, { text = "3. Back away peacefully", action = function()
            self:closeDialogue()
        end })

    elseif state == "challenge_request" or state == "defect_request" then
        -- Find a specific rival target
        local target = self.gangManager:findRivalTarget(gang.id)
        if not target then
            -- No rivals left!
            self.dialogueText = "Our rivals have already crumbled! You may join our ranks immediately."
            table.insert(self.options, { text = "1. Join " .. gang.name, action = function()
                player:joinGang(gang)
                self.dialogueText = "Welcome to " .. gang.name .. "! You are now a " .. gang.class:upper() .. "!"
                self.options = { { text = "1. Let's roll!", action = function() self:closeDialogue() end } }
            end })
            return
        end

        local rivalGang = self.gangManager:getGang(target.gangId)
        local challengeIntro = ""
        if state == "defect_request" then
            challengeIntro = "A defector? We don't trust turncoats easily. You want in? Prove your loyalty by taking out one of your former allies or enemies: "
        else
            challengeIntro = "You want to wear the colors of " .. gang.name .. "? Words are cheap. Prove your worth: "
        end

        self.dialogueText = challengeIntro .. "Track down and eliminate " .. target.name .. ", a " .. target.class:upper() ..
            " of the rival " .. rivalGang.name .. "!\nWe have given you trial " .. gang.class:upper() .. " equipment. Complete the hit to be officially inducted!"

        table.insert(self.options, { text = "1. Accept Mission: Assassinate " .. target.name .. " (" .. rivalGang.name .. ")", action = function()
            player:setInitiateTrial(gang, target)
            player.mission.target = target
            player.mission.targetGangName = rivalGang.name
            self.dialogueText = "Contract accepted! You now wield trial " .. gang.class:upper() .. " abilities. Find " .. target.name .. " and strike them down!"
            self.options = { { text = "1. On the hunt!", action = function() self:closeDialogue() end } }
        end })

        table.insert(self.options, { text = "2. Decline the challenge", action = function()
            self:closeDialogue()
        end })

    elseif state == "offended" then
        self.dialogueText = "YOU DARE INSULT ME?! DRAW YOUR WEAPONS!"
        table.insert(self.options, { text = "1. Fight!", action = function()
            self:closeDialogue()
            self.combatManager:startCombat(player, npc)
        end })
    end
end

function DialogueManager:selectOption(index)
    if not self.active or not self.options[index] then return end
    local opt = self.options[index]
    if opt.action then
        opt.action()
    end
end

function DialogueManager:mousepressed(mx, my, button)
    if not self.active or button ~= 1 then return false end
    for i, b in ipairs(self.renderedOptionBounds) do
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            self:selectOption(i)
            return true
        end
    end
    return false
end

function DialogueManager:mousemoved(mx, my)
    self.hoveredOptionIndex = nil
    if not self.active then return end
    for i, b in ipairs(self.renderedOptionBounds) do
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            self.hoveredOptionIndex = i
            break
        end
    end
end

return DialogueManager
