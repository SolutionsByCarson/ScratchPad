# ============================================================================
# Player controller — CharacterBody2D
# ----------------------------------------------------------------------------
# Drives all player abilities: walk, jump (with coyote + buffer windows), dash
# (with dodge i-frames), wall slide / wall jump, ground slam, ranged shoot
# (fruit), grenade throw + charging, melee bat swing + charging, and the
# H+K / K+H combo lobs. Also owns player HP / death and the on-screen HUD
# (HP label and charge label).
#
# The flow lives in _physics_process(). The order matters because some inputs
# gate others (dash early-returns; wall_attached suppresses most actions).
# ============================================================================
extends CharacterBody2D

# ---------------------------------------------------------------------------
# Locomotion + jump
# ---------------------------------------------------------------------------
const SPEED := 140.0                # Ground/air horizontal max speed (px/s).
const JUMP_VELOCITY := -350.0       # Initial upward velocity on jump (negative = up).
const COYOTE_TIME := 0.10           # Window after leaving a ledge where jump is still allowed.
const JUMP_BUFFER := 0.10           # Window before landing where a pre-pressed jump still fires.

# ---------------------------------------------------------------------------
# Dash (also doubles as a dodge — passes through enemies + grenades)
# ---------------------------------------------------------------------------
const DASH_SPEED := 320.0           # Horizontal speed during dash.
const DASH_DURATION := 0.17         # How long a dash lasts.
const DASH_COOLDOWN := 0.5          # Re-press cooldown after a dash ends.
# Grace window after dash ends where the player stays in the "dashing" group.
# Without this, enemies/grenades that run their _physics_process AFTER the
# player on the same frame would see the dodge flag already cleared and
# detonate / hurt the player exactly on the dash's last frame.
const DASH_DODGE_GRACE := 0.08

# ---------------------------------------------------------------------------
# Wall slide / wall jump
# ---------------------------------------------------------------------------
const WALL_STICK_TIME := 0.20       # Free hang time before sliding starts.
const WALL_SLIDE_MAX_FALL := 80.0   # Capped fall speed while sliding.
const WALL_JUMP_PUSH_X := 220.0     # Horizontal launch speed away from the wall.
const WALL_JUMP_VELOCITY := -300.0  # Vertical launch on a wall jump.
# After a wall jump we LOCK horizontal input for this long, otherwise the
# player flicking back toward the wall would immediately re-attach and you'd
# never visibly leave it. The input is still read, just not applied to velocity.
const WALL_JUMP_INPUT_LOCK := 0.22
# Tiny grace window where we still treat the player as "near a wall" after
# they've left wall contact. Makes the 0.22s lock + ricochet feel forgiving.
const WALL_GRACE_TIME := 0.06

# ---------------------------------------------------------------------------
# Ground slam — Down/S in the air
# ---------------------------------------------------------------------------
const SLAM_SPEED := 500.0           # Forced downward velocity once slamming.
const SLAM_RADIUS := 56.0           # Sphere AOE radius — reaches airborne enemies above + beside.
const SLAM_LAND_DURATION := 0.18    # How long the slam-landing squash visual holds.
const SLAM_DAMAGE := 2              # Damage dealt to each enemy in radius on landing.
const SLAM_KNOCKBACK := 160.0       # Radial knockback magnitude on landing (half of bat).
const SLAM_RING_DURATION := 0.28    # Visual impact ring expansion time.
const SLAM_RING_COLOR := Color(0.6, 0.85, 1.0, 0.7)  # Pale-blue shockwave color.
const SLAM_RING_SEGMENTS := 32

# ---------------------------------------------------------------------------
# Sprite scaling (squash & stretch) + afterimages
# ---------------------------------------------------------------------------
const DASH_SCALE := Vector2(1.45, 0.7)         # Stretched-horizontal during dash.
const SLAM_DESCENT_SCALE := Vector2(0.65, 1.45) # Stretched-vertical during slam fall.
const SLAM_LAND_SCALE := Vector2(1.55, 0.55)    # Flattened on slam land.
const DASH_OFFSET_X := 4.0                      # Sprite lean during dash (forward push).
const AFTERIMAGE_INTERVAL := 0.05               # How often dash/slam spawn ghost sprites.
const AFTERIMAGE_DURATION := 0.22               # Time for each ghost to fade out.
const AFTERIMAGE_START_ALPHA := 0.55            # Initial alpha of each ghost.

# ---------------------------------------------------------------------------
# Shoot (fruit) + Throw (grenade)
# ---------------------------------------------------------------------------
const FRUIT_SCENE := preload("res://scenes/fruit.tscn")
const SHOOT_OFFSET := Vector2(12.0, -3.0)   # Fruit spawn offset from player center.
const GRENADE_SCENE := preload("res://scenes/grenade.tscn")
const THROW_OFFSET := Vector2(16.0, -6.0)   # Grenade spawn offset (in front + slightly up).
const THROW_CHARGE_MAX := 3.0               # Cap for grenade size charge (seconds).

# ---------------------------------------------------------------------------
# Health + invulnerability + death fall
# ---------------------------------------------------------------------------
const MAX_HEALTH := 3
const INVULN_TIME := 1.0          # i-frames after taking damage.
const FALL_DEATH_Y := 350.0       # World y past which the player dies (fell off the map).

