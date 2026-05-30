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

## Project state (2026-05-30)

- **Genre: explosion-themed action platformer.** Combat pivot — grenades are the kill button, melee bat is the utility/knockback tool, slam is the AOE punctuation, gun is chip damage.
- **Base resolution: 320×180** (16:9, integer-scales to 1080p ×6 / 4K ×12). Initial window 1280×720 (×4).
- **Tile size: 16×16** (Brackeys assets), character sprite 32×32 (knight).
- **Art:** [Brackeys CC0 platformer asset pack](assets/CREDITS.txt) — knight, world_tileset, platforms, slime variants, fruit, coin + chiptune SFX/music + PixelOperator8 font. No bat-on-ball SFX in the project; lob "crack" is `tap` + `power_up` stacked via `Audio.play_sfx_layered`.
- **Pixel-perfect settings:** applied — Nearest filter default, `snap_2d_transforms_to_pixel`, `snap_2d_vertices_to_pixel`, viewport stretch with `keep` aspect.
- **Playable level:** [scenes/main.tscn](scenes/main.tscn) — 2880×180 single-screen-tall level. Section A (0–960) intro, Section B (960–1920) "sky path" with tower wall-jump shaft, Section C (1920–2880) "gauntlet". 21 platforms, 6 walls (each its own `RectangleShape2D`), 17 slimes (green/purple mix, 2× floating). Camera2D in player.tscn clamped to world bounds.
- **Player movement** ([scripts/player.gd](scripts/player.gd)): walk, jump (coyote + buffer), dash (Shift — dodge: passes through enemies AND grenades; 0.08s post-dash grace keeps the dodge flag alive past the last frame; A/D-aware direction at trigger; leans 4px forward; afterimages every 0.05s), shoot fruit (J), throw grenade (K — charged), melee bat (H — charged), ground slam (Down/S in air — fall-time scaled). Bottom-anchored squash & stretch. Wall slide is sticky once attached; exits via Jump (wall jump), Slam, away-input, or floor. Wall jump fires even when flush against a wall via fallback horizontal raycast. Smoothed multi-wall ricochet via 0.22s input lock, wall-ignore filter, and 0.06s sticky-wall grace.
- **One-way platforms:** Platform1/2/4/5/6/7 have `one_way_collision = true`. Player jumps up through, lands on top, drops through with Down.
- **Player health:** 3 HP, 1s invincibility after damage (also bypassed by dash dodge and slam i-frames), red sprite flash on hit, `hurt` SFX. HP UI built programmatically (CanvasLayer + Label child of player). HP label permanently on screen. Falling below `y > 350` is instant death; `_die()` reloads the scene.
- **Charge label** ([scripts/player.gd](scripts/player.gd)): single floating Label above the player, recolored on charge start — yellow for grenade, red for bat. Shows whole-second count (0→3). Per-second tick plays `coin` (grenade) or `power_up` (bat).
- **Combat — fruit (J):** Fruit ([scripts/fruit.gd](scripts/fruit.gd)) is a black `Polygon2D` circle (r=2.5, Area2D); 250 px/s, 1.5s lifetime; 1 dmg via `take_damage`; despawns on wall hit; spawns a fading trail.
- **Combat — grenade (K, charged 0–3s):** Grenade ([scripts/grenade.gd](scripts/grenade.gd)) is a red-orange `Polygon2D` circle (r=5) on a **CharacterBody2D**. Initial velocity (200, −180), GRAVITY 700; bounces off surfaces via `move_and_collide` + `velocity.bounce(normal) * 0.55`. Charge scales explosion radius: base `BASE_EXPLOSION_RADIUS=48`, `+100/3 px per second held` → max `148` at 3s; visual tints redder while charging. One grenade out at a time. Detonates on contact with player (after 0.15s arm; skipped if dashing or `_player_safe`), enemy proximity (CONTACT_RADIUS=16), fruit contact, or 5s fuse. Last 0.6s of the fuse: 3 red→white timeout-warning blinks. On any detonation: 0.09s pre-detonate freeze where Visual flashes pure white and `tap` SFX plays, then `_explode` runs. Wave-based damage: ring expands at WAVE_SPEED=260 px/s (outrunnable by dash 320 px/s); contact-triggering enemy/player damaged immediately on prime (can't escape the 0.09s prime delay). Player damage 8, enemy damage 8.
- **Combat — knockback model (per research recipe — see `28f2c89`):** Grenade `apply_knockback(vx, vy)` checks if grounded via a 7px down probe. Grounded targets get velocity REPLACEMENT + auto-lift (`vy = min(vy, -160)`) so a flat horizontal swing pops them off the floor. Airborne targets get ADDITIVE impulse (juggling stacks). 0.18s `_knockback_timer` swaps the floor bounce-with-damp for `velocity.slide(normal)` during the launch window so re-grounding doesn't eat the impulse. 0.12s `_gravity_suspend_timer` skips the gravity tick. Slime knockback mirrors this pattern; slime knockback also bounces off walls/ceilings via `_is_blocked_at` probes (50% velocity damping).
- **Combat — melee bat (H, charged 0–3s):** Player runs a brown `Polygon2D` bat (24×5px) tweened via `_animate_bat`. Direction = jump key (up), slam key (down), move_left/right, or facing default. Swing duration 0.11s, cooldown 0.24s. Hit detection: `_in_swing_arc` — point-blank 9px (always hits regardless of facing), otherwise hemisphere check (`dot > -0.15`, ~198°). Base reach 52px, +3px per second charged. Knockback scales 1.0×–1.6× with charge; damage is fixed at 0.5/swing via an accumulator (`_swing_damage_carry`, every other swing applies 1). Bat tints from brown → red as charge increases.
- **Combat — lob combos (mirror):** Holding either charge button and tapping the other immediately spawns + bats a grenade. **K-hold + H tap:** strong grenade with default bat. **H-hold + K tap:** default grenade with strong bat. Skipped if a grenade is already out. Lob spawns the grenade with `set_player_safe(true)` — adds a collision exception with the player so the grenade physically phases through and can't fall back on its own thrower. Lob mechanic: small upward toss (vy=-90), bat animates, after `SWING_DURATION * 0.5` (mid-swing) the main impulse is applied via `create_timer` lambda + `is_instance_valid` guard, with `power_up` layered as the connection sound. Base lob speed 460, scales 1.0×–1.45× with bat charge.
- **Combat — slam (Down/S in air, fall-time scaled):** Player snaps to vy=500 + gravity during slam; afterimages. `_slam_fall_time` accumulates each physics tick during descent. On landing: `fall_mult = clamp((fall_time - 0.15) / 0.15, 0, 1.5)`. Below threshold → no AOE (basic jump-slam is silent on impact). Above threshold → multiplier is floored at 0.75 (so any qualifying slam feels meaty) and capped at 1.5. Slam initializes a shockwave (origin=landing pos, max_radius=`SLAM_RADIUS=45 * mult`, knockback=`SLAM_KNOCKBACK=160 * mult`, damage=`round(SLAM_DAMAGE=2 * mult)`). `_tick_slam_wave` (called each physics frame from `_physics_process`) grows radius at `SLAM_WAVE_SPEED=240 px/s` and applies knockback + damage to enemies as the expanding circle crosses them (mirrors grenade `_tick_wave`); `_slam_damaged` set prevents double-hits. Pale-blue ring visual expands linearly to match the damage edge 1:1. `explosion` SFX plays on every landing regardless of mult.
- **Slime AI** ([scripts/slime.gd](scripts/slime.gd)) state machine (WANDER → CHASE → WIND_UP → JUMP → LAND): aggros only when player is within `aggro_x_range` AND `aggro_y_tolerance`, persists 30s after last sighting; jump-attacks with squash/stretch and 4px wall-collision lookahead; leaps off platforms and falls via gravity; ledge-avoids during wander/chase; blocked by walls; raycasts exclude the player; auto-falls if patrolling without ground. `@export max_health` (default 4) + `take_damage`. Purple variant ([scenes/slime_purple.tscn](scenes/slime_purple.tscn)) sets `max_health = 8`.
- **Enemy health bars** ([scripts/slime.gd](scripts/slime.gd)): 16×2px ColorRect bar above each slime, hidden by default. Pops in on `take_damage`, stays for 2s, fades over 0.4s. Color: green → yellow → red as HP drops.
- **Audio singleton** ([scripts/audio.gd](scripts/audio.gd)) loops `time_for_adventure.mp3`, exposes `Audio.play_sfx(name)` for the six WAV SFX, and `Audio.play_sfx_layered(name)` which spawns a one-shot AudioStreamPlayer so multiple SFX can stack (used by the lob "crack").
- Palette / tilemap-authoring tool / save format: still TBD — see [docs/playbook.md](docs/playbook.md).

## Architecture overview

Current tree:
- `assets/` — fonts, music, sounds, sprites (CC0 from Brackeys pack)
- `scenes/` — `main.tscn` (entry), `player.tscn`, `fruit.tscn` (black-dot projectile), `grenade.tscn` (red-orange ballistic), `slime.tscn` / `slime_purple.tscn` (enemies), `level/floor.tscn` `level/platform.tscn` `level/wall.tscn` (reusable level blocks)
- `scripts/` — `audio.gd` (autoload), `player.gd`, `fruit.gd`, `grenade.gd`, `slime.gd`, `level_block.gd` (@tool auto-syncs visual/collision via @export size)
- `docs/` — project documentation (playbook + future design notes)

Group conventions:
- `"player"` — player CharacterBody2D (added in player._ready)
- `"dashing"` — player only while a dash is active (+ 0.08s post-dash grace; enemies + grenade dodge-gate on this)
- `"enemy"` — slime Area2Ds (fruit / grenade / slam / bat check this group)
- `"fruit"` — fruit Area2Ds (grenade checks this so shooting a grenade detonates it)
- `"grenade"` — live grenade CharacterBody2D (enforces one-at-a-time + lob-existence gating)

Autoloads:
- `Audio` (`scripts/audio.gd`) — `Audio.play_sfx("jump"|"hurt"|"coin"|"explosion"|"power_up"|"tap")` plus `Audio.play_sfx_layered(name)` for stackable shots. Music loops automatically on game start.

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

Newest first. Format: `YYYY-MM-DD <short SHA> — what changed`. Recent rapid iterations are consolidated into the topical entry that landed them.

- 2026-05-30 `fc2c6b4` — Slam knockback rebuilt as a grenade-style expanding wave. `_do_slam_damage(mult)` seeds shockwave state (origin, max radius, knockback, damage); `_tick_slam_wave` ticks each physics frame at `SLAM_WAVE_SPEED=240 px/s`, applying knockback + damage as the circle's edge crosses each enemy. `_slam_damaged` set prevents double-hits. Visual ring switched to `TRANS_LINEAR` so what you see is what gets hit. Wave origin fixed at landing point so it doesn't follow the player.
- 2026-05-30 `6c8aade` `25876cd` `83914d7` `2fac0ed` — Slam fall-time scaling + sphere AOE. `_slam_fall_time` accumulates during descent. On landing `fall_mult = clamp((fall_time - 0.15) / 0.15, 0, 1.5)`, floored at 0.75 once above threshold so any qualifying slam feels meaty. Basic jump-slam (≤0.15s) does nothing. Radius / damage / knockback / ring size all multiplied by `fall_mult`. SLAM_RADIUS bumped 36→45. Pale-blue shockwave ring at landing point. `explosion` SFX always plays; only AOE gated.
- 2026-05-30 `550da15` — Slam gains radial knockback. Pushes every enemy in radius outward at 160 px/s (half melee base) using `(enemy - player).normalized()`. Slimes auto-lift via existing grounded-knockback path.
- 2026-05-30 `7b7b2bc` — Verbose comments throughout `player.gd`. Section dividers, per-constant + per-var purpose notes, docstring-style headers, inline commentary in `_physics_process`. No logic changes.
- 2026-05-30 `d5bf8a2` — Slime knockback bounces off walls/ceilings instead of phasing. `_is_blocked_at` probes 4px ahead horizontally + 6px above; reverses velocity with 50% damp on contact. Ground snap unchanged.
- 2026-05-30 `33ee13e` — Bat damage halved via fractional accumulator. `SWING_DAMAGE_PER_HIT=0.5` accumulates into `_swing_damage_carry`; integer damage applied only when carry crosses 1 (every-other-swing). Knockback fires every swing regardless.
- 2026-05-30 `759dbd8` `c8fb34b` `0cd99e1` `c8cabe5` `f87405f` — Melee hit-tolerance tuning. Base reach 36→52, per-charge 2→3, hemisphere check relaxed `dot > 0` → `dot > -0.15`. Point-blank radius iterated 14 → 9. Grenade enemy CONTACT_RADIUS bumped 9→16 so a slime sitting on a grenade triggers detonation immediately.
- 2026-05-30 `28f2c89` — Knockback model rebuild per research recipe (Smash/Dead Cells/Godot canonical pattern). Grounded target → velocity REPLACEMENT + auto-lift (`vy = min(vy, -160)`) so a flat horizontal swing pops a resting grenade off the floor. Airborne target → additive impulse. 0.18s knockback window swaps floor-bounce-with-damp for `velocity.slide(normal)`. 0.12s gravity suspension prevents frame-1 re-grounding from eating the impulse. Slime mirrors the same model.
- 2026-05-30 `e328da8` — Contact-triggered detonation always damages the triggerer. `_prime_explode(target=null)` takes the contact entity and damages it immediately + adds it to `_damaged` so fast enemies can't escape the 0.09s prime delay.
- 2026-05-30 `bb8c998` `c652df9` `db8be20` — Crash hardening on `_prime_explode`. `take_damage` on the player can trigger `_die()` → `reload_current_scene()`, which removes the grenade from the tree mid-function; `get_tree()` then returns null and `create_timer` crashes. Bail via `is_inside_tree()` before scheduling `_explode`.
- 2026-05-30 `a6b826f` — Mirror lob combo. Pressing H while charging K lobs a strong grenade with default bat (charge grenade → hit melee → strong grenade). Inverse of the existing K-during-H combo. `_do_grenade_lob(dir, bat_charge, grenade_charge=0.0)` routes each combo into the right slot.
- 2026-05-30 `3ca8d99` `0f6c7f7` `839480d` — Lob refinements. Grenade `_player_safe` flag — gates both contact and proximity detonation on player; also calls `add_collision_exception_with(player)` so `move_and_collide` reports no player contact (no slide-on-head). Lob now tosses up first (vy=-90), bat animates, mid-swing `create_timer` fires the main impulse with `power_up` layered as the "crack". Fix: `set_player_safe` must run AFTER `add_child` so `get_tree()` is non-null. Regular swing on a grenade also plays the layered hit SFX.
- 2026-05-30 `6b5ba38` `d4f77f9` — Charge caps lowered to 3s for both bat (mult halved → max 1.6×) and grenade (per-second radius bump scaled so max stays 148px).
- 2026-05-30 `7cd3289` `3bd2777` — Dash dodges grenades. Grenade collision + proximity checks skip detonation if player is in `dashing` group. Added 0.08s post-dash grace so a frame-order race doesn't let the flag clear before the grenade's physics tick.
- 2026-05-30 `d438f53` — Bat tuning. 30→24px shorter, 0.13→0.11s swing, 0.28→0.24s cooldown. `_get_swing_direction` also reads move_left/right (default to facing). Lob plays layered `tap`+`power_up` via new `Audio.play_sfx_layered` (no true bat-on-ball SFX in the project; this stacks the two closest shorts).
- 2026-05-30 `0223100` `40e74ba` — Damage rebalance (final state in current commits): fruit 1, melee 0.5 average, slam 2 × fall_mult, grenade 8. Green slime 4 HP, purple 8 HP.
- 2026-05-30 `50bf8a6` `4939872` `68b8955` — Directional charged melee bat on H. Brown 24×5 `Polygon2D` swings 0.11s, mirrored for facing left, mirrored arcs for up/down. Direction = jump (up) / slam (down) / move_left / move_right / facing default. Charge scales knockback + reach (cap 1.6×). One-shot arc hit detection with point-blank radius. `apply_knockback` ADDS to existing velocity so targets keep momentum. K-during-H-charge fires the lob combo.
- 2026-05-30 `1f7b7ba` — Drop K remote-detonate. Grenades only blow up from contact, fruit hit, or fuse timeout. One-at-a-time rule still gates new throws.
- 2026-05-30 `1232075` — Enemy health bars. 16×2px ColorRect above each slime, hidden by default; pops in on `take_damage`, holds 2s, fades 0.4s. Fill color green → yellow → red as HP drops.
- 2026-05-30 `a981983` `6b2d974` `cac9333` `34386be` — Grenade UX. (1) Pre-detonate flash: 0.09s freeze where Visual goes pure white + `tap` SFX before `_explode` runs. (2) Timeout warning: 3 red→white blinks over the last 0.6s of the 5s fuse. (3) Charge counter UI: Label above player, shows whole-second tick, plays `coin` on each tick. (Label2D doesn't exist in Godot 4 → used Control `Label`.)
- 2026-05-30 `6b09d5e` `8edafd6` — Grenade charging on hold-K. Each second adds explosion radius (was 20px/sec, later scaled when cap moved to 3s). Visual tints redder while charging. Enemy HP first doubled here.
- 2026-05-30 `4c214d6` — Grenade wave-based damage. Damage applies only as the expanding ring reaches each target — wave 260 px/s (outrunnable by dash 320). Replaces the instant-radius application.
- 2026-05-13 `bb53bef` — Explosion visual: single 32-seg red semi-transparent Polygon2D ring at `EXPLOSION_RADIUS` (color `(1, 0.15, 0.15, 0.8)`). Scale 0.05 → 1.0 with `TRANS_BACK` ease-out overshoot. Alpha pulses 0.25 ↔ 1.0 twice on a parallel tween before fading to 0 over `BLAST_DURATION=0.25s`. (A 48-ball particle cloud was tried and replaced by this single ring — denser but messier visually.)
- 2026-05-13 `9e8d95f` — One grenade at a time. Grenade joins `"grenade"` group in `_ready`; new public `detonate()` wraps `_explode()`. `_throw_grenade` looks up an existing grenade and detonates it instead of spawning a second. queue_free removes from group, so the next K press throws fresh.
- 2026-05-13 `0b52523` — Grenade also detonates when a fruit comes within `CONTACT_RADIUS+3px` (shoot it to blow it up). Fruit despawns on contact via its own body_entered.
- 2026-05-13 `a503ace` — Per-frame player proximity check (`PLAYER_CONTACT_RADIUS=12`) so the grenade explodes when the player walks into a resting grenade — not only when the grenade flies into the player.
- 2026-05-13 `4584beb` — Grenade explosion now deals 2 dmg to enemies (was 1), one-shotting 2-HP purple slimes via `ENEMY_DAMAGE` constant.
- 2026-05-13 `9ce576b` — Grenade reworked from Area2D into CharacterBody2D. Bounces off floor/walls/platforms via `move_and_collide` + `velocity.bounce(n)*0.55`. Detonates on 5s fuse, player contact (after 0.15s arm), or enemy proximity (9px). Explosion damages player (2) and enemies (1) within 48px. THROW_OFFSET x raised 10→16 so the physical body spawns clear of the thrower. Player gains slam i-frames (no damage while `_slamming`) and a red sprite flash on hit (tween modulate back to white over 0.4s).
- 2026-05-13 `ad55c8c` — Player health system. 3 HP, 1s invuln after damage, `hurt` SFX, `_die()` reloads the scene. Fall below `y > 350` is instant death (checked at top of `_physics_process` so it fires even during dash/slam). HP label built in code (CanvasLayer + Label as player children — no main.tscn dependency). Enemy slime contact calls `body.take_damage(1)`; dash dodge still bypasses via `"dashing"` group. Slime gains `@export max_health` (default 1) + `take_damage(amount)`; fruit/grenade/slam route damage through it. Purple slime sets `max_health = 2`.
- 2026-05-13 `ac4772c` — Restore level_block.gd (@tool, @export size: Vector2) attached to all three level scenes; user scene/balance tweaks bundled.
- 2026-05-13 `10234e1` — Wall slide: pressing direction AWAY from wall now detaches and moves the player in that direction. Adds a fourth exit alongside jump / slam / floor contact.
- 2026-05-13 `7e78f53` — Fruit spawn y -4 → +1 (~15% of sprite height lower), placing the bullet at lower-chest level instead of mid-chest.
- 2026-05-13 `ea69f54` — Fruit projectile redrawn: 12-segment black `Polygon2D` circle at radius 2.5 (half the grenade's size), `CircleShape2D` collision; trail now duplicates Polygon2D instead of Sprite2D. Knight fruit sprite no longer used by this projectile.
- 2026-05-13 `d243af7` — New grenade projectile on K. Area2D + 5px CircleShape2D + red-orange Polygon2D circle; initial (200, -260) velocity, GRAVITY 700, 4s lifetime; AOE radius 48 on detonation. Both projectiles spawn fading trails (~0.04s interval, 0.22-0.28s duration, alpha 0.5-0.55 → 0).
- 2026-05-13 `b2eb47c` — Dash is now a dodge. Player adds self to `"dashing"` group during dash; slime body_entered skips hurt SFX if entering body is in `"dashing"`.
- 2026-05-13 `263ce43` — Wall jump fires when player is flush against wall without input. Fallback in `_classify_wall_contact`: two 9px horizontal rays + shape orientation check supplement `is_on_wall_only()` so the player doesn't lose wall contact the moment direction is released.
- 2026-05-13 `a371737` — Slime JUMP state respects walls via 4px lookahead `_is_blocked_at`; on collision, jump_dir is zeroed for the rest of the leap, slime slides straight down to ground below.
- 2026-05-13 `f2472e9` — Reverted `8321623` (level_block @export size); rebuilt in `ac4772c` later.
- 2026-05-13 `5750fbb` — Briefly removed `level_block.gd` and the script reference from level scenes; user keeps visual/collision in sync manually. Subsequently restored.
- 2026-05-13 `012f442` — Level block sync: `visual.position = cs.position - size / 2` (corrected from a transient `/ 1.0`); visual rect exactly covers collision rect.
- 2026-05-13 `8e1d11a` — Player sprite bottom aligned with collision bottom. `Sprite2D.position.y` 16 → 11; with offset (0, -16), bottom_y = position.y + sy*(H/2+offset.y) = 11 always, so squash/stretch stays anchored to feet.
- 2026-05-13 `2ccb325` — New reusable level scenes: `scenes/level/{floor,platform,wall}.tscn`. Each is `StaticBody2D` + `ColorRect` + `CollisionShape2D` with a `resource_local_to_scene = true` `RectangleShape2D`, so duplicated instances get independent shapes.
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
- **Space** / **W** / up — jump
- **Shift** — dash (also a dodge — phases through enemies + grenades)
- **S** / down (in air) — slam (fall-time scaled AOE on landing)
- **J** — shoot fruit (1 dmg, ranged chip)
- **K** (tap or hold up to 3s) — throw grenade; charge scales explosion radius (48 → 148)
- **H** (tap or hold up to 3s) — melee bat swing; charge scales knockback + reach; direction = vertical modifier / horizontal input / facing default
- **K while holding H** — lob a default grenade with strong bat (great hit, normal size)
- **H while holding K** — lob a charged grenade with default bat (normal hit, big size)
- **Hold direction into a wall** while in the air — wall stick → slide; jump to wall-jump

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
