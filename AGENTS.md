# Project Bluebean Agent Handoff

This repo is a Godot 4.6.3 first-person, round-based fantasy survival shooter. The git root is
`C:\Users\sith\Code\projectbluebean`; the actual Godot project is nested at
`C:\Users\sith\Code\projectbluebean\projectbluebean` (`res://`).

## Current State

The game is playable through the main scene, `res://scenes/world/Arena.tscn`.

## M12 "The Undercroft" — DONE, verified, committed (2026-07-02, commit `2c97659`)

The map redesign (user-approved scope: bigger map + staged buyable doors + more KayKit variety)
is **complete and committed**. The full design reference is embedded below ("The Undercroft —
full design reference"). **Not yet done: web re-export** (the live GitHub Pages build still runs
the OLD map — re-export via the headless CLI as before) and a **user playtest**.

Verified in-game this session (run 3, clean): 231 cells; 3 doors block their lanes and clear
after purchase with correct cost deduction; stage unlock cascade `_active_entries()` 1 → 3 → 5;
all active spawn positions stay in unlocked areas; nav paths reach all 5 barricade positions,
all machines, and all boss points (endpoint gap 0.10); kiting loop paths both directions after
doors 2+3; round-1 orcs spawned at Chapel Window, broke the boards, vaulted in, crossed the
chapel, and killed an idle player (combat + entry flow work); per-area screenshots confirmed
distinct identities (stone chapel/hall, wood annex, torch-lined 76 m gallery, dirt crypt with
glowing PaP apse); 144 FPS, 376 draw calls (up from ~103 — more props + ~60 torches; desktop
fine, web lever = raise torch modulus `% 3` → `% 4` in `_build_dungeon`).

Session gotchas learned (additions to the MCP-gotchas list):
- `script_patch` params are `old_text`/`new_text` (NOT old_string/new_string).
- **The game main loop fully stalls when the window loses focus** (0 process/physics frames;
  likely pause-menu focus-out pause + helper quirk) — `game_eval` awaits hang, orcs freeze.
  A stalled run can wedge (editor says `is_playing:false`, helper still answers): stop +
  relaunch. `DisplayServer.window_move_to_foreground()` via eval can reclaim focus. Keep any
  single eval's awaits under ~8 s total.
- `project_run(mode="custom", scene="res://scenes/world/Arena.tscn")` skips the main menu.
- Godot upgraded to **4.7-stable**; plugin/project.godot upgrade artifacts committed
  separately as `1c1ecd5`.

### Script side (all in commit `2c97659`, edited via godot-ai MCP)

- `scripts/interactables/buyable_door.gd` — rewritten: `signal opened(id)`, vars
  `door_id`/`door_cost`/`door_label` read in `_configure()` (cost is no longer hard-coded 1000),
  `_on_purchased` emits `opened` first, hinge is now basis-relative.
- `scripts/systems/arena.gd` — patched:
  - `STYLE_STONE/WOOD/DIRT` consts; `_floor_cells` values are now **styles, not `true`**;
    `_add_room(rect, style)`; floors render as one MultiMesh per style
    (`floor_tile_large`/`floor_wood_large`/`floor_dirt_large`).
  - New `_collect_cells()` = the Undercroft layout (231 cells, see map below).
  - `_decorate_buyable_door()` → **replaced** by `_create_buyable_doors()` /
    `_create_buyable_door(cell,id,price,label)`: 3 code-built doors (Area3D + DoorScript +
    interact shape + Barrier/BarrierCol + wall_doorway DoorModel), parented under **Arena root**
    (never the nav region — navmesh must span doorways), connected to `_on_door_opened`.
  - Spawn gating: `_stage_unlocked=[true,false,false]`; entries carry `"stage"`;
    `_active_entries()` filter used by `_spawn_orc`; `_on_door_opened` unlocks stage 1 (any door)
    and stage 2 (door2/door3).
  - 5 barricade entries: Chapel Window (0,7)(0,1) s0; West Breach (-8,0)(-1,0) s1; Storage
    Window (8,0)(1,0) s1; Gallery Breach (-9,-5)(-1,0) s2; Crypt Breach (4,-12)(0,-1) s2.
  - Boss: `_boss_spawn_position()` — s2 crypt (-4,0,-40); s1 hall (-14,0,0); s0 chapel (0,0,26).
  - `_place_dungeon_props()` rewritten with per-area dressing (door lanes/corridor/apse/alcove
    mouths deliberately prop-free — prop colliders carve the navmesh).

### Scene + export side (also in commit `2c97659`)

- `Arena.tscn`: old `BuyableDoor` node deleted; MysteryBox (26,0,6); PerkReload (-36,0,-8)
  yaw -90; PerkFireRate (-28,0,-40) yaw -90; PerkSpeed (20,0,-40) yaw +90; PackAPunch
  (-4,0,-52); Spawn1-4 moved into the chapel. Player + WallBuy/WallBuyAxe unchanged.
  (Perk shrine yaws were NOT visually confirmed against the model's forward axis — check on
  the next playtest; interaction works regardless.)
