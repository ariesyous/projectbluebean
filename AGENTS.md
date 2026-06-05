# Project Bluebean Agent Handoff

This repo is a Godot 4.6.3 first-person, round-based fantasy survival shooter. The git root is
`C:\Users\sith\Code\projectbluebean`; the actual Godot project is nested at
`C:\Users\sith\Code\projectbluebean\projectbluebean` (`res://`).

## Current State

The game is playable through the main scene, `res://scenes/world/Arena.tscn`.

Completed and committed so far:

- Core loop, economy, interactables, wall-buy Staff, buyable door, player health, and HUD.
- Imported goblin/orc enemy model with animation.
- Fixed goblin hit detection by resizing the `Orc.tscn` capsule collider.
- Wired KayKit Crossbow and Staff view models.
- Added discrete round/wave system with round UI and between-round breather.
- Added weapon slots: Crossbow on `1`, Staff on `2` once purchased.
- Added quick melee on `V` so the player has a fallback when out of ammo.
- Added a visible procedural quick-melee swing on `V` by blending a lunge/tilt into the first-person
  weapon holder sway/bob.
- Added Fire Staff projectile bolts.
- Added HUD weapon feedback: hit marker on confirmed damage and `Reloading` text during reload.
- Added procedural weapon recoil and reload animations using tweens.
- Added ammo refill affordance via a `buyable_ammo` interactable script.
- Added Throwing Axe as a third weapon (projectile with gravity) and placed its wall-buy in the starting arena.
- Added procedural weapon sway/bob and firing/reload SFX + impact VFX (M3 feel polish).
- Started M4: added the **Mystery Box** (`scripts/interactables/mystery_box.gd` +
  `scenes/interactables/MysteryBox.tscn`), placed in the far room behind the BuyableDoor.
- Added M4 **Perk shrines** (`buyable_perk.gd` base + `perk_reload`/`perk_firerate`/`perk_speed`
  subclasses on a shared `scenes/interactables/PerkShrine.tscn`): Stamina (move speed ×1.35),
  Quick Hands (reload ×0.5), Frenzy (fire rate ×1.5). Player tracks perks + `fire_rate_mult`/
  `reload_time_mult`; `weapon.gd` reads them so future weapons benefit. HUD shows owned perks.
- Added M4 **Pack-a-Punch** (`buyable_pap.gd` on `scenes/interactables/PackAPunch.tscn`):
  5000 pts upgrades the held weapon once. `weapon.pack_a_punch()` **duplicates** the WeaponData
  before boosting (damage ×2, mag/reserve ×1.5, fire_rate ×1.15, violet muzzle, "+" name,
  ammo refill) so the shared `.tres` is never mutated. HUD tints the ammo readout violet when
  the held weapon is upgraded. **This completes M4.**
- Started M5: replaced the greybox with a **KayKit Dungeon Remastered** modular map. A
  parametric builder in `arena.gd` (`_build_dungeon`/`_collect_cells`/`_place_torch`) lays floor
  tiles + perimeter walls (with collision under `NavigationRegion3D`) from room rects on the
  kit's 4-unit grid; walls auto-fill any cell edge with an empty neighbour, leaving corridors
  open. Three rooms (start / combat / vault) linked by corridors; the buyable door gates the
  vault. Added **atmosphere**: 18 wall-mounted torches with flickering lights
  (`scripts/fx/torch_flicker.gd`), a dark dungeon Environment, and fog.
- Added an M5 map-flow pass: the combat room is wider, the buyable door opens into a gated vault
  ring for late-round kiting, and Mystery Box/perks/Pack-a-Punch were moved onto that loop so
  the reward area is no longer a linear dead end.
