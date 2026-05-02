# ScratchPad Playbook — Godot 4 Pixel Art

Bookmarks + project decisions. Anything in the canonical docs lives at the link, not here.

## Project decisions

| Decision | Choice | Notes |
|---|---|---|
| Genre / pillars | Simple platformer | Locked 2026-05-01. |
| Base resolution | **320×180** | ×6 → 1080p, ×4 → 720p initial window. |
| Palette | TBD (using Brackeys pack as-is) | Candidates if/when we lock: [PICO-8](https://lospec.com/palette-list/pico-8), [DB16](https://lospec.com/palette-list/dawnbringer-16), [AAP-64](https://lospec.com/palette-list/aap-64), [Resurrect-64](https://lospec.com/palette-list/resurrect-64). |
| Tile size | **16×16** (Brackeys tileset). Knight character is 32×32 sheet. | |
| Animation cadence | TBD | Knight + slime sheets are still on static frame 0. Wiring AnimatedSprite2D is open work. |
| Audio | `Audio` autoload (`scripts/audio.gd`) | Single AudioStreamPlayer for music (looping MP3) + single AudioStreamPlayer for SFX. SFX collide if triggered rapidly — pool when that becomes audible. |
| Group conventions | `"player"`, `"enemy"`, `"fruit"` | Set in each script's `_ready()`. Fruit checks `is_in_group("enemy")` to decide what to destroy. |
| Art tool | TBD | Aseprite (standard) or [Pixelorama](https://github.com/Orama-Interactive/Pixelorama) (free, FOSS, made in Godot). |
| Tilemap authoring | Direct sprite + StaticBody2D for now | Escalate to TileMapLayer or [LDtk](https://ldtk.io) when level count grows. |
| Save format | Custom Resource (when needed) | Type-safe, native types. ConfigFile for user settings. |
| Source assets | [Brackeys CC0 platformer pack](../assets/CREDITS.txt) | knight, slimes, fruit, coin, world_tileset, platforms, chiptune SFX/music, PixelOperator8 font. |

Update this table as choices land — and commit each change.

## Mandatory Godot 4 project settings (pixel-perfect)

When we wire these up in `project.godot`, the canonical paths are:

```ini
[rendering]
textures/canvas_textures/default_texture_filter = 0   # Nearest

[display]
window/size/viewport_width = 320     # base render resolution
window/size/viewport_height = 180
window/stretch/mode = "viewport"     # render at base res, scale to window
window/stretch/aspect = "keep"       # letterbox to preserve ratio

[rendering]
2d/snap/snap_2d_transforms_to_pixel = true
2d/snap/snap_2d_vertices_to_pixel = true   # only if rotated/scaled sprites still shimmer
```

Reference: [GDQuest pixel art setup](https://www.gdquest.com/library/pixel_art_setup_godot4/), [itch.io: Godot 4.4 Settings for Pixel Art](https://itch.io/blog/806788/godot-44-settings-for-pixel-art).

## Known traps to avoid

- **Smooth Camera2D + pixel snap fight each other.** Default `position_smoothing` produces visible jitter on snapped sprites. If/when we want smooth camera, use the SubViewport approach: [voithos/godot-smooth-pixel-camera-demo](https://github.com/voithos/godot-smooth-pixel-camera-demo). Don't waste time fighting the built-in smoothing first.
- **TileMap is deprecated as of 4.3.** Always use [TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html). Editor has a one-click conversion if we ever inherit a TileMap.
- **Rotating sprites breaks pixel grid.** Snap rotations to 90° or pre-render frames.
- **TTF/anti-aliased font in pixel UI ruins the look.** Use a bitmap font or pixel-style TTF with hinting disabled.
- **`texture_filter` inheritance pitfall.** A child can inherit Linear from a parent CanvasItem even when the project default is Nearest. Set explicitly per-node or on the parent CanvasLayer.

## Bookmarks

### Godot 4 docs (canonical)
- [Project Settings reference](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html)
- [2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)
- [TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)
- [Singletons (Autoload)](https://docs.godotengine.org/en/latest/tutorials/scripting/singletons_autoload.html)
- [Using AnimationTree](https://docs.godotengine.org/en/latest/tutorials/animation/animation_tree.html)
- [CharacterBody2D](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html)

### Tutorials worth bookmarking
- [GDQuest pixel art setup for Godot 4](https://www.gdquest.com/library/pixel_art_setup_godot4/) — settings cheatsheet
- [GDQuest save/load](https://www.gdquest.com/library/save_game_godot4/) — Resource-based save/load
- [GDQuest event bus pattern](https://www.gdquest.com/tutorial/godot/design-patterns/event-bus-singleton/) — autoload signal hub
- [GDQuest finite state machine](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/) — node-per-state FSM
- [Kids Can Code: Y-sort](https://kidscancode.org/godot_recipes/4.x/2d/using_ysort/index.html), [coyote time](https://kidscancode.org/godot_recipes/4.x/2d/coyote_time/index.html), [save/load](https://kidscancode.org/godot_recipes/4.x/basics/file_io/index.html)
- [Catlike Coding: True Top-Down 2D](https://catlikecoding.com/godot/true-top-down-2d/) — full top-down lighting/shadow series

### Tools
- Aseprite — [aseprite.org](https://www.aseprite.org/)
- Pixelorama (free, FOSS) — [github.com/Orama-Interactive/Pixelorama](https://github.com/Orama-Interactive/Pixelorama)
- [AsepriteWizard](https://github.com/viniciusgerevini/godot-aseprite-wizard) — `.aseprite` → AnimationPlayer/AnimatedSprite/SpriteFrames
- [LDtk](https://ldtk.io) — modern level editor + [godot-ldtk-importer](https://github.com/heygleeson/godot-ldtk-importer)
- [Tiled](https://www.mapeditor.org/) + [Godot4-TiledImporter](https://github.com/feendrache/Godot4-TiledImporter)
- Lospec palettes — [lospec.com/palette-list](https://lospec.com/palette-list)

### Audio
- [Furnace](https://tildearrow.org/furnace/) — multi-system chiptune tracker (NES, Genesis, etc.)
- [Bosca Ceoil Blue](https://yurisizov.itch.io/boscaceoil-blue) — beginner-friendly chiptune
- [ChipTone](https://sfbgames.itch.io/chiptone) — free SFX generator (sfxr-style, better UI)
- [jsfxr](https://sfxr.me) — browser-based sfxr for quick SFX

### Free / cheap art
- [Kenney.nl](https://www.kenney.nl/assets) — CC0
- [OpenGameArt](https://opengameart.org/) — verify license per asset
- [itch.io free assets tag](https://itch.io/game-assets/free)

### Shaders / palette swap
- [Godot Shaders](https://godotshaders.com/) — searchable; see "palette", "outline", "CRT" tags
- [KoBeWi/Godot-Palette-Swap-Shader](https://github.com/KoBeWi/Godot-Palette-Swap-Shader) — drop-in

### Open-source Godot 4 projects to study
- [codernunk/flick](https://github.com/codernunk/flick) — Godot 4.x 2D platformer, CC-BY assets
- [Pixelorama](https://github.com/Orama-Interactive/Pixelorama) — large Godot 4 codebase (it's a tool, not a game, but the patterns are useful)
- [godotengine/awesome-godot](https://github.com/godotengine/awesome-godot) — curated list, filter for Godot 4
