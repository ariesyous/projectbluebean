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

Recent commits:

- `afcfadf Add weapon audio and visual impact polish`
- `ba47ccb Fix weapon procedural animation drifting on rapid fire`
- `daf786a Implement procedural weapon sway and bob`
- `7172aa6 Add throwing axe, procedural weapon animations, and ammo refills`
- `dfd4c30 Add weapon hit and reload feedback`
- `2751734 Use KayKit weapon view models`

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
- Round system: `projectbluebean/scripts/systems/arena.gd`
- Enemy: `projectbluebean/scripts/enemies/orc.gd`, `projectbluebean/scenes/enemies/Orc.tscn`

## Best Next Step

M3 polish, the M4 Mystery Box, and the M4 Perk shrines are in. Finish M4 with **Pack-a-Punch**.

Recommended next task: add a Pack-a-Punch shrine that upgrades the held weapon. **Duplicate**
the held weapon's `WeaponData` (`weapon.data = weapon.data.duplicate()`) before boosting
damage/mag/fire_rate so the shared `.tres` (loaded/cached) is never mutated. Mark upgraded
weapons (e.g. recolor `muzzle_color`, tweak `display_name`) and reflect it on the HUD.

## User Preferences / Context

The user can manually playtest when asked. They care about practical feel and are comfortable
iterating through Godot MCP. Keep changes scoped and commit verified checkpoints.
