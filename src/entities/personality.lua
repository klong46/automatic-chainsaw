local Constants = require("src.constants")
local MathUtils = require("src.utils.math_utils")

local Personality = {}

local TRAIT_DESCRIPTIONS = {
    combative = "Combative - quick to draw blood, starts fights, never retreats.",
    peaceful = "Peaceful - avoids bloodshed, seeks compromise, flees battle.",
    proud = "Proud - refuses to back down, fiercely defends honor, insults back.",
    shy = "Shy - keeps a cautious distance, speaks hesitantly.",
    charming = "Charming - silver-tongued, easily recruits or pacifies rivals.",
    intelligent = "Intelligent - calculates cover, exploits enemy blind spots.",
    generous = "Generous - aids allies, shares spoils, fiercely loyal.",
    heroic = "Heroic - self-sacrificing, protects comrades at personal peril.",
    selfish = "Selfish - looks out for number one, retreats early, will defect."
}

function Personality.getRandomTraits(count)
    count = count or math.random(2, 3)
    local traits = {}
    local pool = {}
    for _, t in ipairs(Constants.TRAITS) do
        table.insert(pool, t)
    end
    MathUtils.shuffle(pool)

    for i = 1, math.min(count, #pool) do
        traits[pool[i]] = true
    end

    -- Ensure conflicting traits don't coexist in extremes
    if traits["combative"] and traits["peaceful"] then
        if math.random() < 0.5 then traits["combative"] = nil else traits["peaceful"] = nil end
    end
    if traits["heroic"] and traits["selfish"] then
        if math.random() < 0.5 then traits["heroic"] = nil else traits["selfish"] = nil end
    end

    return traits
end

function Personality.hasTrait(person, trait)
    return person and person.personality and person.personality[trait] == true
end

function Personality.getTraitString(person)
    if not person or not person.personality then return "Neutral" end
    local list = {}
    for t, active in pairs(person.personality) do
        if active then
            table.insert(list, t:sub(1,1):upper() .. t:sub(2))
        end
    end
    if #list == 0 then return "Neutral" end
    return table.concat(list, ", ")
end

function Personality.getDescription(trait)
    return TRAIT_DESCRIPTIONS[trait] or trait
end

return Personality
