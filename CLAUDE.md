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
- **Playable test scene:** [scenes/main.tscn](scenes/main.tscn) (also the main scene) — knight on a tiled floor with two reachable platforms; A/D/arrows move, Space/W jumps. Movement code in [scripts/player.gd](scripts/player.gd) with coyote time and jump buffering.
- Palette / tilemap-authoring tool / save format: still TBD — see [docs/playbook.md](docs/playbook.md).

## Architecture overview

Current tree:
- `assets/` — fonts, music, sounds, sprites (CC0 from Brackeys pack)
- `scenes/` — `.tscn` scene files (`main.tscn` is entry, instances `player.tscn`)
- `scripts/` — `.gd` scripts (`player.gd` is the platformer controller)
- `docs/` — project documentation (playbook + future design notes)

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

- 2026-05-01 `6214cf4` — Playable movement test scene. Pixel-perfect project settings (320×180, Nearest, snap), Input Map (move_left/right/jump on WASD/arrows/Space), `Player` scene with movement script (gravity, coyote time, jump buffer, sprite flip), `Main` scene with tiled floor + two platforms + HUD controls hint. Set as main scene.
- 2026-05-01 `294c2d3` — Imported Brackeys 2D platformer asset pack (CC0) into `assets/{fonts,music,sounds,sprites}`; original zip removed.
- 2026-05-01 `eb1d0cd` `db4b6f7` — Wrote `CLAUDE.md` (this file) + `docs/playbook.md` (bookmarks + decisions table). Library scope: links and decisions, no upstream-doc duplication.
- 2026-05-01 `755868b` — Expanded `.gitignore` to cover `.claude/`, common AI assistant configs, editor metadata, and Godot export artifacts.
- 2026-05-01 `4c6cc3e` — Initial commit. Scaffold-only Godot 4 project (`.editorconfig`, `.gitattributes`, `.gitignore`, `icon.svg`, `icon.svg.import`, `project.godot`).

## How to run

Open the project in Godot 4 and press F5 (or use the play button). Main scene is `scenes/main.tscn`. Controls: A/D or arrows to move, Space or W to jump.

## Open questions

1. Aseprite or Pixelorama for any custom art? (Drives whether we install the AsepriteWizard plugin.)
2. Palette commitment — stay free-form with Brackeys' colors, or lock to a Lospec palette and palette-swap variants later?
3. Is the knight sprite sheet's frame layout something we want to wire up as AnimatedSprite2D animations now (idle/run/jump cycle), or stay on a static frame for now?
4. Target platforms — desktop only, or mobile/web from day one?

Update the decisions table in [docs/playbook.md](docs/playbook.md) and add a journal entry here when any of these land.