- **M5 map/feel polish** (all in `arena.gd`, verified, playtested "great, very good"):
  - `_build_ceiling()` caps every floor cell with `ceiling_tile.gltf` at wall height — the dark
    void above the walls is gone, replaced by a beamed ceiling.
  - `_build_corner_pillars()` places a `wall_corner` buttress at every convex corner (a cell with
    two perpendicular walls + an empty diagonal) via `_corner_yaw()` (yaw calibrated from the
    piece AABB) so corners read as columns instead of two overlapping straight walls.
  - `_decorate_buyable_door()` hides the gated door's emissive box mesh and stands a
    `wall_doorway.gltf` model (stone-framed wooden door) in the gate; the box collider stays and
    the whole `BuyableDoor` still frees on purchase.
  - `_tune_environment()` raises ambient 0.35→0.85 and thins fog (the sealed ceiling darkened the
    box); `_place_torch` torches went 3.2→4.2 energy / 9→12 range. Warm, moody, readable.
- Added a single-threaded Godot Web export for GitHub Pages. The export preset lives at
  `projectbluebean/export_presets.cfg`; generated Pages artifacts live in repo-root `docs/`.
  GitHub Pages is enabled for `ariesyous/projectbluebean` from `main` / `/docs` and serves
  `https://ariesyous.github.io/projectbluebean/`.
- Fixed the first Web export's gray-screen risk by explicitly including runtime-loaded scripts,
  autoloads, weapon resources/scenes, sounds, KayKit GLTF props, and the Godot AI helper preload
  dependency in the Web preset. The live export remains single-threaded (`GODOT_THREADS_ENABLED = false`).

Recent commits (newest first):

- `90e2d0a Fix web export dependencies`
- `190cb5c Add web export for GitHub Pages`
- `e31b967 Add visible quick melee animation`
- `b6fd93a M5: add gated dungeon loop route`
- `539d4f0 Docs: backlog loop-based dungeon layout`
- `c1486d5 M5: add dungeon ambience and hit polish`
- `ec5c251 M5: torch-lit dungeon atmosphere`
- `adf6675 M5: replace greybox with KayKit modular dungeon`
- `da7399d Add M4 Pack-a-Punch weapon upgrade machine`

## Verification Notes

Use Godot MCP with the editor running:

- Run main scene with `project_run(mode="main", autosave=false)`.
- Confirm `editor_state` reports `game_capture_ready: true`.
- Use `editor_manage game_eval` for deterministic runtime checks.
- Stop play sessions with `project_manage(op="stop")` when done.

Verified most recently:

- Crossbow hit reduced enemy health `100 -> 55`.
- Fire Staff uses projectile bolts and damages after travel.
- Melee hit reduced enemy health `100 -> 45`.
- Quick melee now starts a `0.28s` first-person holder lunge/tilt animation and recovers back
  near idle; verified by runtime sampling of `WeaponHolder` position/rotation.
- Crossbow reload HUD shows `Reloading`, then returns to ammo text.
- Hit marker appears on confirmed Crossbow/projectile/melee damage and clears after its flash.
- Weapon switching and Staff re-buy/refill work without duplicating slots.
- Round 1 and Round 2 scheduling work.
- Throwing Axe projectile arcs correctly and damages enemies.
- Ammo refill interactable restores mag and reserve correctly.
- Mystery Box: rolling spends exactly 950, cycles weapon models, settles on a random weapon,
  and presenting it again grants the weapon (refills an owned one or adds a new slot and
  switches to it). Box resets to IDLE after a grab; the present timeout dismisses the weapon
  with no refund. Verified via `game_eval` and a `game` screenshot of the chest + floating prop.
- Perk shrines: each costs 1500, one-time per run. Buying all three spent 4500 and set
  move_speed 5.5->7.425, fire_rate_mult 1.5, reload_time_mult 0.5; `weapon._fire_rate_mult()`/
  `_reload_time_mult()` read those values (Crossbow effective fire rate 2.5->3.75). Re-purchase
  is blocked (empty prompt, no double-apply); the consumed shrine dims its glow; HUD shows
  "Perks: Stamina, Quick Hands, Frenzy"; perks reset on scene reload. Screenshot confirms the
  three colour-tinted shrines (blue/amber/green) in the far room.
