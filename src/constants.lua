local Constants = {}

-- Viewport and Display
Constants.TILE_SIZE = 48       -- 48x48 pixels per grid tile
Constants.VIEW_TILES = 15      -- 15x15 tiles in viewport
Constants.VIEW_PIXELS = Constants.TILE_SIZE * Constants.VIEW_TILES -- 720 px
Constants.SIDEBAR_WIDTH = 240
Constants.WINDOW_WIDTH = Constants.VIEW_PIXELS + Constants.SIDEBAR_WIDTH -- 960 px
Constants.WINDOW_HEIGHT = Constants.VIEW_PIXELS -- 720 px

-- City Dimensions
Constants.MAP_WIDTH = 200
Constants.MAP_HEIGHT = 200

-- Character Class Types
Constants.CLASS_COWBOY = "cowboy"
Constants.CLASS_SAMURAI = "samurai"
Constants.CLASS_HORSEMAN = "horseman"
Constants.CLASS_NORMIE = "normie"

-- Personalities (NPCs only)
Constants.TRAITS = {
    "combative",
    "peaceful",
    "proud",
    "shy",
    "charming",
    "intelligent",
    "generous",
    "heroic",
    "selfish"
}

-- Game States
Constants.STATE_NAME_ENTRY = "name_entry"
Constants.STATE_ROAM = "roam"           -- Free exploration in city
Constants.STATE_COMBAT = "combat"       -- Locked in 15x15 arena
Constants.STATE_DIALOGUE = "dialogue"   -- In conversation
Constants.STATE_GAMEOVER = "game_over"   -- Player killed
Constants.STATE_VICTORY = "victory"     -- Player's gang dominates city

-- Direction Vectors (8-directional)
Constants.DIRS_8 = {
    { dx =  0, dy = -1, name = "N" },
    { dx =  1, dy = -1, name = "NE" },
    { dx =  1, dy =  0, name = "E" },
    { dx =  1, dy =  1, name = "SE" },
    { dx =  0, dy =  1, name = "S" },
    { dx = -1, dy =  1, name = "SW" },
    { dx = -1, dy =  0, name = "W" },
    { dx = -1, dy = -1, name = "NW" },
}

-- Orthogonal Directions (4-directional)
Constants.DIRS_4 = {
    { dx =  0, dy = -1, name = "N" },
    { dx =  1, dy =  0, name = "E" },
    { dx =  0, dy =  1, name = "S" },
    { dx = -1, dy =  0, name = "W" },
}

return Constants