- `export_presets.cfg`: the 18 new KayKit gltf paths appended to `export_files`.

### The Undercroft — full design reference (cell = 4 units; world = cell×4; self-contained)

The done script work in `arena.gd`/`buyable_door.gd` is its own ground truth — read those for
exact code. This section preserves the *design intent* and every hand-authored coordinate.

**Stages / rooms** (231 cells total; `_collect_cells()` in arena.gd implements exactly this):

- Stage 0 **Chapel** `Rect2i(-2,4,5,4)` — start; player (0,1,20); Staff/Axe wall-buys unchanged
  at (±9.5,1.5,18). Floor style STONE.
- Stage 1 via **Door 1 (1000, cell (0,3), node (0,2,12), "Open the Great Hall")**:
  **Great Hall** `Rect2i(-8,-2,10,5)` STONE + **Storage Annex** `Rect2i(3,-2,6,5)` WOOD, joined
  by a 2-wide arch (2,0),(2,1) WOOD. PerkReload nub (-9,-2) STONE; MysteryBox in the Annex.
- Stage 2 via **Door 2 (1750, cell (-3,-3), node (-12,2,-12), "Open the Long Gallery")** or
  **Door 3 (2500, cell (5,-3), node (20,2,-12), "Open the Storage Gate")**:
  **Long Gallery** `Rect2i(-9,-6,19,3)` STONE (76 m sightline) + **Crypt** `Rect2i(-6,-12,11,5)`
  DIRT via a 3-wide corridor (-2..0,-7) DIRT, plus the Pack-a-Punch apse (-2..0,-13) DIRT.
  Crypt perk nubs (-7,-10) and (5,-10) DIRT. Opening BOTH deep doors completes the kiting loop
  Hall→Arch→Annex→Door3→Gallery→Door2→Hall.
- Gating invariant (verified on paper): each stage region's ONLY non-barricade opening is its
  door cell(s); every door cell has exactly two opposite floor neighbours (no walk-around leak);
  every alcove/nub touches its area by exactly one edge.

**ASCII tile map** (x = -10..9 west→east; z = -13 top/deep .. 8 bottom/start. A chapel,
1/2/3 door cells, H hall, a arch, S annex, G gallery, c corridor, C crypt, P PaP apse,
n machine nub, W barricade alcove, . empty):

```
        x: -10 -9 -8 -7 -6 -5 -4 -3 -2 -1  0  1  2  3  4  5  6  7  8  9
z=-13       .  .  .  .  .  .  .  .  P  P  P  .  .  .  W  .  .  .  .  .   W=B5 Crypt Breach
z=-12       .  .  .  .  C  C  C  C  C  C  C  C  C  C  C  .  .  .  .  .
z=-11       .  .  .  .  C  C  C  C  C  C  C  C  C  C  C  .  .  .  .  .
z=-10       .  .  .  n  C  C  C  C  C  C  C  C  C  C  C  n  .  .  .  .   n(-7)=FireRate n(5)=Speed
z=-9        .  .  .  .  C  C  C  C  C  C  C  C  C  C  C  .  .  .  .  .
z=-8        .  .  .  .  C  C  C  C  C  C  C  C  C  C  C  .  .  .  .  .
z=-7        .  .  .  .  .  .  .  .  c  c  c  .  .  .  .  .  .  .  .  .   3-wide crypt corridor
z=-6        .  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G
z=-5        W  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G   W=B4 Gallery Breach
z=-4        .  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G  G
z=-3        .  .  .  .  .  .  .  2  .  .  .  .  .  .  .  3  .  .  .  .   Door2 (-3,-3) Door3 (5,-3)
z=-2        .  n  H  H  H  H  H  H  H  H  H  H  .  S  S  S  S  S  S  .   n=PerkReload nub
z=-1        .  .  H  H  H  H  H  H  H  H  H  H  .  S  S  S  S  S  S  .
z= 0        .  W  H  H  H  H  H  H  H  H  H  H  a  S  S  S  S  S  S  W   W(-9)=B2, W(9)=B3
z= 1        .  .  H  H  H  H  H  H  H  H  H  H  a  S  S  S  S  S  S  .
z= 2        .  .  H  H  H  H  H  H  H  H  H  H  .  S  S  S  S  S  S  .
z= 3        .  .  .  .  .  .  .  .  .  .  1  .  .  .  .  .  .  .  .  .   Door1 (0,3)
z= 4        .  .  .  .  .  .  .  .  A  A  A  A  A  .  .  .  .  .  .  .
z= 5        .  .  .  .  .  .  .  .  A  A  A  A  A  .  .  .  .  .  .  .   Player (0,1,20)
z= 6        .  .  .  .  .  .  .  .  A  A  A  A  A  .  .  .  .  .  .  .
z= 7        .  .  .  .  .  .  .  .  A  A  A  A  A  .  .  .  .  .  .  .
z= 8        .  .  .  .  .  .  .  .  .  .  W  .  .  .  .  .  .  .  .  .   W=B1 Chapel Window
```

