# Projectbluebean

A first-person, round-based survival shooter built in Godot 4.6. Inspired by Call of Duty Zombies, but set in a dark-fantasy dungeon where you fight waves of orcs and goblins using fantasy ranged weapons.

## Features

- **Round-Based Survival:** Fight increasingly difficult waves of enemies.
- **Economy System:** Earn points by hitting enemies and spend them on weapon refills or opening doors.
- **Fantasy Arsenal:**
  - **Crossbow:** Precision ranged weapon.
  - **Fire Staff:** Powerful area damage with projectile bolts.
  - **Quick Melee:** Fallback attack for close encounters.
- **Dynamic HUD:** Real-time feedback for hits, ammo, points, and round status.
- **Advanced Physics:** Powered by Godot Jolt for robust 3D interactions.

## Tech Stack

- **Engine:** [Godot 4.6](https://godotengine.org/)
- **Physics:** [Godot Jolt](https://github.com/godot-jolt/godot-jolt)
- **Assets:** KayKit Adventurers and Skeletons packs.

## Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ariesyous/projectbluebean.git
   ```
2. **Open the project:**
   Open `projectbluebean/project.godot` in Godot 4.6.
3. **Run the game:**
   Press F5 or run the `Arena.tscn` scene.

## Controls

- **WASD:** Move
- **Space:** Jump
- **Left Mouse Button:** Fire weapon
- **R:** Reload
- **F:** Interact (buy weapon refill, open doors)
- **V:** Melee attack
- **1 / 2:** Switch weapons
- **Esc:** Pause

## Project Structure

- `projectbluebean/`: The main Godot project directory.
  - `scenes/`: Game scenes (Player, Enemies, World).
  - `scripts/`: GDScript logic.
  - `autoloads/`: Global singletons (GameState, Economy).
  - `assets/`: 3D models and textures.
  - `resources/`: Data-driven weapon definitions.
- `assets/`: Raw asset source files (outer directory).

## License

This project is private. See `godot-ai-LICENSE.txt` for details on the Godot AI integration.
