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
- **Playable test scene:** [scenes/main.tscn](scenes/main.tscn) (also the main scene) — knight on a tiled floor with two reachable platforms and a stationary green slime. Movement code in [scripts/player.gd](scripts/player.gd) supports walk, jump (coyote + buffer), dash (Shift), and shoot (J → fruit projectile). Fruit is an Area2D ([scripts/fruit.gd](scripts/fruit.gd)) that destroys "enemy"-group Area2Ds. Slime ([scripts/slime.gd](scripts/slime.gd)) plays hurt SFX on player contact and dies to fruit. Audio singleton ([scripts/audio.gd](scripts/audio.gd)) loops `time_for_adventure.mp3` and plays SFX on demand.
- Palette / tilemap-authoring tool / save format: still TBD — see [docs/playbook.md](docs/playbook.md).

## Architecture overview

Current tree:
- `assets/` — fonts, music, sounds, sprites (CC0 from Brackeys pack)
- `scenes/` — `main.tscn` (entry), `player.tscn`, `fruit.tscn` (projectile), `slime.tscn` (enemy)
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

## Open questions

1. Wire up AnimatedSprite2D for the knight (idle/run/jump cycles) using the existing knight sprite sheet?
2. Animate the slime (idle hop using its 12-frame sheet)?
3. Add a death/respawn system for the player after slime contact, or keep contact as a sound-only "hurt" for now?
4. Move SFX paths into a Resource so the Audio singleton can be configured outside code?
5. Aseprite or Pixelorama for any future custom art? (Drives whether we install the AsepriteWizard plugin.)
6. Palette commitment — stay free-form with Brackeys' colors, or lock to a Lospec palette and palette-swap variants later?
7. Target platforms — desktop only, or mobile/web from day one?

Update the decisions table in [docs/playbook.md](docs/playbook.md) and add a journal entry here when any of these land.
