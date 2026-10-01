# Gangs (Love2D)

A turn-based, grid-based, top-down tactical gang warfare game built in Love2D.

## Features

- **Character Creation & Naming**:
  - Enter your custom name at the start of a game, or press `[TAB]` for random name suggestions.
  - Player is fully human-controlled and free of automated personality biases.
- **Procedural Gang Generation**:
  - 3 rival gangs: one for each attack class (**Cowboy**, **Samurai**, **Horseman**).
  - Procedural names generated from 3 combined tokens from a hardcoded word bank (e.g. *Veldgareth*, *Brunkerts*, *Draksenax*).
  - Gang colors generated evenly spaced by 120° on the color wheel.
  - Unique procedural insignias composed of 3–4 layered white polygons on the gang's banner.
- **4 Distinct Classes**:
  - **Cowboys**: Move 1 square in any direction (including diagonal) and shoot in a straight orthogonal line. Bullets instantly hit the first obstacle (person or wall). Can move and shoot on the same turn.
  - **Samurai**: Move unlimited squares orthogonally in any direction, then execute an adjacent melee kill in any direction (orthogonal or diagonal).
  - **Horsemen**: Move like a chess queen (unlimited distance in any of 8 directions) and kill by occupying the enemy square.
  - **Normies**: Regular city citizens. Can move 1 square in any direction; cannot attack.
- **Initiation Contracts & Gang Challenges**:
  - Gangs do not grant membership for free. When you ask to join, the gang assigns a specific hit contract to assassinate a named rival gang member.
  - You are granted probationary trial equipment of that class to hunt them down.
  - The HUD tracks your target's distance and cardinal compass direction, and a pulsating `[TARGET]` crosshair marks them on-screen.
  - Eliminating the target completes your initiation, officially inducting you into the gang with full membership, permanent class abilities, and gang colors!
- **2-Ply Lookahead Beam-Search AI**:
  - NPC enemy AI evaluates the top 3 best moves, then computes the 3 best follow-up counter-moves for each, modulated by personal traits and danger assessments.
- **15x15 Viewport & Locked Combat Arena**:
  - During roam mode, the 15x15 tile viewport tracks the player smoothly across the 200x200 city.
  - Movement and attack overlays are hidden during peaceful exploration and only appear during combat on your turn.
  - When combat begins, the screen locks strictly to the 15x15 tile zone; borders act as impassable walls until all hostile attackers on either side are defeated.
- **Spacious Dialogue Interface**:
  - Dialogue appears in a clean, non-overlapping bottom overlay with dynamic line wrapping.
  - Option buttons have dedicated collision boxes with responsive mouse hover highlights and number key shortcuts `[1]`, `[2]`, `[3]`.
- **Game Over, Victory & Restart**:
  - Defeat and Victory screens display end-game outcomes and statistics.
  - Click `[RESTART GAME]` or press `[R]` anytime to start a fresh playthrough.

## How to Play

### Launching the Game
From the project folder:
```bash
/Users/kylelong/.gemini/antigravity/scratch/gangs/run.sh
```
Or directly with Love2D:
```bash
/Applications/love.app/Contents/MacOS/love /Users/kylelong/.gemini/antigravity/scratch/gangs
```

### Controls
- **Arrow Keys / WASD**: Move 1 tile (N, S, W, E).
- **Q / E / Z / C**: Move diagonal (NW, NE, SW, SE).
- **Space**: Wait / pass turn.
- **Left Click**:
  - In Roam Mode: Click an adjacent NPC to talk; click distant tile to step toward it.
  - In Combat Mode: Click a highlighted green tile to move; click a red target/line to attack.
  - In Dialogue Mode: Click option buttons or press keys `1`, `2`, `3`, `4`.
- **R**: Restart game.
- **Escape**: Close dialogue.