**Barricade entries** (implemented in `_create_barricade_entries`; barricade sits half a tile
outside its room cell, spawn one further half-tile out):

| # | Label | Room cell | Dir | Stage | Barricade world | Spawn world |
|---|---|---|---|---|---|---|
| B1 | Chapel Window | (0,7) | (0,1) | 0 | (0,0,30) | (0,0,32) |
| B2 | West Breach | (-8,0) | (-1,0) | 1 | (-34,0,0) | (-36,0,0) |
| B3 | Storage Window | (8,0) | (1,0) | 1 | (34,0,0) | (36,0,0) |
| B4 | Gallery Breach | (-9,-5) | (-1,0) | 2 | (-38,0,-20) | (-40,0,-20) |
| B5 | Crypt Breach | (4,-12) | (0,-1) | 2 | (16,0,-50) | (16,0,-52) |

**Arena.tscn node transforms** (step 1 of the remaining work; positions are node origins):

| Node | New origin | Note |
|---|---|---|
| Player | (0,1,20) | unchanged |
| WallBuy (Staff) | (9.5,1.5,18) | unchanged |
| WallBuyAxe | (-9.5,1.5,18) | unchanged |
| BuyableDoor | **DELETE the node** | replaced by 3 code-built doors |
| MysteryBox | (26,0,6) | Storage Annex |
| PerkReload | (-36,0,-8) | hall west nub; face +x toward hall |
| PerkFireRate | (-28,0,-40) | crypt west nub; face +x |
| PerkSpeed | (20,0,-40) | crypt east nub; face -x |
| PackAPunch | (-4,0,-52) | PaP apse (deepest point) |
| Spawn1..4 | (-6,0.3,17),(6,0.3,17),(-6,0.3,27),(6,0.3,27) | fallback markers, all in chapel |

(Perk shrine facing: yaw was not verified against the model's forward axis — set it, screenshot,
and adjust; interaction works regardless of facing.)

**Boss spawn points** (`_boss_spawn_position()`, kept prop-free): stage 2 → crypt centre
(-4,0,-40); stage 1 → hall centre (-14,0,0); stage 0 → chapel south (0,0,26).

**Prop/dressing intent** (implemented in `_place_dungeon_props`; per-area identity): Chapel blue
banners + barrel/crates; Great Hall = red feast hall (2 long tables west, 2 `column` cover at
z=0, low `barrier`, keg); Annex = green storage (kegs, crates, `shelf_large`, `chest`); Gallery =
yellow, 4 `column` on the z=-20 centreline for cover along the sightline + rubble in corners;
Crypt = white/gold (4 `pillar_decorated` colonnade, trunk/chest, `chest_gold` + broken table by
the apse). Rule: prop colliders carve the navmesh — door lanes, arch lane, corridor, apse
approach, alcove and nub mouths must stay prop-free.

**Verification details** (step 3; all via `editor_manage game_eval` after
`project_run(autosave=false)` + ~6 s wait, game window focused):

- `get_tree().current_scene._floor_cells.size()` == 231; `_entry_points.size()` == 5;
  `_active_entries().size()` == 1.
- Door gating per door: `direct_space_state.intersect_ray` across the door cell
  (door1 (0,1,10)→(0,1,14); door2 (-12,1,-10)→(-12,1,-14); door3 (20,1,-10)→(20,1,-14))
  hits a StaticBody pre-purchase; `Economy.add_points(10000)` then call `interact(player)` on
  the door node (named `BuyableDoor_door1` etc., children of Arena); ~1 s later the ray is clear
  and `_active_entries()` grew (3 after door1, 5 after door2 or door3).
- Nav: `NavigationServer3D.map_get_path(map, from, to, true)` non-empty + endpoint within ~1 m
  for: each barricade's `get_orc_attack_position()`, each machine, each boss point, the PaP apse;
  after doors 2+3, loop paths both directions, e.g. (-12,0.5,-8)→(20,0.5,-16) and reverse.
- Spawn gating: with only door1 open, force ~20 `_spawn_orc()` calls and assert no enemy
  `global_position.z < -12`.
- Boss: `_boss_spawn_position()` per stage matches the table above.
- Perf: `editor_manage monitors_get` FPS + draw calls (~60 torch lights now vs ~40; if web FPS
  suffers later, raise the torch modulus `torch_i % 3` → `% 4` in `_build_dungeon`).
- `editor_screenshot` in each area (set `GameState.is_game_over=true` + hide overlay trick from
  the MCP-gotchas section for static shots).