- Pack-a-Punch: upgrading the Crossbow set damage 45->90, mag 6->9, reserve 60->90, name
  "Crossbow +", violet muzzle, and refilled ammo, while the source `crossbow.tres` stayed at
  damage 45 (duplicate confirmed). Re-purchase on an upgraded weapon is blocked (0 spent); a
  freshly equipped Staff is upgradeable independently; the ammo readout tints violet only while
  an upgraded weapon is held. Screenshot confirms the glowing-portal machine in the far room.
- M5 dungeon: builder makes 91 floor tiles + 98 walls; player lands on the floor, walls block
  movement, the navmesh bakes (orcs report reachable paths through corridors), and the buyable
  door blocks the player at the vault loop until bought, then opens. Torch-lit/fog screenshots
  confirm the mood. Runtime check: a ray from combat to loop hit `Barrier` before purchase and
  cleared after purchase; `NavigationServer3D` found a 22-point path from combat to Pack-a-Punch.
  The kit's redundant `fbx`/`obj` copies were left on disk (untracked) — only `Assets/gltf` +
  `textures` are committed.
- M5 polish: with ceiling + corner pillars + door model + brighter lights, the build still parses
  clean (only the benign `agent_height` warning), the navmesh is unaffected (ceiling/pillars/door
  model live under `DungeonProps`, not the nav region) — the door still blocks the loop (ray hits
  `BuyableDoor/Barrier`) and the combat→Pack-a-Punch path is still 22 points — and the scene runs
  at 144 FPS with 36 omni lights. User playtested and approved the look.

- Web export: installed Godot 4.6.3 export templates locally, exported with `variant/thread_support=false`
  using the no-threads Web template, and pushed to GitHub Pages. Live checks returned `200` for
  HTML and `index.wasm` (`application/wasm`); live `index.pck` after the dependency fix is
  `3,719,720` bytes. The HTML contains `GODOT_THREADS_ENABLED = false`.
- Browser visual verification could not be completed from Codex because the in-app browser/Node
  bridge failed with a local Windows sandbox spawn error. User should hard-refresh or open
  `https://ariesyous.github.io/projectbluebean/?v=90e2d0a` and manually smoke test. If a gray
  screen persists, inspect the browser console first for missing `res://` resources or WebGL errors.

Known recurring warning:

- `Property agent_height is ceiled to cell_height voxel units and loses precision`
  from `scripts/systems/arena.gd:_bake_navigation`. This existed before the latest work and is
  not currently blocking gameplay.

Known git/sandbox quirk:

- `git status` may print Windows permission warnings for `C:\Users\sith/.config/git/ignore`.
  The repo can still be clean. Git staging/commits may require escalated permission because the
  sandbox cannot write `.git/index.lock`.

## Important Paths

- Main scene: `projectbluebean/scenes/world/Arena.tscn`
- Player: `projectbluebean/scripts/player/player.gd`
- Weapon logic: `projectbluebean/scripts/weapons/weapon.gd`
- Weapon data: `projectbluebean/resources/weapons/*.tres`
- Fire bolt: `projectbluebean/scripts/weapons/fire_bolt.gd`,
  `projectbluebean/scenes/weapons/FireBolt.tscn`
- HUD: `projectbluebean/scripts/ui/hud.gd`, `projectbluebean/scenes/ui/HUD.tscn`
- Round system + dungeon builder: `projectbluebean/scripts/systems/arena.gd`
- Enemy: `projectbluebean/scripts/enemies/orc.gd`, `projectbluebean/scenes/enemies/Orc.tscn`
- M4 interactables: `scripts/interactables/mystery_box.gd` (+ `MysteryBox.tscn`),
  `buyable_perk.gd` + `perk_reload/perk_firerate/perk_speed.gd` (+ `PerkShrine.tscn`),
  `buyable_pap.gd` (+ `PackAPunch.tscn`). Perk state + `fire_rate_mult`/`reload_time_mult` live
  on `player.gd`; `weapon.gd` reads them and has `pack_a_punch()`.
