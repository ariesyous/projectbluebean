# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current handoff update

The newest concise handoff is in `AGENTS.md`. Read that first in a new thread.

Current status as of commit `dfd4c30 Add weapon hit and reload feedback`:

- M1 core loop/economy is playable.
- Goblin/orc hit detection is fixed.
- KayKit Crossbow and Staff view models are wired.
- M2 round/wave system is implemented.
- M3 foundation is implemented: weapon slots, Staff purchase/refill, quick melee fallback, Fire
  Staff projectile bolts, HUD hit marker, and reload HUD feedback.
- Added procedural weapon recoil/reload animations.
- Added Throwing Axe (gravity projectile) as weapon_3 and placed it on the wall in Arena.tscn.
- Added Ammo Refill interactable (`buyable_ammo.gd`).
- M3 feel polish done: procedural sway/bob and firing/reload SFX + impact VFX (committed).
- M4 started: **Mystery Box** (`scripts/interactables/mystery_box.gd`,
  `scenes/interactables/MysteryBox.tscn`) placed in the far room behind the BuyableDoor —
  pay 950 to roll a random weapon, then interact again to take it.
- M4 **Perk shrines** (`buyable_perk.gd` + `perk_reload`/`perk_firerate`/`perk_speed` on a
  shared `PerkShrine.tscn`) in the far room: Stamina (move speed), Quick Hands (reload),
  Frenzy (fire rate). Player holds `fire_rate_mult`/`reload_time_mult`/`_perks`; `weapon.gd`
  reads the mults; HUD `PerksLabel` lists owned perks.

Most recently verified through Godot MCP:

- Crossbow hit reduces enemy health `100 -> 55`, decrements ammo, and flashes the hit marker.
- Hit marker clears after its short flash.
- Reload HUD shows `Reloading`, then returns to ammo text.
- Fire Staff projectile damage, melee damage, weapon switching, Staff refill, and Round 2
  scheduling were verified in earlier checkpoints.
- Procedural recoil/reload tweens apply cleanly via `.as_relative()`.

Known current issues / polish:

- The Crossbow view model still floats somewhat in the middle of the air, but it does not block aim.
- Existing navmesh warning persists: `Property agent_height is ceiled to cell_height voxel units
  and loses precision` from `scripts/systems/arena.gd:_bake_navigation`.
- No firing/reload SFX yet.

Recommended next step: finish M4 with Pack-a-Punch — duplicate the held `WeaponData` (`weapon.data = weapon.data.duplicate()`) before boosting damage/mag/fire_rate so the shared `.tres` stays clean, then mark the upgraded weapon on the HUD.

## What this is

A first-person, round-based survival shooter — Call-of-Duty-Zombies-style but reskinned to a
dark-fantasy dungeon where you fight waves of orcs (goblins) with fantasy ranged weapons. Built
in **Godot 4.6.3** and driven entirely through the **godot-ai MCP server** (the editor must be
running for any work to happen). Milestone 1 (core loop + economy) is complete and playtested.

## CRITICAL: project layout and how files reach Godot

The Godot project is **nested one level deeper** than the agent working directory:

- Agent working dir / git root: `C:\Users\sith\Code\projectbluebean\` (OUTER)
- Real Godot project (`res://`): `C:\Users\sith\Code\projectbluebean\projectbluebean\` (INNER)

The shell tools (`Bash`/`PowerShell`/`Write`/`Read`) and `Glob` operate on the OUTER tree.
**They cannot see or write the running Godot project** — `Test-Path project.godot` is False from
the shell, and files you `Write` there are invisible to the engine. Confirm the real path any
time with `game_eval` → `ProjectSettings.globalize_path("res://")`.

Therefore, **edit project files only through the godot-ai MCP:**

- GDScript: `script_create` (create/overwrite) and `script_patch` (anchored edit). Never `Write`/`Edit` a `.gd`.
- Scenes/nodes: `scene_manage`, `scene_open`, `node_create`, `node_set_property`, `script_attach`, `batch_execute`, `scene_save`.
- Text resources (`.tres`, etc.): `filesystem_manage write_text` — NOT the `Write` tool.
- Read ground truth from the engine's view with `filesystem_manage read_text` / `search`, not `Read`.