Completed and committed so far:

- **Enemy animation / weapons / hitbox fixes (post-M10 playtest, 2026-06-05):**
  - All enemy models (Wizard/Viking/Knight/Goblin) share **one Quaternius rig** with clips
    `Idle, Walk, Run, Run_Carry, Walk_Carry, Punch, SwordSlash, Shoot_OneHanded, Jump, Death, …`.
    The scripts had been calling clip names that don't exist in that rig, so `AnimationPlayer.play()`
    was a no-op and the model froze in its rest pose. Fixed: **boss & brute glide**
    (`"Running_A"` → `Run_Carry`, and added Run/Run_Carry to the loop-mode list so it actually
    loops) and **mage casting** (`"Cast"`/`"Spellcast_Shoot"` → `Shoot_OneHanded`). Armed melee
    enemies now swing with `SwordSlash`.
  - Fixed a **latent bug in `boss.gd`**: `_barricade_target` was used/assigned but never declared.
  - **Equipped weapons** on enemies via a code-added `BoneAttachment3D` on the `Fist.R` bone
    (`_equip_weapon()` + `_find_skeleton()` in boss/brute/shaman): `staff.gltf` on the mage,
    `axe_1handed.gltf` on the Knight (Brute) and Viking (Boss). Grip is exposed as
    `WEAPON_GRIP_POS/ROT/SCALE` consts at the top of each `_equip_weapon()`. **Tuned** so the axe
    stands upright in the fist (pos `(0,-0.15,0)`, rot `(180,0,0)`, scale `0.55`) and the staff is
    held vertically with the glowing orb up by the shoulder (pos `(0,0.06,0)`, rot `(180,0,0)`,
    scale `0.6`). All enemies share the rig, so the axe transform is identical for Brute and Boss.
  - Fixed **enemy "death slide"**: `_on_velocity_computed()` (the NavigationAgent avoidance
    callback) had no `_dead` guard, so a killed enemy kept being pushed by `move_and_slide()` in its
    last travel direction during the death animation. Added `if _dead: return` to all four enemy
    scripts (orc/brute/shaman/boss).
  - Fixed **mage headshots not registering**: the Wizard head bone sits at y≈2.02 but the Shaman
    capsule topped out at exactly y=2.0, so the head + hat were above the collider. Resized the
    `Shaman.tscn` capsule to radius 0.55 / height 2.7 / offset y 1.35; raycasts now register from
    0.8 m up through 2.6 m (head + hat). Verified via `game_eval`.
- **Web performance pass + export-list repair (2026-06-05):**
  - The web build (GitHub Pages, single-threaded WASM, 1 core) lagged. First attempt — **web-only
    GPU reductions** (`scaling_3d/scale.web=0.75`, half the torch lights, ambient bump) — was
    **reverted**: it made the dungeon dark and did NOT improve FPS, which confirmed the bottleneck
    is **CPU (draw-call submission), not GPU/fill-rate**.
  - **Real fix — MultiMesh draw-call reduction** (`arena.gd`): the dungeon used to spawn one
    `MeshInstance3D` per floor/wall/ceiling/corner tile (~336 separate draw calls). `_build_dungeon`
    now collects per-tile transforms and draws each tile type as a single `MultiMeshInstance3D` via
    helpers `_extract_tile_mesh()` / `_first_mesh_instance()` / `_add_tile_multimesh()`. Result
    (verified in-editor): Floor 117 + Wall 80 + Ceiling 117 + Corner 22 tiles now render in **4 draw
    calls instead of 336** (total scene draw calls ~400 → ~103). Collision is untouched (still
    individual `CollisionShape3D`s under `NavigationRegion3D`), and the bake parses static colliders
    only (`PARSED_GEOMETRY_STATIC_COLLIDERS`), so the navmesh is unaffected (22-point path verified).
  - **Fixed the web HUD "tofu" glitch** (`hud.gd` `_apply_hud_overhaul` / repair indicator): the
    M10 overhaul used Unicode glyphs (crosshair `⊹` U+22B9, hit marker `✕`, repair `○◔◑◕●`). The
    web build has **no OS font fallback**, so each rendered as a tofu box showing its hex codepoint
    (the user saw the crosshair as "a box that says 22 / 69" = U+22B9). Replaced all with ASCII
    (`+`, `X`, `.oO0#`). Any future HUD text must stay ASCII or ship an embedded font.
  - **Repaired the badly-stale Web export file list.** `export_presets.cfg` used a hand-curated
    `export_files` list (because `load(KIT + "...")` string-concat loads aren't followed by Godot's
    dependency scanner) that predated M5-polish/M8/M10/M11. It was missing the **main scene
    (`MainMenu.tscn`)**, `PauseMenu.tscn`, all M10 enemies (Boss/Brute/Shaman/ShamanFireball +
    scripts + Viking/Knight/Wizard models), combat audio (`orc_*`/`player_hurt.wav`), and
    runtime-loaded dungeon pieces (`ceiling_tile`, `wall_corner`, `wall_doorway`,
    `wall_archedwindow_open`). A rebuild without these would have gray-screened. Found every
    runtime `load()`/`preload()` target by grep and added the missing ones.
  - **Rebuilt + committed the GitHub Pages build** via headless CLI export
    (`Godot_v4.6.3-stable_win64_console.exe --headless --path . --export-release "Web"` to
    `../docs/index.html`). `index.pck` grew 3.7MB→4.84MB (M10 content now present);
    `GODOT_THREADS_ENABLED = false` preserved. Godot editor binary lives at
    `C:\Users\sith\Code\projectgencom\Godot_v4.6.3-stable_win64.exe`; templates `4.6.3.stable`
    are installed.
