# ScratchPad

A new Godot 4 pixel art game project. Currently scaffolding only — no gameplay code yet.

This file is the project journal and architectural overview. Update it whenever:
- A meaningful change ships (commit reference + one-line entry under "Journal")
- A decision lands (update "Project decisions" in [docs/playbook.md](docs/playbook.md))
- We push to origin (refresh the journal so the public state reflects what's deployed)

## Quick links

- **Playbook & bookmarks:** [docs/playbook.md](docs/playbook.md) — Godot 4 pixel-art settings, tooling, gotchas, project decisions table
- **Repo:** https://github.com/SolutionsByCarson/ScratchPad
- **Engine:** Godot 4.x (see `project.godot` for exact version when loaded)

## Project state (2026-05-01)

- **Genre: simple platformer.**
- **Base resolution: 320×180** (16:9, integer-scales to 1080p ×6 / 4K ×12). Initial window 1280×720 (×4).
- **Tile size: 16×16** (Brackeys assets), character sprite 32×32 (knight).
- **Art:** [Brackeys CC0 platformer asset pack](assets/CREDITS.txt) — knight, world_tileset, platforms, slime variants, fruit, coin + chiptune SFX/music + PixelOperator8 font.
- **Pixel-perfect settings:** applied — Nearest filter default, `snap_2d_transforms_to_pixel`, `snap_2d_vertices_to_pixel`, viewport stretch with `keep` aspect.
- **Playable level:** [scenes/main.tscn](scenes/main.tscn) — 2880×180 single-screen-tall level (9 viewports wide) split into three sections: Section A (0–960) intro, Section B (960–1920) "sky path" with tower wall-jump shaft, Section C (1920–2880) "gauntlet". 21 platforms, 6 walls (each with its own unique `RectangleShape2D` so resizing is independent), 17 slimes (mix of green/purple, two `is_floating = true` to test mid-air variants). Camera2D in player.tscn clamped to world bounds.
- **Player movement** ([scripts/player.gd](scripts/player.gd)): walk, jump (coyote + buffer), dash (Shift, A/D-aware direction at trigger, leans 4px forward, spawns fading afterimages every 0.05s), shoot fruit (J — gated during dash), ground slam (Down/S in air; afterimages during descent; bottom-anchored squash & stretch on dash, slam descent, slam landing). Wall slide on vertical walls is **sticky** — once attached, only Jump (wall jump) or Slam exit; direction inputs are ignored. Smoothed multi-wall ricochet via 0.22s input lock, wall-ignore filter on the just-jumped wall, and 0.06s sticky-wall grace.
- **One-way platforms:** Platform1/2/4/5/6/7 have `one_way_collision = true`. Player jumps up through them, lands on top, drops through with Down. Floor and walls remain solid.
- **Combat:** Fruit Area2D ([scripts/fruit.gd](scripts/fruit.gd)) flies at 250 px/s, despawns on walls, destroys "enemy"-group Area2Ds with `explosion` SFX. Slime ([scripts/slime.gd](scripts/slime.gd)) is a state-machine AI (WANDER → CHASE → WIND_UP → JUMP → LAND): aggros only when player is within `aggro_x_range` AND `aggro_y_tolerance`, persists 30s after last sighting, jump-attacks when close (with squash/stretch), can leap off platforms and fall via gravity to ground below, ledge-avoids during wander/chase, blocked by walls, raycasts exclude the player (won't stand on his head), auto-falls if patrolling with no ground beneath. Configurable per-instance via @export. Purple variant is texture-only ([scenes/slime_purple.tscn](scenes/slime_purple.tscn)).
- **Audio singleton** ([scripts/audio.gd](scripts/audio.gd)) loops `time_for_adventure.mp3` and exposes `Audio.play_sfx(name)` for the six WAV SFX.
- Palette / tilemap-authoring tool / save format: still TBD — see [docs/playbook.md](docs/playbook.md).

## Architecture overview

Current tree:
- `assets/` — fonts, music, sounds, sprites (CC0 from Brackeys pack)
- `scenes/` — `main.tscn` (entry), `player.tscn`, `fruit.tscn` (projectile), `slime.tscn` (green enemy), `slime_purple.tscn` (purple variant)
- `scripts/` — `audio.gd` (autoload), `player.gd`, `fruit.gd`, `slime.gd`
- `docs/` — project documentation (playbook + future design notes)

Group conventions:
- `"player"` — player CharacterBody2D (added in player._ready)
- `"enemy"` — enemy Area2Ds (slime; fruit checks this group on area_entered)
- `"fruit"` — projectile Area2Ds (currently informational)

Autoloads:
- `Audio` (`scripts/audio.gd`) — `Audio.play_sfx("jump"|"hurt"|"coin"|"explosion"|"power_up"|"tap")`. Music loops automatically on game start.

Default conventions, captured here so they're not re-debated:

- **Pixel-perfect rendering** — Stretch Mode `viewport`, Nearest filter, snap transforms to pixel. Detailed settings in [docs/playbook.md](docs/playbook.md).
- **Composition over inheritance** — features are child nodes (HealthComponent, HitboxComponent, etc.), not deep class hierarchies.
- **Signals up, calls down** — parents call children directly; cross-tree communication goes through an `Events` autoload (event bus pattern).
- **TileMapLayer, never TileMap** — TileMap is deprecated as of Godot 4.3.
- **Custom Resource subclasses for save data** — type-safe, native Godot types. ConfigFile only for user settings, JSON only for tool/web interop.
- **State machines:** node-per-state FSM until a character has 5+ states; AnimationTree state machine above that.

## Workflow rules

- **Every codebase change → its own commit.** Each commit is a clean rollback point.
- **`.claude/` and other Claude-tooling files are gitignored.** This file (`CLAUDE.md`) is committed and is part of the project documentation.
- **Refresh this journal on push to origin.** The remote should always reflect the current architectural and project state.
- **Don't re-implement upstream docs.** Bookmark canonical Godot/tooling docs in the playbook; record only project-specific decisions and gotchas.

## Journal

Newest first. Format: `YYYY-MM-DD <short SHA> — what changed`.

- 2026-05-01 `1f6bbdd` — Slimes fall to ground if patrolling in thin air. Non-floating slimes in WANDER/CHASE check ground below every frame; if missing or > 2px above, transition to JUMP with zero velocity for gravity drop. Fixes mis-placed instances and dynamic ground loss.
- 2026-05-01 `c9e0b1a` — Slime raycasts exclude the player (cached `_player_rid` passed via `query.exclude`). Slimes no longer treat the player's CharacterBody2D as ground/wall during navigation.
- 2026-05-01 `84a7d41` — Slam descent spawns afterimages (reuses dash's `_spawn_afterimage` helper). Falling at 500 px/s produces a streaked tower of fading ghosts.
- 2026-05-01 `cad662b` — Dash visual polish: sprite leans 4px forward during dash; afterimages spawn every 0.05s, alpha 0.55 → 0 over 0.22s, z_index −1.
- 2026-05-01 `0bb9556` — Each wall now has its own unique `RectangleShape2D` sub_resource (`_LeftEdgeWall`, `_RightEdgeWall`, `_TallWall`, `_TallWall2`, `_TowerLeftWall`, `_TowerRightWall`). Resizing one no longer affects the others. Platforms still share `_platform`.
- 2026-05-01 `62847c8` — Extended level to 2880 wide (3x). Section B = sky path with stairstep platforms + Tower wall-jump shaft. Section C = gauntlet with 7 platforms + boss-perched slime. 14 new platforms, 2 tower walls, 10 new slimes (including 2 with `is_floating = true`). Camera limit_right → 2880; slime WORLD_MAX_X → 2864.
- 2026-05-01 `6295980` — Slimes block on vertical walls (PhysicsPointQueryParameters2D check 8px ahead in move direction during wander/chase). Likely fixes "no patrol" symptom — slimes near walls were getting pinned at world-bound clamps. Player shoot input gated on `_dash_time_left <= 0.0` so dashing isn't interrupted.
- 2026-05-01 `db4b0e7` — Slimes can jump-attack off platforms and fall to ground below. Removed pre-jump landing prediction; JUMP descent uses continuous downward raycast via `_ground_y_below`, lands at first hit (any y), updates `_initial_x`/`_initial_y` to new resting spot.
- 2026-05-01 `f6ab630` — (Reverted next commit) Slime: predict jump landing, abort if no ground there.
- 2026-05-01 `8f3ed97` — Slime wander restored (raycast was casting from inside the floor due to `hit_from_inside = false`; now casts from above the slime). Slime sprite bottom-anchored (`position.y=12`, `offset.y=-12`) so squash/stretch happens from feet.
- 2026-05-01 `5a3b8cc` — Slime AI rewrite. State machine WANDER → CHASE (axis-aware aggro: `|dx| ≤ aggro_x_range` AND `|dy| ≤ aggro_y_tolerance`, 30s persistence) → WIND_UP (pause + squash) → JUMP (gravity sim, 110 px/s horizontal, -180 px/s vertical) → LAND (recovery + squash). Per-instance @export: `is_floating`, `aggro_x_range`, `aggro_y_tolerance`, `aggro_duration`, `wander_radius`. Ledge avoidance via downward raycast (skipped when `is_floating`).
- 2026-05-01 `48ea188` — Dash uses A/D direction if pressed at trigger time (matters during wall-jump input lock where the horizontal-input override is skipped).
- 2026-05-01 `8b85ba5` — Removed wall hang / ledge grab entirely. ~123 LoC and 8 vars/constants gone. Players still get one-way platforms, wall slide/jump, slam, etc.
- 2026-05-01 `459f9c8` — Wall slide locked: dash/shoot/movement disabled while attached. New `_wall_attached` state latches when `wall_clinging` first triggers; only Jump (wall jump) or Slam exit. Direction inputs no longer break slide.
- 2026-05-01 `3a6c17e` `f00424c` — Hang lock: only Jump or Down work while hanging. Pressing into the platform also mantles up. (Both later removed in `8b85ba5`.)
- 2026-05-01 `5a9ba84` — Restored ledge hang on one-way platforms via 14px horizontal raycast (collision-based detection couldn't fire on one-way side passes). (Later removed in `8b85ba5`.)
- 2026-05-01 `2b9450a` — One-way platforms (Platform1/2/4/5/6/7 set `one_way_collision = true`). Player jumps up through, lands on top, drops through by pressing Down (2px nudge past the threshold). Floor and walls stay solid.
- 2026-05-01 `71e68a8` — Smooth multi-wall jumping. Bumped WALL_JUMP_INPUT_LOCK 0.15→0.22, added wall-ignore (the wall just jumped off is filtered by `_classify_wall_contact` until lock expires or opposite wall is touched), and 0.06s sticky wall grace so missed inputs near the wall still convert to wall jumps. Eliminates stutter when ricocheting between two close walls; single-wall climb still works after lock expires.
- 2026-05-01 `cf19d27` — Bottom-anchored sprite for stretch effects (`offset.y=-16` + `position.y=16`); bumped scale magnitudes for dash, slam descent, slam landing.
- 2026-05-01 `c5d5670` — Player feel tweaks: auto-hang on slow walk-off, slam SFX always, dash/slam squash & stretch.
- 2026-05-01 `a2b8fba` — Wall-stick now restricted to vertical walls (shape size.y > size.x). On horizontal platform sides, if the player approaches near the top edge while pressing into it, they "hang" with collision flush against the platform top; pressing jump mantles them onto the platform.
- 2026-05-01 `a999136` — Lowered music + SFX volume by ~5dB each (~40% loudness). Re-added Controls Label inside HUD with the full move list.
- 2026-05-01 `89a3e53` — Ground slam ability on Down/S. While airborne, snaps velocity to +500 px/s downward; on landing, destroys "enemy"-group nodes within 36px and plays explosion SFX (or tap on a clean miss).
- 2026-05-01 `a26c8d3` — Camera dead zone (30% horizontal, 25% vertical drag margin) so the player can wiggle in the middle without the camera chasing. Removed top limit so the camera pans up on tall jumps.
- 2026-05-01 `8c5749c` — Slime AI. Wander within ±48px of starting x at 24 px/s (random direction every 1-3s); chase player at 56 px/s when within 80px.
- 2026-05-01 `204354d` — Doc refresh for wall jump + extended level.
- 2026-05-01 `784683b` — Extended level to 960 wide. Added two edge walls, a wall-jump shaft (two close walls + reward platform), 5 new platforms across the new area, 6 new slimes (3 green + 3 purple) including one perched on Platform2 and one inside the shaft. Added `slime_purple.tscn` (texture-only variant). Camera2D in player.tscn clamped to world bounds. HUD label updated.
- 2026-05-01 `f86f131` — Mario-style wall stick / slide / wall jump in player.gd. Press into a wall mid-air to cling for 0.2s, then slide capped at 80 px/s. Press jump while clinging for a 220 px/s push along wall normal + -300 jump velocity, with a 0.15s input lock so the player visually clears the wall.
- 2026-05-01 `0a065ef` — Lowered fruit spawn from head to center mass (SHOOT_OFFSET y from -4 to +2).
- 2026-05-01 `16b77a1` — Stationary slime enemy. Area2D in "enemy" group, plays hurt SFX on player contact (0.6s cooldown), dies to fruit projectile via the existing fruit→enemy interaction. One placed in `main.tscn`.
- 2026-05-01 `ba920ac` — Fruit projectile + shoot action (J). Area2D moves at 250 px/s with 1.5s lifetime; despawns on wall hit; explodes "enemy" group Area2Ds with explosion SFX. Player added to "player" group to avoid self-collide. Spawns `tap` SFX on shoot.
- 2026-05-01 `ae36cb5` — Dash mechanic (Shift): 320 px/s for 0.15s with 0.5s cooldown, follows last facing, zeros velocity.y mid-dash, plays `power_up` SFX.
- 2026-05-01 `7f1496d` — Audio autoload (`Audio`). Loops `time_for_adventure.mp3` (sets MP3 stream loop=true at runtime) and plays SFX on demand. Player jump now plays `jump` SFX.
- 2026-05-01 `6214cf4` — Playable movement test scene. Pixel-perfect project settings (320×180, Nearest, snap), Input Map (move_left/right/jump on WASD/arrows/Space), `Player` scene with movement script (gravity, coyote time, jump buffer, sprite flip), `Main` scene with tiled floor + two platforms + HUD controls hint. Set as main scene.
- 2026-05-01 `294c2d3` — Imported Brackeys 2D platformer asset pack (CC0) into `assets/{fonts,music,sounds,sprites}`; original zip removed.
- 2026-05-01 `eb1d0cd` `db4b6f7` — Wrote `CLAUDE.md` (this file) + `docs/playbook.md` (bookmarks + decisions table). Library scope: links and decisions, no upstream-doc duplication.
- 2026-05-01 `755868b` — Expanded `.gitignore` to cover `.claude/`, common AI assistant configs, editor metadata, and Godot export artifacts.
- 2026-05-01 `4c6cc3e` — Initial commit. Scaffold-only Godot 4 project (`.editorconfig`, `.gitattributes`, `.gitignore`, `icon.svg`, `icon.svg.import`, `project.godot`).

## How to run

Open the project in Godot 4 and press F5. Main scene is `scenes/main.tscn`.

Controls:
- **A/D** or arrows — move
- **Space** or **W** or up — jump
- **Shift** — dash
- **J** — shoot fruit
- **Hold direction into a wall** while in the air — wall stick → slide; press jump while clinging for a wall jump

## Open questions

1. Wire up AnimatedSprite2D for the knight (idle/run/jump/dash/wall-cling cycles)?
2. Animate the slime (idle hop using its 12-frame sheet)?
3. Add a death/respawn system after slime contact, or keep contact as a sound-only "hurt" for now?
4. Move levels into their own scene files so we can have multiple? (`main.tscn` is currently both the entry and the level.)
5. Camera limits are hard-coded in `player.tscn` for the current 960×180 level — extract to per-level config when we add a second level.
6. Aseprite or Pixelorama for any future custom art?
7. Palette commitment — stay free-form, or lock to a Lospec palette and palette-swap variants later?
8. Target platforms — desktop only, or mobile/web from day one?

Update the decisions table in [docs/playbook.md](docs/playbook.md) and add a journal entry here when any of these land.
