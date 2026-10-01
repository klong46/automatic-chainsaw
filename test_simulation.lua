-- Automated headless test to verify simulation, AI, moves, and dialogue
local Constants = require("src.constants")
local CityMap = require("src.world.city_map")
local GangManager = require("src.gangs.gang_manager")
local CombatManager = require("src.combat.combat_manager")
local DialogueManager = require("src.dialogue.dialogue_manager")
local Person = require("src.entities.person")
local Moves = require("src.entities.moves")
local AIBrain = require("src.ai.ai_brain")

print("1. Initializing CityMap...")
local cityMap = CityMap.new()
assert(cityMap.width == 200, "CityMap width should be 200")
assert(cityMap.height == 200, "CityMap height should be 200")

print("2. Initializing GangManager...")
local gangManager = GangManager.new()
assert(#gangManager.gangs == 3, "Must have exactly 3 gangs")
for i, g in ipairs(gangManager.gangs) do
    print(string.format("   Gang %d: Name='%s', Class='%s', Hue=%.2f, Color=(%.2f, %.2f, %.2f)",
        i, g.name, g.class, g.hue, g.color[1], g.color[2], g.color[3]))
    assert(#g.name >= 4, "Gang name should be generated from word bank")
    assert(g.insignia and #g.insignia.polygons >= 3, "Insignia must have 3-4 polygons")
end

print("3. Spawning test entities...")
local player = Person.new({ name = "Tester", x = 50, y = 50, class = Constants.CLASS_NORMIE, isPlayer = true })
cityMap:addPerson(player)
assert(player.personality == nil, "Player must NOT have AI personality traits")

local cowboy = Person.new({ name = "Billy", x = 52, y = 50, class = Constants.CLASS_COWBOY, gangId = 1 })
cityMap:addPerson(cowboy)
gangManager:registerMember(1, cowboy)

local samurai = Person.new({ name = "Musashi", x = 54, y = 50, class = Constants.CLASS_SAMURAI, gangId = 2 })
cityMap:addPerson(samurai)
gangManager:registerMember(2, samurai)

local horseman = Person.new({ name = "Joan", x = 50, y = 54, class = Constants.CLASS_HORSEMAN, gangId = 3 })
cityMap:addPerson(horseman)
gangManager:registerMember(3, horseman)

print("4. Testing Movement and Attack generators...")
local pMoves = Moves.getAvailableMoves(player, cityMap, nil)
print("   Player (Normie) available moves count: " .. #pMoves)
assert(#pMoves > 0, "Player must have moves")

local cMoves = Moves.getAvailableMoves(cowboy, cityMap, nil)
print("   Cowboy available moves count: " .. #cMoves)
assert(#cMoves > 0, "Cowboy must have moves and shoot options")

local sMoves = Moves.getAvailableMoves(samurai, cityMap, nil)
print("   Samurai available moves count: " .. #sMoves)
assert(#sMoves > 0, "Samurai must have orthogonal moves")

local hMoves = Moves.getAvailableMoves(horseman, cityMap, nil)
print("   Horseman available moves count: " .. #hMoves)
assert(#hMoves > 0, "Horseman must have queen moves")

print("5. Testing Combat Manager and 15x15 Arena Lock...")
local combatManager = CombatManager.new(cityMap, gangManager)
cityMap:centerCameraOn(50, 50, true)
combatManager:startCombat(player, cowboy)
assert(combatManager.active == true, "Combat must be active")
assert(combatManager.arenaLock ~= nil, "Arena lock must be set")
print(string.format("   Arena locked: min=(%d, %d) max=(%d, %d)",
    combatManager.arenaLock.minX, combatManager.arenaLock.minY,
    combatManager.arenaLock.maxX, combatManager.arenaLock.maxY))
assert((combatManager.arenaLock.maxX - combatManager.arenaLock.minX + 1) == 15, "Arena width must be 15 tiles")
assert((combatManager.arenaLock.maxY - combatManager.arenaLock.minY + 1) == 15, "Arena height must be 15 tiles")
combatManager:endCombat("Test reset")

print("6. Testing AI Brain 2-ply search...")
local bestMove = AIBrain.findBestMove(cowboy, { samurai, horseman }, {}, cityMap, nil)
assert(bestMove ~= nil, "AI must find a move")
print("   Cowboy best move chosen: " .. tostring(bestMove.desc))

print("7. Testing Dialogue Manager & Initiation Mission Hit Contract...")
local dialogueManager = DialogueManager.new(gangManager, combatManager)
dialogueManager:startDialogue(player, cowboy)
assert(dialogueManager.active == true, "Dialogue must be active")
print("   Dialogue prompt: " .. dialogueManager.dialogueText)
assert(#dialogueManager.options > 0, "Must have dialogue options")

-- Select "Ask to join" (option 1)
dialogueManager:selectOption(1)
print("   Contract prompt: " .. dialogueManager.dialogueText)
assert(player.mission == nil, "Player should not have accepted mission yet")

-- Select "Accept Mission: Assassinate Target" (option 1)
dialogueManager:selectOption(1)
assert(player.isInitiate == true, "Player must now be an initiate")
assert(player.mission ~= nil, "Player must have an active assassination mission")
print("   Mission target: " .. player.mission.targetName .. " of " .. player.mission.targetGangName)
print("   Player trial weapon class: " .. player.class)

print("8. Testing Target Elimination and Gang Induction...")
local target = player.mission.target
assert(target ~= nil, "Target must exist")
combatManager:killPerson(target, player)
assert(player.isInitiate == false, "Player should now be fully inducted")
assert(player.gangId == 1, "Player should now be a full member of Gang 1")
assert(player.mission == nil, "Mission is cleared upon graduation")
print("   Target successfully killed! Player inducted into Gang 1 as: " .. player.class)

print("ALL HEADLESS TESTS PASSED WITH 100% SUCCESS!")