- **M10 Polish Pass (HUD, Audio, Vaulting, Bosses)**:
  - Replaced the enemy models with `Ultimate Animated Character Pack`.
  - Added a Boss enemy (Viking Warlord, `boss.gd`) that has 2000 HP and spawns minions when hit.
  - Added a Shaman enemy (Wizard) that shoots fireballs.
  - Revamped the HUD with crisp outlines, shadows, and better scaling for an intense shooter vibe.
  - Synthesized and added spatialized combat sound effects (`orc_attack.wav`, `orc_hurt.wav`, `orc_death.wav`, `player_hurt.wav`) natively into all enemy/player scripts.
  - Implemented dynamic Barricade Vaulting animations. When a barricade breaks, enemies leap over the window sill into the arena using a sine wave interpolation and the `Jump` animation.
- **M8 barricades / entry points are done and user-approved.**
  - Added `scripts/interactables/barricade.gd` (+ `.uid`), created dynamically from
    `arena.gd`.
  - `arena.gd` now adds three one-cell enemy entry alcoves and three barricades:
    `StartWindow`, `EastBreach`, `WestBreach`.
  - Round spawning now prefers these entry points. Spawned orcs get assigned to a barricade while
    it is still boarded.
  - `orc.gd` has barricade attack behavior: stop at the boards, face the barricade, restart the
    existing `Punch` animation, and remove one board per hit.
  - Barricades have 5 boards. Orc hits remove one board. Player repair restores one board and
    awards `+10` points.
  - Repair is **hold-F**, not tap: `player.gd` now supports hold-capable interactables via
    `uses_hold_interact()` / `hold_interact(player, delta)` / `cancel_hold_interact()`.
  - `hud.gd` creates a small runtime `RepairProgress` label under the prompt and shows progress
    with `○` / `◔` / `◑` / `◕` / `●` while each plank repairs.
  - Barricade collision uses layer `16` for the normal board blocker. Player and orcs collide with
    it, but weapon rays ignore it, so the player can shoot orcs through boarded windows.
  - Added a player-only spawn threshold blocker on layer `32` at each entry. Player collision mask
    includes layer `32`; orcs do not. When boards are broken, orcs can enter but the player cannot
    walk into the spawn alcove and trap themselves.
  - Each barricade also instantiates `wall_archedwindow_gated.gltf` as an `EnemyEntryFrame` visual
    so the hole reads as a monster entry/window, not a normal doorway. Its imported collisions are
    disabled in script; gameplay collision comes from the explicit blockers.
- **M9 axe rework slice is done and verified.**
  - `resources/weapons/axe.tres`: damage `65 -> 160`, fire rate `1.5 -> 0.65`, reserve
    `10 -> 9` (total capacity = 10 including loaded axe), reload `0.8 -> 2.25`, projectile speed
    `22 -> 24`.
  - `scenes/weapons/Axe.tscn`: first-person KayKit axe is no longer flat; it is held more upright
    and angled lower/right in the view.
  - `scripts/weapons/axe.gd`: overrides `_spawn_projectile()` to launch from a right-hand offset
    with a slight upward overhand bias, without changing Fire Staff projectiles.
  - `scripts/weapons/axe_projectile.gd`: gravity raised to `20`, spin uses local
    `rotate_object_local(Vector3.RIGHT, spin_rate * delta)`, and the projectile model is posed in
    `_ready()`.