- M5 dungeon: built in `arena.gd` (`_build_dungeon` / `_collect_cells` / `_add_room` /
  `_place_torch`); torch flicker in `scripts/fx/torch_flicker.gd`. Kit at
  `res://assets/dungeon/KayKit_DungeonRemastered_1.1_FREE/Assets/gltf/` (4-unit grid: floor
  tiles 4×4, walls 4×4×1; measured via AABB). Dark Environment + dimmed Sun set on `Arena.tscn`.

- Web export preset: `projectbluebean/export_presets.cfg`
- GitHub Pages output: `docs/index.html`, `docs/index.js`, `docs/index.wasm`, `docs/index.pck`,
  `docs/.nojekyll`
- Live Pages URL: `https://ariesyous.github.io/projectbluebean/`

### How the dungeon builder works (to extend the map)
`_collect_cells()` defines rooms as `Rect2i` in **tile** coords (world = tile×4) plus corridor
cells; edit/add rooms there. `_build_dungeon()` then: places a `floor_tile_large` per cell with a
per-cell floor collider; for each cell edge whose neighbour is empty, places a `wall` + a 4×4×1
box collider (rotated 90° on the two x-facing sides); and mounts a torch on every 3rd wall.
Floors/walls/colliders go **under `NavigationRegion3D`** so `_bake_navigation()` parses them
(static colliders); torches go under a `DungeonProps` node on `Arena` so they don't affect nav.
The buyable door's barrier is **not** under the nav region (navmesh spans the doorway), so don't
spawn orcs behind a closed door — current spawn markers are only in the start/combat rooms.

## Best Next Step

M5 (modular dungeon + atmosphere + map/feel polish) is **done and user-approved**. The roadmap
below is reorganized around **playtest feedback from 2026-06-05** (verbatim notes at the end). Work
it **milestone by milestone** — the user explicitly does NOT want everything one-shotted. Suggested
order is M6 → M11; confirm scope with the user before starting each.

### M6 — Map fixes & quick feel wins (small; do first)
- **Prop collision.** Hallway props (barrels, tables, crates, pillars) are placed by
  `_place_prop` / `_place_wall_prop` in `arena.gd` with **no colliders**, so the player *and*
  orcs clip straight through them. Add collision (a `StaticBody3D` + convex/box shape per prop)
  when instancing.
- **Perk shrine clipping into the food table.** In `_place_dungeon_props`, `PerkSpeed` (Arena.tscn
  at `(0,0,-34)`) overlaps `table_long_decorated_A` at `(0,0,-34.2)` — the shrine sits inside the
  table and both are walk-through. Move the table (or shrine) and make sure every shrine stands on
  clear floor with collision.
- **Shrink the orcs ~15–20%.** They tower over the player — spooky, but you can't outmaneuver them
  in narrow halls. Scale the model + collider in `Orc.tscn`, then re-verify hit detection, nav
  agent radius/height, and attack range.
- **Door open animation + SFX.** The buyable door just vanishes on purchase. Animate the new
  `wall_doorway` model (swing or slide) with a sound before `queue_free`
  (`buyable_door.gd._on_purchased`).

### M7 — Sprint / stamina (small–medium)
- Hold **Shift to sprint**: a temporary speed boost that drains a stamina meter, then a "rest &
  recover" cooldown before you can sprint again. Add stamina state + an HUD indicator. Lives in
  `player.gd` (`move_speed`, new stamina vars) + `hud.gd`. Add a `sprint` input action.

### M8 — Barricades & entry points (Zombies signature; medium–large, high value)
- Orcs currently "drop in" at `SpawnPoints` markers, which feels jarring. Replace with fixed
  **entry points** — barricaded windows / wall cavities the orcs must **break through**. Kit has
  `barrier*.gltf`, `wall_archedwindow_gated`, `wall_window_*`, `wall_broken`, `barrier_corner`.