`Write`/`Read`/`Glob` are still fine for non-engine files: this `CLAUDE.md`, plans, and staging
downloaded binary assets in the OUTER tree before copying them in (see Assets below).

## Running and verifying the game

There is no build/lint/test toolchain — you drive the live editor.

- **Run:** `project_run(mode="main", autosave=false)`. Always pass **`autosave=false`**. With
  autosave on, the launch serializes the editor's stale in-memory script cache and the game
  fails to actually start (you'll see a frozen `run_id` and no real process). `scene_save`
  explicitly before running if you changed a scene.
- **Confirm it really launched:** `editor_state` → `game_capture_ready: true` and a *changing*
  `run_id`. If `editor_screenshot(source="game")` errors with "autoload never registered", the
  game isn't running.
- **Inspect runtime state:** `editor_manage game_eval` runs GDScript inside the live game (read
  ammo, orc count, animation state, etc.). Its internal `await` only progresses while the game
  window is focused; keep eval code side-effect-light or expect short awaits to need focus.
- **Logs:** `logs_read(source="game")` for runtime; `logs_read(source="editor")` for script
  parse errors. Note the editor log is **filtered to `.gd`/`.cs`** — glTF/import errors do NOT
  appear there (check the FileSystem dock icon / `.import` sidecar instead).
- `test_run` / `test_manage` exist but no tests are written.

### Known editor quirk
The live editor often fails to register the `GameState`/`Economy` autoloads as globals, so
gameplay scripts show `Identifier not found: GameState` in `logs_read(source="editor")`. This is
**cosmetic** — the game process reads `project.godot` fresh and runs fine. A one-time
`Project → Reload Current Project` (user action) clears it and also forces a full asset import.

## Architecture

Signal-driven and data-driven so later milestones slot in cleanly. Main scene: `res://scenes/world/Arena.tscn`.

- **Autoloads** (`autoloads/`, registered in `project.godot`): `GameState` (run state +
  `player_died`/`round_changed` signals) and `Economy` (points balance; `add_points`,
  `try_spend`, `can_afford`; `points_changed` signal). Systems and UI communicate through these
  signals rather than direct references.
- **Weapons are data-driven.** `scripts/weapons/weapon.gd` (`class_name Weapon`) is a generic
  hitscan weapon configured by a `WeaponData` resource (`weapon_data.gd`). A concrete weapon =
  a one-line subclass that `load()`s its `.tres` (`crossbow.gd`, `staff.gd`) plus a scene
  (`scenes/weapons/*.tscn`) and a `resources/weapons/*.tres`. Adding a weapon means new data +
  scene, not new logic.
- **Player** (`scripts/player/player.gd` on `Player.tscn`): `CharacterBody3D` with Head→Camera→
  WeaponHolder. **Semi-auto fire is event-driven in `_unhandled_input`** (one click = one shot);
  automatic fire polls in `_physics_process`. A forward `RayCast3D` (mask = interactables layer)
  feeds the HUD prompt and calls `interact()` on buyables. In the `"player"` group.
- **Orc enemy** (`scripts/enemies/orc.gd`, `class_name Orc`): `CharacterBody3D` +
  `NavigationAgent3D`, paths to the player each physics tick, melee-attacks in range, awards
  `Economy` points on death. Drives the imported goblin model's `AnimationPlayer`
  (Run / Punch / Idle / Death). In the `"orc"` group.
- **Arena** (`scripts/systems/arena.gd`): builds + bakes the `NavigationRegion3D` **in code** at
  startup (cell_size 0.25, parses static colliders), then runs an M1 cap-limited timer spawner
  (full round system is M2). Greybox two-room dungeon with a buyable door between rooms.
- **Interactables** (`scripts/interactables/`): `buyable.gd` (`class_name Buyable`, an `Area3D`
  on the interactables collision layer) with subclasses `buyable_weapon.gd` (grants/refills a
  wall weapon) and `buyable_door.gd` (frees its barrier child to open the doorway). Config is set
  in code via `_configure()`, not editor exports.
- **HUD** (`scripts/ui/hud.gd` on `HUD.tscn`): a `CanvasLayer` that finds the player by group and
  listens to `health_changed`/`weapon_changed`/`Economy.points_changed`/`GameState.player_died`.

Collision layers: 1 = world, 2 = player, 3 = enemies, 4 = interactables. Hitscan masks world+
enemies (1|4 by bit = 5); the interact ray masks interactables only.

## Conventions and gotchas specific to this MCP setup

- **`node_set_property` cannot set script-defined `@export` vars** (it validates against the
  engine class and returns `PROPERTY_NOT_ON_CLASS`). Assign such data **in code** (`load()` in
  `_ready`) or write the value into the `.tscn`/`.tres` text. This is why weapons/buyables
  configure themselves in code instead of via inspector-set exports.
- After creating a new `class_name` script via `script_create`, the editor's global class cache
  can lag — `filesystem_manage reimport` the script(s) before relying on the class/its exports.
- **Importing binary assets (models/textures):** the agent cannot deliver binaries into `res://`.
  Workflow: the user drops CC0 packs into the OUTER `...\projectbluebean\assets\`; copy the
  needed glTF + `.bin` + textures into the INNER `res://assets/...` with `PowerShell Copy-Item`
  (keep a glTF's `.bin`/textures alongside it); then the **user clicks the Godot editor window
  once** so it scans + imports (there is no MCP verb to force import headlessly). Prefer
  `.glb`/`.gltf`; avoid `.fbx`. Enemy model = Quaternius `Goblin_Male.gltf`; its `GoblinModel`
  node is rotated 180° on Y because Quaternius faces +Z while Godot `look_at` aims −Z.

## Status, resume point, and roadmap

**Current status:** Milestone 1 (core loop + economy) is complete and playtested ("fun, quite
balanced"). The orc enemy uses the imported, animated Quaternius goblin model.

**Resume here (in-progress asset pass):** KayKit weapon models are staged in
`res://assets/weapons/kaykit/` (`crossbow_2handed`, `staff`, `axe_1handed` + `.bin` + textures)
but **not yet imported or wired**. To continue: have the user focus the Godot editor so it
imports them, then replace the primitive box/cylinder viewmodels inside `scenes/weapons/Crossbow.tscn`
and `Staff.tscn` with the KayKit models, positioned/scaled in the player's `WeaponHolder`. No
**dungeon** kit has been downloaded yet — recommend KayKit Dungeon Remastered (CC0) to replace
the greybox arena.

**M1 polish backlog (optional, not yet done):** starting crossbow has finite reserve ammo with
no refill (forces the wall-buy); no fire sound or hit-marker; orc damage is a touch punishing
for a stationary player.

**Roadmap** (agreed with the user; full plan at
`C:\Users\sith\.claude\plans\i-ve-got-you-hooked-smooth-mitten.md`):

- **M2 — Round/wave system:** discrete escalating rounds (orc count + health scaling), a
  between-round breather, and round UI. Replaces the M1 cap-limited timer trickle in `arena.gd`.
- **M3 — Weapon arsenal:** staff → fire-bolt projectile, throwing axe, weapon switching (1/2/3 keys),
  reserve-ammo + reload polish, muzzle/impact SFX & VFX.
- **M4 — Zombies signature systems (fantasy reskin):** Mystery Box, Perk shrines, Pack-a-Punch
  (upgrades the held `WeaponData`).
- **M5 — Map & atmosphere:** multi-room dungeon from a real kit, barricades orcs break, torch
  lighting, fog, ambient audio, blood/impact particles.
- **M6 — Meta & game feel:** main menu, pause, settings, downed/revive, special orc types
  (ranged shaman, heavy brute), a boss round, persistent high score.

Longer-lived project context also lives in the agent memory index (`MEMORY.md`):
`project-bluebean-orc-fps`, `godot-mcp-filesystem-sandbox`, `godot-mcp-run-and-export-quirks`.