- **Important typo fixed:** a stray `ipp` accidentally prefixed the `var hold_target: bool = ...`
  line in `player.gd`, causing `Unexpected identifier "ipp" in class body` on Play. It has been
  removed and the game launched successfully afterward.

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
- **M6 map fixes & quick feel wins** (verified via `game_eval`, navmesh paths re-checked):
  - `_add_prop_collider()` gives every floor prop a box collider sized to its mesh AABB, parented
    under `NavigationRegion3D` so the bake **carves around it** (player + orcs are blocked but orcs
    still route around, no trapping). **Lesson:** carving a prop in a 4-wide corridor disconnects
    the navmesh — the two vault-arm barrels had to move to the wide combat room; keep narrow
    corridors/arms prop-free.
  - Fixed the perk-shrine-in-table overlap: `table_long_decorated_A` moved out of the `PerkSpeed`
    shrine to the vault back-nub wall at `(-4,0,-37.2)`, clear of the PaP approach.
  - Orcs shrunk ~18% in `Orc.tscn` (model ×0.82, capsule radius 0.95→0.78 / height 3.0→2.46,
    re-centered) — less towering, easier to slip past.
  - Buyable door now swings open on a left-edge hinge pivot with an `impact.wav` thunk before
    freeing (`buyable_door.gd`); collider frees instantly so the path opens at once. `arena.gd`
    names the door model `DoorModel` for the swing to grab.
- **M7 sprint / stamina** (verified via `game_eval`): hold **Shift** (`sprint` input action) to move
  at `move_speed * 1.6` while a stamina meter drains (`player.gd` `_update_stamina`); emptying it
  sets `_exhausted` and locks you to base speed until stamina **fully** recovers (a forced rest).
  Stamina regens after a short delay and not while standing still. New `stamina_changed` signal
  drives a HUD `StaminaBar` (green normally, red when exhausted) added above the health bar in
  `HUD.tscn`/`hud.gd`. Tunables are `@export`s on `player.gd`.
- Added a single-threaded Godot Web export for GitHub Pages. The export preset lives at
  `projectbluebean/export_presets.cfg`; generated Pages artifacts live in repo-root `docs/`.
  GitHub Pages is enabled for `ariesyous/projectbluebean` from `main` / `/docs` and serves
  `https://ariesyous.github.io/projectbluebean/`.
- Fixed the first Web export's gray-screen risk by explicitly including runtime-loaded scripts,
  autoloads, weapon resources/scenes, sounds, KayKit GLTF props, and the Godot AI helper preload
  dependency in the Web preset. The live export remains single-threaded (`GODOT_THREADS_ENABLED = false`).

Recent commits (newest first):

- `1e5779a Fix M7 regression: restore per-frame player updates`
- `f7b9e16 M7: sprint + stamina`
- `5091cee M6: prop collision, shrine/table fix, smaller orcs, door swing`
- `4f24697 M5 polish: ceiling, corner pillars, door model, brighter lighting`
- `8bc1f06 Docs: update web export handoff`
- `90e2d0a Fix web export dependencies`
- `190cb5c Add web export for GitHub Pages`
- `e31b967 Add visible quick melee animation`
- `adf6675 M5: replace greybox with KayKit modular dungeon`

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

- M8 barricades:
  - Game launched successfully after the `ipp` typo fix in `player.gd`.
  - Three barricades spawn and are in group `barricade`.
  - Orcs assigned to intact barricades path to the board face and use `Punch` to damage them.
  - Barricade damage reduces board count one at a time.
  - Hold-repair: partial hold does not add a board; after enough held time, one board appears and
    `Economy.points` increases by `10`.
  - Runtime layer check: each barricade has board blocker layer `16`, player-only blocker layer
    `32`, and `EnemyEntryFrame` visual present. Player collision mask was `49`
    (`world + layer 16 + layer 32`); spawned orc mask was `17` (`world + layer 16`), so orcs can
    enter but the player cannot step into spawn alcoves.
  - When boards are broken (`_intact_boards = 0`), normal board blocker disables but the
    player-only blocker remains enabled.
  - Shooting-through-board behavior was verified by collision masks: weapon hitscan still uses mask
    `1 | 4` (world + enemies), so it ignores layer `16`/`32` barricade blockers.
- M9 axe rework:
  - `axe.tres` loads as damage `160`, fire rate `0.65`, mag `1`, reserve `9`, reload `2.25`,
    projectile speed `24`.
  - Instantiated `Axe.tscn` reports ammo `1 / 9`; model transform is upright/angled instead of flat.
  - Direct `AxeProjectile` hit test against a 100-health orc set health to `-60` and `_dead = true`.

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
- Editor logs may still echo the old fixed parse error
  `Unexpected identifier "ipp" in class body` for `player.gd:321` even after clearing logs. The
  actual stray `ipp` has been removed. Trust a fresh successful `project_run`, `game_capture_ready:
  true`, and live `game_eval` over that stale editor buffer if it appears again.

Known git/sandbox quirk:

- `git status` may print Windows permission warnings for `C:\Users\sith/.config/git/ignore`.
  The repo can still be clean. Git staging/commits may require escalated permission because the
  sandbox cannot write `.git/index.lock`.

## MCP workflow gotchas (learned the hard way — read before editing)