# ---------------------------------------------------------------------------
# Melee bat swing
# ---------------------------------------------------------------------------
const SWING_DURATION := 0.11          # Animation length of one swing.
const SWING_COOLDOWN := 0.24          # Re-press cooldown after a swing fires.
const SWING_REACH_BASE := 52.0        # Base hit radius (px from player center).
const SWING_REACH_PER_CHARGE := 3.0   # Extra reach per second of charge held.
# Inside this radius, ANY enemy hits regardless of swing direction. Lets the
# player hit something they're standing on top of without aiming.
const SWING_POINT_BLANK := 9.0
const SWING_KNOCKBACK_ENEMY_BASE := 320.0     # Base enemy knockback magnitude.
const SWING_KNOCKBACK_GRENADE_BASE := 360.0   # Base grenade knockback magnitude.
const SWING_CHARGE_MAX := 3.0                 # Cap for bat charge (seconds).
const SWING_CHARGE_KB_MULT_PER_SEC := 0.2     # Knockback multiplier growth per charge second.
# Bat does half-damage on average. Accumulator pattern: each swing adds 0.5,
# damage actually applied is floor(accumulator). Every other swing lands 1.
const SWING_DAMAGE_PER_HIT := 0.5
const SWING_BAT_LENGTH := 24.0
const SWING_BAT_THICKNESS := 5.0
const SWING_BAT_COLOR := Color(0.75, 0.5, 0.2, 1.0)        # Uncharged: brown.
const SWING_BAT_FULL_COLOR := Color(1.0, 0.3, 0.15, 1.0)   # Full charge: red.

# Grenade lob (H+K or K+H combo) — see _do_grenade_lob below.
const SWING_LOB_BASE_SPEED := 460.0
const SWING_LOB_MULT_PER_SEC := 0.15  # Lob velocity multiplier growth per bat charge second.

@onready var sprite: Sprite2D = $Sprite2D

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
var _coyote_timer := 0.0              # Counts down after leaving ground; jump allowed while >0.
var _jump_buffer_timer := 0.0         # Counts down after pressing jump; jump fires when timer >0 and grounded.
var _facing := 1.0                    # +1 = facing right, -1 = facing left. Drives sprite flip + spawn directions.
var _dash_time_left := 0.0            # >0 means dash in progress (early-returns _physics_process).
var _dash_cooldown_left := 0.0        # >0 blocks new dash.
var _dash_grace_left := 0.0           # See DASH_DODGE_GRACE — extends "dashing" group membership.
var _wall_stick_left := WALL_STICK_TIME
var _wall_jump_lock_left := 0.0       # >0 suppresses horizontal input application.
var _slamming := false
var _slam_land_timer := 0.0           # Visual hold for slam-landing squash.
var _afterimage_timer := 0.0          # Ticks down between afterimage spawns.
var _ignore_wall_normal_x := 0.0      # Wall normal we just jumped FROM; filtered until lock expires.
var _wall_grace_left := 0.0
var _last_wall_normal_x := 0.0        # Cached normal for grace-window wall jump.
var _wall_attached := false           # Sticky wall-cling state (exits via jump/slam/away/floor).
var _wall_attached_normal_x := 0.0
var _health := MAX_HEALTH
var _invuln_left := 0.0
var _hp_label: Label                  # On-screen HP counter (built in code, lives in CanvasLayer).

# Grenade charge state.
var _throw_charging := false
var _throw_charge := 0.0
var _last_charge_tick := 0            # Last whole-second tick (for SFX + label update).
var _charge_label: Label              # Floating "0/1/2/3" indicator above the player (shared by swing + throw, recolored).

# Melee swing state.
var _swing_cooldown_left := 0.0
var _swing_visual: Polygon2D          # The rotating bat polygon (child of player).
var _swing_charging := false
var _swing_charge := 0.0
var _last_swing_tick := 0
var _swing_damage_carry := 0.0        # Accumulator for SWING_DAMAGE_PER_HIT (half-dmg/swing).


# ============================================================================
# Setup
# ============================================================================

func _ready() -> void:
	add_to_group("player")  # Enemies, fruit, grenades all look us up via this group.
	_setup_hp_ui()
	_update_hp_ui()
	_setup_charge_ui()
	_setup_swing_visual()


# Build the bat polygon (rectangle, extends along +x from origin). Rotated via
# tween at swing time. Hidden by default; only shown for the duration of a swing.
func _setup_swing_visual() -> void:
	_swing_visual = Polygon2D.new()
	_swing_visual.polygon = PackedVector2Array([
		Vector2(0.0, -SWING_BAT_THICKNESS / 2.0),
		Vector2(SWING_BAT_LENGTH, -SWING_BAT_THICKNESS / 2.0),
		Vector2(SWING_BAT_LENGTH, SWING_BAT_THICKNESS / 2.0),
		Vector2(0.0, SWING_BAT_THICKNESS / 2.0),
	])
	_swing_visual.color = SWING_BAT_COLOR
	_swing_visual.z_index = 2
	_swing_visual.position = Vector2(0.0, -2.0)  # Slightly above player center.
	_swing_visual.visible = false
	add_child(_swing_visual)