- The player can **repair** a barricade by interacting (rebuild boards, small point reward, à la
  CoD Zombies) — the core defensive loop for rounds ~1–15. Needs barricade health, an orc
  tear-down animation/SFX, board-by-board repair, and a spawner rework in `arena.gd` that pulls
  orcs from entry points instead of the current cap-limited markers.

### M9 — Weapon overhaul & models (medium)
- **Axe rework** (`scenes/weapons/Axe.tscn` + `AxeProjectile.tscn` + axe weapon data/script):
  hold it **upright** (currently flat against the POV), throw with a **natural overhand arc**
  (currently flung sideways), and make it a **one-shot kill** — justified by a **slow reload** and
  a **10-axe capacity** that forces looping back to the start room for ammo. Rebalance so the axe
  is a real alternative; right now there's no reason not to buy the Fire Staff.
- **Real wall-buy models.** The Staff and Axe wall-buys are **blue boxes** (emissive
  `StandardMaterial3D` panels in `Arena.tscn`). Replace with the staged KayKit weapon models.
- Fire Staff is "machine-gun" fast — fun; leave as-is for now, add more weapons later.

### M10 — Enemy AI & map redesign (large; later)
- **Orc pathing** sticks on corners and is basic. Improve nav: agent radius/avoidance, path
  smoothing, corner handling, maybe local steering (`orc.gd` + `NavigationAgent3D` config).
- **Redesign the initial dungeon** to be less basic / more natural — better layout, varied rooms,
  sightlines. Hand-author or substantially improve the procedural builder in `arena.gd`.

### M11 — Meta & game feel (the old M6)
- Main menu, pause, settings, special orc types (ranged shaman, heavy brute), a boss round,
  downed/revive, persistent high score. (Decided earlier: solo death stays an instant game-over
  for now — no revive this pass.)

### Still-open earlier items
- Web export browser smoke test: hard-refresh / cache-bust
  `https://ariesyous.github.io/projectbluebean/?v=<sha>` and confirm it isn't a gray screen; if it
  is, grab the browser console error and patch the Web preset.
- Loop-feel tuning knobs (revisit during/after M6): door cost (`buyable_door.gd` = 1000) and the
  `arena.gd` spawn exports (`spawn_interval`, `max_alive`, `enemies_added_per_round`, health/speed
  scales).

### Raw playtest feedback — 2026-06-05 (verbatim intent, so nothing's lost)
- Loved it overall ("great, very good"). Wants a **Sprint** (Shift → speed boost → rest/recover).
- Map is a bit **simple/basic**; random props in the **middle of hallways** are walk-through for
  player and enemies; a **perk shrine sits inside a food table** (also walk-through). Wants the
  initial map redesigned to be better/more natural — "for now this is a good start."
- Wants **Zombies-style barricades**: enemies break through a window/wall cavity, player repairs
  walls/windows (very useful rounds ~1–15). Current "drop-in" spawns feel jarring.
- **Enemy AI** gets stuck on corners / basic pathing — OK to improve later.
- **Enemies are a bit large** / tower over the player — spooky but you can't outmaneuver them in
  narrow halls; shrink a bit.
- Wants a **door-open animation** and general polish; **Staff & Axe wall-buys are just blue boxes**.
- **Axe**: held **upright** (not flat), thrown **naturally** (not sideways), **one-shot kill**,
  **slow reload**, **capacity 10** (loop back for ammo). Hard to justify over the Fire Staff today.
- **Fire Staff** is basically a machine gun right now — fun, fine for now; more weapons later.
- Process note: **don't one-shot everything** — work systematically in achievable milestones.

## User Preferences / Context

The user can manually playtest when asked. They care about practical feel and are comfortable
iterating through Godot MCP. Keep changes scoped and commit verified checkpoints.