- **Edit `res://` files only through the godot-ai MCP** — `script_create`/`script_patch` for `.gd`,
  scene/node verbs + `scene_save` for `.tscn`, `filesystem_manage write_text`/`read_text` for
  `.tres` and ground-truth reads. The shell/`Write`/`Read` tools see the OUTER tree, which the
  engine can't load from. (OUTER-tree files like `AGENTS.md`, `CLAUDE.md`, `docs/`,
  `export_presets.cfg` are fine to edit with normal file tools.) Full rules live in `CLAUDE.md`.
- **A "wedged" play session is almost always a parse error.** Symptom: `project_run` returns a
  *frozen* `run_id`, the game log buffer never clears, and `game_eval`/`editor_screenshot` report
  "capture never registered". The editor is still running the last good *cached* build because the
  new script failed to compile. Fix: check `logs_read(source="editor")` for a `Parse Error`, fix it,
  then (if it persists) have the user do **Project → Reload Current Project** to clear the cache.
- **`game_eval` needs the game window focused**, and capture registration lags boot — wait ~6s after
  `project_run` (a backgrounded `sleep` works) before evaluating. `Input.action_press(...)` takes a
  frame to register, so warm it with one throwaway call before reading the resulting state.
- **GDScript typing:** `var x := <expr>` cannot infer from an untyped (Variant) value such as a loop
  var (`for n in array`, `stack.pop_back()`). Cast (`var mi := n as MeshInstance3D`) or annotate
  (`var t: Transform3D = ...`). A parse error here silently breaks the *whole* script.
- **`script_patch` near the end of a function:** when inserting a new `func` right after another
  function's last statement, make sure you don't strand that function's trailing lines after the new
  `return` as dead code. This exact mistake moved `_update_weapon_visuals`/`_handle_weapon_input`/
  `_update_interaction`/`_update_health_regen` out of `_physics_process` and silently broke weapon
  bob, auto-fire, buying, and health regen.
- **Navmesh carving:** colliders parented under `NavigationRegion3D` are carved by the bake, so a
  prop in a 4-wide corridor/arm disconnects the mesh. Keep narrow lanes prop-free and re-verify with
  `NavigationServer3D.map_get_path(map, from, to, true)` to a known target after changing geometry.
- **Verify deterministically with `game_eval`** (read health/stamina/positions, call functions, run
  `map_get_path`) rather than relying on screenshots — the running game is dark and the death overlay
  (`HUD/Root/GameOver`) dims captures. To inspect a static scene, set `GameState.is_game_over = true`
  + free orcs + `player.set_physics_process(false)` + hide the overlay, then screenshot.

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
- M5 polish + M6 helpers (all in `arena.gd`): `_build_ceiling` / `_build_corner_pillars` /
  `_corner_yaw` / `_decorate_buyable_door` / `_add_prop_collider` / `_tune_environment`. Door swing
  in `scripts/interactables/buyable_door.gd`.
- M7 sprint/stamina: `player.gd` (`_update_stamina`, `stamina_changed` signal, `@export` tunables) +
  `hud.gd` `StaminaBar` + `HUD.tscn`; `sprint` input action (Shift) is in `project.godot`.
- M8 barricades: `scripts/interactables/barricade.gd`, `arena.gd` (`_add_barricade_alcoves`,
  `_create_barricade_entries`, `_add_barricade_entry`, `_spawn_orc` entry assignment),
  `orc.gd` (`assign_barricade`, `_update_barricade_attack`, `_attack_barricade`), `player.gd`
  hold-interaction path, and `hud.gd` runtime `RepairProgress` label.
- M9 axe slice: `resources/weapons/axe.tres`, `scenes/weapons/Axe.tscn`,
  `scripts/weapons/axe.gd`, `scripts/weapons/axe_projectile.gd`.

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

**Current resume point (2026-07-02): M12 "The Undercroft" is DONE, committed (`2c97659`), and
the web build is re-exported + LIVE on GitHub Pages (`2ebb73e`, pck 5,075,864 bytes verified by
content-length; exported with Godot 4.7 + freshly installed 4.7 web nothreads templates —
editor binary `C:\Users\sith\Code\projectgencom\Godot_v4.7-stable_win64.exe`, the old 4.6.3
binary is gone).** Next, in order: (1) **user playtest** — desktop + a hard-refresh of
`https://ariesyous.github.io/projectbluebean/?v=2ebb73e` (door costs/pacing, perk shrine
facing, hall/gallery cover feel, crypt darkness, web FPS on the bigger map); (2) the
pre-existing backlog below (enemy AI corner-snagging — note the Explore findings: enemy capsule
radii 0.55–1.1 exceed the baked navmesh agent_radius 0.5 and `path_postprocessing=1`
(edge-centered) hugs corners; web CPU levers incl. torch modulus; content/meta).