# Build the charge counter Label that floats above the player while charging
# either the bat (red text) or the grenade (yellow text). The color is set at
# charge-start time so the same Label serves both meters.
func _setup_charge_ui() -> void:
	_charge_label = Label.new()
	var font: Font = load("res://assets/fonts/PixelOperator8-Bold.ttf")
	if font != null:
		_charge_label.add_theme_font_override("font", font)
	_charge_label.add_theme_font_size_override("font_size", 16)
	_charge_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	_charge_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_charge_label.add_theme_constant_override("outline_size", 2)
	_charge_label.position = Vector2(-4, -28)
	_charge_label.scale = Vector2(0.5, 0.5)
	_charge_label.text = "0"
	_charge_label.visible = false
	add_child(_charge_label)


# HP indicator (CanvasLayer so it doesn't follow camera transform). Built in
# code so we don't need to edit the level scene to add a HUD.
func _setup_hp_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hp_label = Label.new()
	_hp_label.offset_left = 4.0
	_hp_label.offset_top = 2.0
	_hp_label.offset_right = 120.0
	_hp_label.offset_bottom = 20.0
	layer.add_child(_hp_label)


func _update_hp_ui() -> void:
	if _hp_label != null:
		_hp_label.text = "HP %d/%d" % [maxi(_health, 0), MAX_HEALTH]


# ============================================================================
# Damage / death
# ============================================================================

# Called by enemies + grenade explosions. We bail early during i-frames, while
# dashing (dodge), or while slamming (slam = i-frames too).
func take_damage(amount: int = 1) -> void:
	if _invuln_left > 0.0 or is_in_group("dashing") or _slamming:
		return
	_health -= amount
	_invuln_left = INVULN_TIME
	Audio.play_sfx("hurt")
	_flash_red()
	_update_hp_ui()
	if _health <= 0:
		_die()


# Visible "I got hit" feedback: tint the sprite red, then fade back to white
# over the i-frame window so the player can read invulnerability state.
func _flash_red() -> void:
	sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)


# Reload the current scene as a brute-force "respawn". Anything that depends
# on scene state (enemies, grenades, fruit) is reset for free.
func _die() -> void:
	get_tree().reload_current_scene()


# ============================================================================
# Main physics loop
# ----------------------------------------------------------------------------
# This is intentionally one long procedure rather than a state machine — the
# action gating is dense and "is this action allowed right now?" lives mostly
# inline. The high-level shape is:
#   1. Tick passive timers / death-by-fall check
#   2. Classify wall contact + wall-cling state
#   3. Read input for one-shot actions (shoot / swing / throw / dash / slam)
#   4. Resolve active continuous states (dash, slam) with early returns
#   5. Apply gravity + jump / wall-jump
#   6. Apply walking input
#   7. move_and_slide() once at the end
# ============================================================================

