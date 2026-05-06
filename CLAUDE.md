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
- **Playable level:** [scenes/main.tscn](scenes/main.tscn) — 960×180 single-screen-tall level with floor, seven platforms at varied heights, two edge walls, a wall-jump shaft (two close walls + reward platform on top), and seven slimes (4 green, 3 purple). Camera2D in player.tscn is clamped to the world bounds.
- **Player movement** ([scripts/player.gd](scripts/player.gd)): walk, jump (coyote + buffer), dash (Shift, with `power_up` SFX), shoot (J → fruit projectile from center mass), wall stick / slide / wall jump on vertical walls.
- **Combat:** Fruit Area2D ([scripts/fruit.gd](scripts/fruit.gd)) flies at 250 px/s, despawns on walls, destroys "enemy"-group Area2Ds with `explosion` SFX. Slime ([scripts/slime.gd](scripts/slime.gd)) plays `hurt` SFX on player contact (0.6s cooldown) and dies to fruit. Purple slime is a texture-only variant ([scenes/slime_purple.tscn](scenes/slime_purple.tscn)).
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