**Previous resume point:** M1–M10 are done and committed, plus a **main menu + pause menu**
(`scenes/ui/MainMenu.tscn` is now the project's main scene; `PauseMenu.tscn`). The 2026-06-05
session fixed enemy animations, equipped + posed enemy weapons, removed the death-slide, fixed the
mage headshot hitbox, added a **web performance pass**, repaired the stale Web export file list, and
**rebuilt the GitHub Pages build** (see Completed list for all detail). Work **milestone by
milestone** — the user explicitly does NOT want everything one-shotted, and prefers verified,
committed checkpoints.

### Done (detail in the Completed list above)
- **M1–M5:** core loop/economy, weapon arsenal, Mystery Box / perks / Pack-a-Punch, modular KayKit
  dungeon + atmosphere + map polish.
- **M6** map fixes & feel, **M7** sprint/stamina, **M8** breakable/repairable barricades + entry
  points, **M9** axe rework + real KayKit wall-buy models, **M10** HUD/audio/barricade-vaulting +
  **boss & enemy types** (Boss/Viking, Shaman/Wizard caster, Brute/Knight).
- Enemy animation/weapon/grip/hitbox fixes + web perf + export repair (this session).
- Main menu + pause menu exist; single-threaded Web build live on GitHub Pages.

### Open / prioritized next steps
1. **Verify the rebuilt web build in a browser** (exports were validated only by exit code + pck
   growth + in-editor checks, never a live web smoke test). Latest deployed build is **sha
   `e773373`** (MultiMesh + HUD-glyph fix). Hard-refresh / cache-bust
   `https://ariesyous.github.io/projectbluebean/?v=e773373`; confirm: menu loads, a round plays,
   bosses/shamans/brutes appear **holding their weapons**, combat audio works, the **crosshair is a
   clean `+`** (not a tofu box), brightness is normal, and it feels **smoother** than before the
   MultiMesh pass. If gray, open the browser console for a missing `res://` resource → add it to
   `export_presets.cfg`'s `export_files` and re-export (the list is hand-curated because
   `load(KIT + "...")` string-concat loads are invisible to Godot's dependency scanner).
2. **More web performance if STILL laggy after the MultiMesh pass** (single WASM core → CPU-bound;
   GPU cuts already proven useless). The dungeon draw-call win is done (~400 → ~103 draw calls).
   Remaining CPU levers, roughly in order:
   - **Lower `physics/common/physics_ticks_per_second` on web** (e.g. 60→30 via a `.web` override).
     Enemy nav + `NavigationAgent3D` avoidance (RVO) runs every physics tick and is heavy. Watch
     player feel — player movement/aim is partly physics-tick-bound.
   - **Disable `NavigationAgent3D` avoidance (RVO)** on the enemies (`avoidance_enabled=false` in
     the enemy scenes / `_ready`): removes per-agent RVO each frame. Enemies may clump more.
   - **Stop shipping the `_mcp_game_helper` autoload in the web build.** It's editor tooling
     (`addons/godot_ai/runtime/game_helper.gd`, registered as an autoload in `project.godot`) and
     has no purpose in a released game — likely idle, but it shouldn't ship. Don't remove the
     autoload outright (the editor MCP needs it); gate its work on `not OS.has_feature("web")` or
     exclude it from the Web preset.
   - **MultiMesh the 32 torch models** too (smaller win), or cap `max_alive` enemies.
3. **Enemy AI / pathing.** Orcs still snag on corners — tune `orc.gd` + `NavigationAgent3D` (agent
   radius, avoidance, path postprocessing/smoothing).
4. **Map / level design.** The procedural dungeon in `arena.gd` is functional but basic — vary
   rooms, sightlines, and flow, or hand-author a stronger layout.
5. **Content & meta.** More weapons (only Fire Staff is really worth buying today), more enemy
   variety, a settings menu, persistent high score.

### Loop-feel tuning knobs (revisit anytime)
- Door cost (`buyable_door.gd`) and the `arena.gd` spawn exports (`spawn_interval`, `max_alive`,
  `enemies_added_per_round`, `health_scale_per_round`, `speed_scale_per_round`).

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

### Best Next Step

See **"Open / prioritized next steps"** under the `## Best Next Step` section above — that is the
authoritative, up-to-date roadmap. In short: (1) browser-verify the latest web build (sha
`e773373`); (2) if it's still laggy, the dungeon MultiMesh draw-call pass is already done, so move
to the remaining CPU levers (physics tick on web, disable enemy RVO avoidance, stop shipping the
`_mcp_game_helper` autoload); then (3) enemy AI/pathing, map design, and more content. The enemy
animation/weapon/grip/hitbox fixes, the HUD tofu-glyph fix, the MultiMesh perf pass, and the web
export repair are all **done and committed** this session — don't redo them unless playtest
feedback asks.

## User Preferences / Context

The user can manually playtest when asked. They care about practical feel and are comfortable
iterating through Godot MCP. Keep changes scoped and commit verified checkpoints.