func _physics_process(delta: float) -> void:
	_update_visual_scale(delta)  # Sprite squash/stretch tracking dash/slam/landing.

	_invuln_left = max(0.0, _invuln_left - delta)
	# Death pit check — runs BEFORE other physics so dash/slam can't outrun it.
	if global_position.y > FALL_DEATH_Y:
		_die()
		return

	# Wall-jump input lock decay. Once expired, we stop filtering the wall we
	# just jumped off (so the player can re-attach to it later).
	_wall_jump_lock_left = max(0.0, _wall_jump_lock_left - delta)
	if _wall_jump_lock_left <= 0.0:
		_ignore_wall_normal_x = 0.0

	# ---- Read inputs and classify environment ----
	var input_dir := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()
	# _classify_wall_contact returns {is_wall: bool, normal_x: float}. It uses
	# both is_on_wall_only() and a fallback raycast so that the player keeps
	# wall-jump availability even after releasing the "into-wall" direction.
	var contact: Dictionary = _classify_wall_contact()
	var on_vertical_wall: bool = contact.is_wall
	var contact_normal_x: float = contact.normal_x

	# If we're now touching the OPPOSITE wall from the one we just jumped off,
	# clear the wall-ignore filter so this new wall is treated normally.
	if on_vertical_wall and _ignore_wall_normal_x != 0.0 and signf(contact_normal_x) != signf(_ignore_wall_normal_x):
		_ignore_wall_normal_x = 0.0

	# Maintain the wall-grace window: while actively touching a wall we refresh
	# it; when we leave it ticks down. During grace, wall-jump still fires
	# (Celeste-style stickiness for missed inputs near the wall).
	if on_vertical_wall:
		_wall_grace_left = WALL_GRACE_TIME
		_last_wall_normal_x = contact_normal_x
	else:
		_wall_grace_left = max(0.0, _wall_grace_left - delta)

	# "Pressing into the wall" requires input AND that input pointing opposite
	# to the wall normal (i.e. pressing right while wall normal points left).
	var pressing_into_contact: bool = contact_normal_x != 0.0 and input_dir != 0.0 and signf(input_dir) != signf(contact_normal_x)
	# Wall cling starts when we press into a wall while not moving up.
	var wall_clinging: bool = on_vertical_wall and pressing_into_contact and velocity.y >= 0.0

	# ---- Wall-attached state machine (sticky) ----
	# Once attached, we stay attached until: floor, wall flip, away-input, or
	# jump/slam (handled below by clearing _wall_attached explicitly).
	if wall_clinging:
		_wall_attached = true
		_wall_attached_normal_x = contact_normal_x
	if on_floor:
		_wall_attached = false
	elif not on_vertical_wall:
		_wall_attached = false
	elif _wall_attached and signf(contact_normal_x) != signf(_wall_attached_normal_x):
		_wall_attached = false  # Touched the OTHER wall — detach.
	elif _wall_attached and input_dir != 0.0 and signf(input_dir) == signf(_wall_attached_normal_x):
		_wall_attached = false  # Pressed AWAY from the wall — detach.

	# ---- One-shot inputs (shoot / swing / throw) ----
	# All gated by not-wall-attached and not-dashing.

	if not _wall_attached and _dash_time_left <= 0.0 and Input.is_action_just_pressed("shoot"):
		_shoot()

	# Swing input. Two paths:
	#   - If we're currently charging a THROW and the player taps swing, it's
	#     the K+H combo: lob a charge-sized grenade with default bat strength.
	#   - Otherwise begin charging a swing.
	# Then, if we ARE currently charging a swing, tick the charge timer (and
	# its per-second SFX/label) or fire on release.
	_swing_cooldown_left = max(0.0, _swing_cooldown_left - delta)
	if Input.is_action_just_pressed("swing"):
		if _throw_charging:
			# K+H combo: lob a charged grenade with default bat.
			var existing_g2 := get_tree().get_first_node_in_group("grenade")
			if existing_g2 == null:
				_do_grenade_lob(_get_swing_direction(), 0.0, _throw_charge)
				_throw_charging = false
				_throw_charge = 0.0
				if _charge_label != null:
					_charge_label.visible = false
		elif not _swing_charging and not _wall_attached \
				and _dash_time_left <= 0.0 and _swing_cooldown_left <= 0.0:
			# Start charging a swing.
			_swing_charging = true
			_swing_charge = 0.0
			_last_swing_tick = 0
			if _charge_label != null:
				_charge_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 1.0))
				_charge_label.text = "0"
				_charge_label.visible = true
	if _swing_charging:
		if Input.is_action_pressed("swing"):
			# Still held — accumulate charge and tick the label.
			_swing_charge = min(_swing_charge + delta, SWING_CHARGE_MAX)
			var sci: int = int(floor(_swing_charge))
			if sci != _last_swing_tick:
				_last_swing_tick = sci
				Audio.play_sfx("power_up")
			if _charge_label != null:
				_charge_label.text = str(sci)
		else:
			# Released — fire the swing.
			_do_swing(_swing_charge)
			_swing_charging = false
			_swing_charge = 0.0
			if _charge_label != null:
				_charge_label.visible = false

	# Throw input — mirror of swing input above.
	#   - If currently charging a SWING and player taps throw, that's the H+K
	#     combo: lob a default grenade with charged bat strength.
	#   - Otherwise begin charging a throw (only if no grenade is already out).
	# Then tick or fire the throw charge.
	if Input.is_action_just_pressed("throw"):
		if _swing_charging:
			# H+K combo: lob a default grenade with strong bat.
			var existing_g := get_tree().get_first_node_in_group("grenade")
			if existing_g == null:
				_do_grenade_lob(_get_swing_direction(), _swing_charge)
				_swing_charging = false
				_swing_charge = 0.0
				if _charge_label != null:
					_charge_label.visible = false
		elif not _throw_charging:
			# Start charging a throw.
			var existing := get_tree().get_first_node_in_group("grenade")
			if existing == null and _dash_time_left <= 0.0 and not _wall_attached:
				_throw_charging = true
				_throw_charge = 0.0
				_last_charge_tick = 0
				if _charge_label != null:
					_charge_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
					_charge_label.text = "0"
					_charge_label.visible = true
	if _throw_charging:
		if Input.is_action_pressed("throw"):
			# Still held — accumulate charge.
			_throw_charge = min(_throw_charge + delta, THROW_CHARGE_MAX)
			var charge_int: int = int(floor(_throw_charge))
			if charge_int != _last_charge_tick:
				_last_charge_tick = charge_int
				Audio.play_sfx("coin")
			if _charge_label != null:
				_charge_label.text = str(charge_int)
		else:
			# Released — throw a normal charged grenade.
			_throw_grenade_charged(_throw_charge)
			_throw_charging = false
			_throw_charge = 0.0
			if _charge_label != null:
				_charge_label.visible = false

	# ---- Dash ----
	_dash_cooldown_left = max(0.0, _dash_cooldown_left - delta)

	if not _wall_attached and Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0 and _dash_time_left <= 0.0:
		# If the player is pressing a horizontal direction at trigger time,
		# adopt it as the dash direction even during the wall-jump input lock
		# (which is what prevents direction from being applied to walking).
		if input_dir != 0.0:
			_facing = input_dir
			sprite.flip_h = input_dir < 0.0
		_dash_time_left = DASH_DURATION
		_dash_cooldown_left = DASH_COOLDOWN
		_dash_grace_left = 0.0
		_afterimage_timer = 0.0
		add_to_group("dashing")  # Enemies / grenades read this for dodge gating.
		Audio.play_sfx("power_up")

	# Active dash — override velocity, spawn afterimages, early-return so none
	# of the gravity/jump/walk logic below runs while dashing.
	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_spawn_afterimage()
			_afterimage_timer = AFTERIMAGE_INTERVAL
		velocity.x = _facing * DASH_SPEED
		velocity.y = 0.0
		move_and_slide()
		# When the dash ends, start the grace timer — we stay in "dashing"
		# group until it expires, so late-running physics still sees the dodge.
		if _dash_time_left <= 0.0:
			_dash_grace_left = DASH_DODGE_GRACE
		return

	# Dash-grace tick — finally remove from "dashing" group once grace expires.
	if _dash_grace_left > 0.0:
		_dash_grace_left -= delta
		if _dash_grace_left <= 0.0 and is_in_group("dashing"):
			remove_from_group("dashing")

	# Drop-through one-way platforms: press slam while standing on one nudges
	# the player 2px below the surface to start falling through.
	if is_on_floor() and Input.is_action_just_pressed("slam") and _is_on_one_way_platform():
		global_position.y += 2.0

	# Start slam: only in the air, only if not already slamming.
	if not is_on_floor() and not _slamming and Input.is_action_just_pressed("slam"):
		_slamming = true
		velocity.x = 0.0
		velocity.y = SLAM_SPEED
		_afterimage_timer = 0.0

	# Active slam — falls at SLAM_SPEED+gravity until floor contact, then deals
	# AOE damage/knockback and triggers landing squash.
	if _slamming:
		if is_on_floor():
			_slamming = false
			_slam_land_timer = SLAM_LAND_DURATION
			Audio.play_sfx("explosion")
			_do_slam_damage()
		else:
			velocity += get_gravity() * delta
			velocity.x = 0.0
			_afterimage_timer -= delta
			if _afterimage_timer <= 0.0:
				_spawn_afterimage()
				_afterimage_timer = AFTERIMAGE_INTERVAL
			move_and_slide()
			return  # Slam descent has its own movement; skip the rest.

	# ---- Gravity / wall slide ----
	# Three branches: on floor (refresh coyote+stick), wall-attached (slide
	# with optional free-stick window), or airborne (normal gravity).
	if on_floor:
		_coyote_timer = COYOTE_TIME
		_wall_stick_left = WALL_STICK_TIME
	elif _wall_attached and _wall_stick_left > 0.0:
		# Free-stick window: don't fall yet, gives the player time to react.
		velocity.y = 0.0
		_wall_stick_left -= delta
		_coyote_timer = 0.0
	elif _wall_attached:
		# Sliding: gravity applies but capped at WALL_SLIDE_MAX_FALL.
		velocity += get_gravity() * delta
		velocity.y = min(velocity.y, WALL_SLIDE_MAX_FALL)
		_coyote_timer = 0.0
	else:
		# Airborne (not on a wall): full gravity, drain coyote, reset stick.
		velocity += get_gravity() * delta
		_coyote_timer -= delta
		if not on_vertical_wall:
			_wall_stick_left = WALL_STICK_TIME

	# ---- Jump buffer ----
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER
	else:
		_jump_buffer_timer -= delta

	# ---- Wall jump vs ground jump ----
	# Wall jump takes priority while in the air and near a wall (including
	# grace window). If no wall, fall through to coyote-time ground jump.
	var can_wall_jump: bool = not on_floor and (on_vertical_wall or _wall_grace_left > 0.0)
	var jump_normal_x: float = contact_normal_x if on_vertical_wall else _last_wall_normal_x
	if _jump_buffer_timer > 0.0 and can_wall_jump and jump_normal_x != 0.0:
		# Push horizontally AWAY from the wall + vertical jump.
		velocity.x = jump_normal_x * WALL_JUMP_PUSH_X
		velocity.y = WALL_JUMP_VELOCITY
		_wall_jump_lock_left = WALL_JUMP_INPUT_LOCK
		_ignore_wall_normal_x = jump_normal_x  # Filter this wall during the lock.
		_wall_grace_left = 0.0
		_wall_attached = false
		_facing = jump_normal_x
		sprite.flip_h = jump_normal_x < 0.0
		_jump_buffer_timer = 0.0
		_wall_stick_left = WALL_STICK_TIME
		Audio.play_sfx("jump")
	elif _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		# Normal jump (covered by coyote window).
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		Audio.play_sfx("jump")

	# ---- Horizontal walking ----
	# Skip while wall-attached (sticky cling) or in the wall-jump lock window.
	if not _wall_attached and _wall_jump_lock_left <= 0.0:
		if input_dir != 0.0:
			velocity.x = input_dir * SPEED
			sprite.flip_h = input_dir < 0.0
			_facing = input_dir
		else:
			# No input: friction toward 0 (allows residual wall-jump push to bleed off).
			velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()


# ============================================================================
# Visuals
# ============================================================================

# Drives sprite scaling based on current action — pure visual, no physics.
# Order matters: landing squash overrides slam-fall stretch, which overrides
# dash stretch. The offset.x leans the sprite forward during dash so the
# squash is anchored to the leading edge.
func _update_visual_scale(delta: float) -> void:
	_slam_land_timer = max(0.0, _slam_land_timer - delta)
	if _slam_land_timer > 0.0:
		sprite.scale = SLAM_LAND_SCALE
		sprite.position.x = 0.0
	elif _slamming:
		sprite.scale = SLAM_DESCENT_SCALE
		sprite.position.x = 0.0
	elif _dash_time_left > 0.0:
		sprite.scale = DASH_SCALE
		sprite.position.x = _facing * DASH_OFFSET_X
	else:
		sprite.scale = Vector2.ONE
		sprite.position.x = 0.0


# ============================================================================
# Wall classification
# ----------------------------------------------------------------------------
# is_on_wall_only() ONLY returns true when move_and_slide last collided into
# a wall (i.e. when input was pushing into it). The moment the player releases
# the direction, the engine stops reporting wall contact, which would cause
# the wall-jump to disappear from under the player.
#
# To fix that we add a short horizontal raycast that detects walls flush
# against us even without active motion-into-wall.
# ============================================================================

func _classify_wall_contact() -> Dictionary:
	var result := {"is_wall": false, "normal_x": 0.0}

	# Primary: read the last move_and_slide collisions, filter to vertical walls.
	if is_on_wall_only():
		for i in range(get_slide_collision_count()):
			var collision := get_slide_collision(i)
			var n: Vector2 = collision.get_normal()
			# Require a near-horizontal normal (this is a vertical wall, not a slope).
			if absf(n.x) <= 0.7:
				continue
			var collider: Object = collision.get_collider()
			if collider == null:
				continue
			var collider_node: Node = collider as Node
			if collider_node == null:
				continue
			# Distinguish wall from platform via collision shape proportions.
			# A "wall" has size_y > size_x (tall rectangle).
			var info: Dictionary = _shape_info(collider_node)
			var size_x: float = info.size_x
			var size_y: float = info.size_y
			if size_y <= size_x:
				continue
			# Filter the just-jumped wall during input lock.
			if _ignore_wall_normal_x != 0.0 and signf(n.x) == signf(_ignore_wall_normal_x):
				continue
			result.is_wall = true
			result.normal_x = n.x
			return result

	# Fallback raycast: detect walls flush against the player when not actively
	# pushing into them. Without this the player loses wall jump the instant
	# they release the directional key.
	if is_on_floor():
		return result
	var space := get_world_2d().direct_space_state
	for normal_x in [1.0, -1.0]:
		if _ignore_wall_normal_x != 0.0 and signf(normal_x) == signf(_ignore_wall_normal_x):
			continue
		var origin: Vector2 = global_position
		var target: Vector2 = origin + Vector2(-normal_x * 9.0, 0.0)
		var query := PhysicsRayQueryParameters2D.create(origin, target)
		query.exclude = [self]
		query.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider: Object = hit.collider
		var collider_node: Node = collider as Node
		if collider_node == null:
			continue
		var info: Dictionary = _shape_info(collider_node)
		var size_x: float = info.size_x
		var size_y: float = info.size_y
		if size_y <= size_x:
			continue
		result.is_wall = true
		result.normal_x = normal_x
		return result
	return result


# Are we standing on top of a one-way platform? Used to enable Drop-Through
# (press slam while grounded on a one-way platform to fall through it).
func _is_on_one_way_platform() -> bool:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var n: Vector2 = collision.get_normal()
		if n.y > -0.7:
			continue  # Not landing-on-top contact.
		var collider: Object = collision.get_collider()
		if collider == null:
			continue
		var collider_node: Node = collider as Node
		if collider_node == null:
			continue
		# Look for a CollisionShape2D child with one_way_collision = true.
		for child in collider_node.get_children():
			if child is CollisionShape2D:
				var cs: CollisionShape2D = child
				if cs.one_way_collision:
					return true
	return false


# Read the rect dimensions of the first CollisionShape2D child of a node.
# Used by wall classification to tell walls (tall) from platforms (wide).
func _shape_info(node: Node) -> Dictionary:
	var info := {"size_x": 0.0, "size_y": 0.0}
	for child in node.get_children():
		if child is CollisionShape2D:
			var cs: CollisionShape2D = child
			if cs.shape is RectangleShape2D:
				var rect: RectangleShape2D = cs.shape
				info.size_x = rect.size.x
				info.size_y = rect.size.y
			break
	return info


# ============================================================================
# Afterimages — ghost sprites for dash/slam motion blur
# ============================================================================

# Duplicate the current sprite, parent it to OUR parent (so it doesn't move
# with us), and fade out over AFTERIMAGE_DURATION. z_index = -1 puts it behind
# the live sprite.
func _spawn_afterimage() -> void:
	var ai := Sprite2D.new()
	ai.texture = sprite.texture
	ai.region_enabled = sprite.region_enabled
	ai.region_rect = sprite.region_rect
	ai.flip_h = sprite.flip_h
	ai.offset = sprite.offset
	ai.scale = sprite.scale
	ai.z_index = -1
	ai.modulate = Color(1.0, 1.0, 1.0, AFTERIMAGE_START_ALPHA)
	get_parent().add_child(ai)
	ai.global_position = sprite.global_position
	var tween := ai.create_tween()
	tween.tween_property(ai, "modulate:a", 0.0, AFTERIMAGE_DURATION)
	tween.tween_callback(ai.queue_free)


# ============================================================================
# Projectiles
# ============================================================================

# Spawn a fruit projectile in front of the player. Direction comes from
# _facing; it stays straight (no gravity).
func _shoot() -> void:
	var fruit := FRUIT_SCENE.instantiate()
	fruit.position = global_position + Vector2(_facing * SHOOT_OFFSET.x, SHOOT_OFFSET.y)
	fruit.direction = _facing
	get_parent().add_child(fruit)
	Audio.play_sfx("tap")


# Normal throw (NOT a lob). Spawns a grenade at THROW_OFFSET with the standard
# initial velocity (gravity arc). set_charge() scales the grenade's explosion
# radius based on how long throw was charged.
func _throw_grenade_charged(charge_seconds: float) -> void:
	var grenade := GRENADE_SCENE.instantiate()
	grenade.position = global_position + Vector2(_facing * THROW_OFFSET.x, THROW_OFFSET.y)
	grenade.direction = _facing
	if grenade.has_method("set_charge"):
		grenade.set_charge(charge_seconds)
	get_parent().add_child(grenade)
	Audio.play_sfx("tap")


# ============================================================================
# Melee swing
# ----------------------------------------------------------------------------
# Fires when the player RELEASES the swing button (or fires immediately on a
# combo). Animates the bat, then runs a one-shot proximity check against
# enemies and grenades. Charge level scales knockback and reach (but not
# damage — bat is fixed at half-damage average via the accumulator).
# ============================================================================

func _do_swing(charge_seconds: float) -> void:
	_swing_cooldown_left = SWING_COOLDOWN
	Audio.play_sfx("tap")
	var dir: Vector2 = _get_swing_direction()
	_animate_bat(dir, charge_seconds)

	# Charge scaling.
	var charge_mult: float = 1.0 + charge_seconds * SWING_CHARGE_KB_MULT_PER_SEC
	var reach: float = SWING_REACH_BASE + charge_seconds * SWING_REACH_PER_CHARGE
	var enemy_kb: float = SWING_KNOCKBACK_ENEMY_BASE * charge_mult
	var grenade_kb: float = SWING_KNOCKBACK_GRENADE_BASE * charge_mult

	# Half-damage accumulator: every other swing actually deals 1 dmg.
	_swing_damage_carry += SWING_DAMAGE_PER_HIT
	var dmg: int = int(floor(_swing_damage_carry))
	_swing_damage_carry -= float(dmg)

	# Enemy hits — knockback always, damage only when accumulator crosses 1.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D and _in_swing_arc(enemy as Node2D, dir, reach):
			var e: Node = enemy
			if e.has_method("apply_knockback"):
				e.call("apply_knockback", dir.x * enemy_kb, dir.y * enemy_kb)
			if dmg > 0 and e.has_method("take_damage"):
				e.call("take_damage", dmg)

	# Grenade hits — knockback only (no damage to grenade), plays "ball-hit" SFX.
	for g in get_tree().get_nodes_in_group("grenade"):
		if g is Node2D and _in_swing_arc(g as Node2D, dir, reach):
			var gn: Node = g
			if gn.has_method("apply_knockback"):
				gn.call("apply_knockback", dir.x * grenade_kb, dir.y * grenade_kb)
				Audio.play_sfx_layered("power_up")


# Grenade-lob combo. Spawns a grenade in front of the player, gives it a small
# upward toss for visual setup, then 0.055s later (mid-swing) applies the main
# bat impulse. set_player_safe(true) makes the grenade phase through the
# player so it can't fall back and detonate on its own thrower.
#
# bat_charge   → scales lob velocity (the "hit strength").
# grenade_charge → scales the grenade's explosion radius (its "size").
func _do_grenade_lob(dir: Vector2, bat_charge: float, grenade_charge: float = 0.0) -> void:
	var grenade := GRENADE_SCENE.instantiate()
	grenade.position = global_position + Vector2(_facing * 2.0, -10.0)
	grenade.direction = 0.0  # Marks this as a lob — grenade._ready skips its normal throw velocity.
	get_parent().add_child(grenade)
	if grenade.has_method("set_player_safe"):
		grenade.set_player_safe(true)
	if grenade.has_method("set_charge"):
		grenade.set_charge(grenade_charge)
	if grenade.has_method("apply_knockback"):
		grenade.apply_knockback(0.0, -90.0)  # Small upward toss so the bat has something to "hit".
	Audio.play_sfx("tap")
	_animate_bat(dir, bat_charge)
	_swing_cooldown_left = SWING_COOLDOWN

	# Schedule the main impulse to land at the visual swing peak. Capturing
	# grenade_ref by closure + is_instance_valid check guards against the
	# grenade being freed before the timer fires (e.g. early detonation).
	var lob_speed: float = SWING_LOB_BASE_SPEED * (1.0 + bat_charge * SWING_LOB_MULT_PER_SEC)
	var grenade_ref: Node = grenade
	get_tree().create_timer(SWING_DURATION * 0.5).timeout.connect(func() -> void:
		if not is_instance_valid(grenade_ref):
			return
		if grenade_ref.has_method("apply_knockback"):
			grenade_ref.call("apply_knockback", dir.x * lob_speed, dir.y * lob_speed)
			Audio.play_sfx_layered("power_up")  # "Crack" of bat on ball.
	)


# Tween the bat polygon along a 120° arc centered roughly on the swing dir.
# The hardcoded angles per cardinal direction were tuned by hand — generalized
# formulas tend to look wrong for one direction or another.
func _animate_bat(dir: Vector2, charge_seconds: float) -> void:
	var start_rot: float
	var end_rot: float
	if dir.y < -0.5:
		# Up swing — windshield-wiper arc overhead, from up-left to up-right.
		start_rot = -3.0 * PI / 4.0
		end_rot = -PI / 4.0
	elif dir.y > 0.5:
		# Down swing — mirror of up: down-left to down-right.
		start_rot = 3.0 * PI / 4.0
		end_rot = PI / 4.0
	elif dir.x < 0.0:
		# Left swing — from straight up sweeping CCW through left to down-left.
		start_rot = -PI / 2.0
		end_rot = -PI - PI / 6.0
	else:
		# Right (default) — from straight up sweeping CW to down-right.
		start_rot = -PI / 2.0
		end_rot = PI / 6.0
	_swing_visual.rotation = start_rot
	_swing_visual.visible = true

	# Charge-based bat appearance: tint toward red + slight scale-up.
	var t: float = clampf(charge_seconds / SWING_CHARGE_MAX, 0.0, 1.0)
	_swing_visual.color = SWING_BAT_COLOR.lerp(SWING_BAT_FULL_COLOR, t)
	_swing_visual.scale = Vector2(1.0 + t * 0.3, 1.0 + t * 0.2)

	var tw := create_tween()
	tw.tween_property(_swing_visual, "rotation", end_rot, SWING_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(_hide_swing_visual)


# Direction the swing aims at. Checks vertical modifiers (jump/slam keys)
# first, then horizontal input, then falls back to player facing.
# Note: pressing jump fires both a jump AND sets the swing direction — that's
# intentional, the player can jump-swing-up in one motion.
func _get_swing_direction() -> Vector2:
	if Input.is_action_pressed("jump"):
		return Vector2(0.0, -1.0)
	if Input.is_action_pressed("slam"):
		return Vector2(0.0, 1.0)
	if Input.is_action_pressed("move_left"):
		return Vector2(-1.0, 0.0)
	if Input.is_action_pressed("move_right"):
		return Vector2(1.0, 0.0)
	return Vector2(_facing, 0.0)


# Is this target within range AND in the swing hemisphere?
#   - Beyond reach → miss.
#   - Within point-blank → hit regardless of facing (forgiving close range).
#   - Otherwise → require the target to be roughly in front of the swing
#     direction. dot > -0.15 is slightly wider than 180° hemisphere (≈198°)
#     to forgive edge-of-arc targets.
func _in_swing_arc(target: Node2D, dir: Vector2, reach: float) -> bool:
	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()
	if dist > reach:
		return false
	if dist < SWING_POINT_BLANK:
		return true
	return to_target.normalized().dot(dir) > -0.15


func _hide_swing_visual() -> void:
	if _swing_visual != null:
		_swing_visual.visible = false


# ============================================================================
# Slam AOE — fires on slam landing
# ----------------------------------------------------------------------------
# Pushes every enemy within SLAM_RADIUS outward from the player along the
# (enemy - player) vector. Magnitude is half the bat's base knockback so a
# slam feels meaningful but distinct from a directional bat hit.
# ============================================================================

func _do_slam_damage() -> void:
	_spawn_slam_ring()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D:
			var e: Node2D = enemy
			var to_enemy: Vector2 = e.global_position - global_position
			# Sphere AOE: Euclidean distance, so airborne enemies above the
			# player are picked up the same as enemies to the side.
			if to_enemy.length() <= SLAM_RADIUS:
				# Direction from player to enemy. If overlapping, fall back to
				# a forward+slightly-up vector so the enemy still gets shoved.
				var dir: Vector2
				if to_enemy.length() > 0.01:
					dir = to_enemy.normalized()
				else:
					dir = Vector2(_facing, -0.5).normalized()
				if e.has_method("apply_knockback"):
					e.call("apply_knockback", dir.x * SLAM_KNOCKBACK, dir.y * SLAM_KNOCKBACK)
				if e.has_method("take_damage"):
					e.take_damage(SLAM_DAMAGE)
				else:
					e.queue_free()


# Pale-blue shockwave ring that snaps out to SLAM_RADIUS over SLAM_RING_DURATION,
# then fades. Parented to our parent so it stays at the impact point even
# though the player keeps moving.
func _spawn_slam_ring() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var pts: PackedVector2Array = []
	for i in range(SLAM_RING_SEGMENTS):
		var a: float = TAU * float(i) / float(SLAM_RING_SEGMENTS)
		pts.append(Vector2(cos(a), sin(a)) * SLAM_RADIUS)
	var ring := Polygon2D.new()
	ring.polygon = pts
	ring.color = SLAM_RING_COLOR
	ring.scale = Vector2(0.05, 0.05)
	ring.z_index = 5
	parent.add_child(ring)
	ring.global_position = global_position

	var scale_tw := ring.create_tween()
	scale_tw.tween_property(ring, "scale", Vector2.ONE, SLAM_RING_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fade_tw := ring.create_tween()
	fade_tw.tween_property(ring, "modulate:a", 0.0, SLAM_RING_DURATION)
	fade_tw.tween_callback(ring.queue_free)
