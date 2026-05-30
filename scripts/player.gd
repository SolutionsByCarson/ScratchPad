extends CharacterBody2D

const SPEED := 140.0
const JUMP_VELOCITY := -350.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.10

const DASH_SPEED := 320.0
const DASH_DURATION := 0.17
const DASH_COOLDOWN := 0.5
const DASH_DODGE_GRACE := 0.08

const WALL_STICK_TIME := 0.20
const WALL_SLIDE_MAX_FALL := 80.0
const WALL_JUMP_PUSH_X := 220.0
const WALL_JUMP_VELOCITY := -300.0
const WALL_JUMP_INPUT_LOCK := 0.22
const WALL_GRACE_TIME := 0.06

const SLAM_SPEED := 500.0
const SLAM_RADIUS := 36.0
const SLAM_LAND_DURATION := 0.18
const SLAM_DAMAGE := 4

const DASH_SCALE := Vector2(1.45, 0.7)
const SLAM_DESCENT_SCALE := Vector2(0.65, 1.45)
const SLAM_LAND_SCALE := Vector2(1.55, 0.55)
const DASH_OFFSET_X := 4.0
const AFTERIMAGE_INTERVAL := 0.05
const AFTERIMAGE_DURATION := 0.22
const AFTERIMAGE_START_ALPHA := 0.55

const FRUIT_SCENE := preload("res://scenes/fruit.tscn")
const SHOOT_OFFSET := Vector2(12.0, -3.0)
const GRENADE_SCENE := preload("res://scenes/grenade.tscn")
const THROW_OFFSET := Vector2(16.0, -6.0)
const THROW_CHARGE_MAX := 3.0

const MAX_HEALTH := 3
const INVULN_TIME := 1.0
const FALL_DEATH_Y := 350.0

const SWING_DURATION := 0.11
const SWING_COOLDOWN := 0.24
const SWING_REACH_BASE := 52.0
const SWING_REACH_PER_CHARGE := 3.0
const SWING_POINT_BLANK := 14.0
const SWING_KNOCKBACK_ENEMY_BASE := 320.0
const SWING_KNOCKBACK_GRENADE_BASE := 360.0
const SWING_CHARGE_MAX := 3.0
const SWING_CHARGE_KB_MULT_PER_SEC := 0.2
const SWING_DAMAGE := 1
const SWING_BAT_LENGTH := 24.0
const SWING_BAT_THICKNESS := 5.0
const SWING_BAT_COLOR := Color(0.75, 0.5, 0.2, 1.0)
const SWING_BAT_FULL_COLOR := Color(1.0, 0.3, 0.15, 1.0)
const SWING_LOB_BASE_SPEED := 460.0
const SWING_LOB_MULT_PER_SEC := 0.15

@onready var sprite: Sprite2D = $Sprite2D

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _facing := 1.0
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_grace_left := 0.0
var _wall_stick_left := WALL_STICK_TIME
var _wall_jump_lock_left := 0.0
var _slamming := false
var _slam_land_timer := 0.0
var _afterimage_timer := 0.0
var _ignore_wall_normal_x := 0.0
var _wall_grace_left := 0.0
var _last_wall_normal_x := 0.0
var _wall_attached := false
var _wall_attached_normal_x := 0.0
var _health := MAX_HEALTH
var _invuln_left := 0.0
var _hp_label: Label
var _throw_charging := false
var _throw_charge := 0.0
var _last_charge_tick := 0
var _charge_label: Label
var _swing_cooldown_left := 0.0
var _swing_visual: Polygon2D
var _swing_charging := false
var _swing_charge := 0.0
var _last_swing_tick := 0


func _ready() -> void:
	add_to_group("player")
	_setup_hp_ui()
	_update_hp_ui()
	_setup_charge_ui()
	_setup_swing_visual()


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
	_swing_visual.position = Vector2(0.0, -2.0)
	_swing_visual.visible = false
	add_child(_swing_visual)


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


func _flash_red() -> void:
	sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)


func _die() -> void:
	get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	_update_visual_scale(delta)

	_invuln_left = max(0.0, _invuln_left - delta)
	if global_position.y > FALL_DEATH_Y:
		_die()
		return

	_wall_jump_lock_left = max(0.0, _wall_jump_lock_left - delta)
	if _wall_jump_lock_left <= 0.0:
		_ignore_wall_normal_x = 0.0

	var input_dir := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()
	var contact: Dictionary = _classify_wall_contact()
	var on_vertical_wall: bool = contact.is_wall
	var contact_normal_x: float = contact.normal_x
	if on_vertical_wall and _ignore_wall_normal_x != 0.0 and signf(contact_normal_x) != signf(_ignore_wall_normal_x):
		_ignore_wall_normal_x = 0.0
	if on_vertical_wall:
		_wall_grace_left = WALL_GRACE_TIME
		_last_wall_normal_x = contact_normal_x
	else:
		_wall_grace_left = max(0.0, _wall_grace_left - delta)
	var pressing_into_contact: bool = contact_normal_x != 0.0 and input_dir != 0.0 and signf(input_dir) != signf(contact_normal_x)
	var wall_clinging: bool = on_vertical_wall and pressing_into_contact and velocity.y >= 0.0

	if wall_clinging:
		_wall_attached = true
		_wall_attached_normal_x = contact_normal_x
	if on_floor:
		_wall_attached = false
	elif not on_vertical_wall:
		_wall_attached = false
	elif _wall_attached and signf(contact_normal_x) != signf(_wall_attached_normal_x):
		_wall_attached = false
	elif _wall_attached and input_dir != 0.0 and signf(input_dir) == signf(_wall_attached_normal_x):
		_wall_attached = false

	if not _wall_attached and _dash_time_left <= 0.0 and Input.is_action_just_pressed("shoot"):
		_shoot()

	_swing_cooldown_left = max(0.0, _swing_cooldown_left - delta)
	if Input.is_action_just_pressed("swing"):
		if _throw_charging:
			var existing_g2 := get_tree().get_first_node_in_group("grenade")
			if existing_g2 == null:
				_do_grenade_lob(_get_swing_direction(), 0.0, _throw_charge)
				_throw_charging = false
				_throw_charge = 0.0
				if _charge_label != null:
					_charge_label.visible = false
		elif not _swing_charging and not _wall_attached \
				and _dash_time_left <= 0.0 and _swing_cooldown_left <= 0.0:
			_swing_charging = true
			_swing_charge = 0.0
			_last_swing_tick = 0
			if _charge_label != null:
				_charge_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 1.0))
				_charge_label.text = "0"
				_charge_label.visible = true
	if _swing_charging:
		if Input.is_action_pressed("swing"):
			_swing_charge = min(_swing_charge + delta, SWING_CHARGE_MAX)
			var sci: int = int(floor(_swing_charge))
			if sci != _last_swing_tick:
				_last_swing_tick = sci
				Audio.play_sfx("power_up")
			if _charge_label != null:
				_charge_label.text = str(sci)
		else:
			_do_swing(_swing_charge)
			_swing_charging = false
			_swing_charge = 0.0
			if _charge_label != null:
				_charge_label.visible = false

	if Input.is_action_just_pressed("throw"):
		if _swing_charging:
			var existing_g := get_tree().get_first_node_in_group("grenade")
			if existing_g == null:
				_do_grenade_lob(_get_swing_direction(), _swing_charge)
				_swing_charging = false
				_swing_charge = 0.0
				if _charge_label != null:
					_charge_label.visible = false
		elif not _throw_charging:
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
			_throw_charge = min(_throw_charge + delta, THROW_CHARGE_MAX)
			var charge_int: int = int(floor(_throw_charge))
			if charge_int != _last_charge_tick:
				_last_charge_tick = charge_int
				Audio.play_sfx("coin")
			if _charge_label != null:
				_charge_label.text = str(charge_int)
		else:
			_throw_grenade_charged(_throw_charge)
			_throw_charging = false
			_throw_charge = 0.0
			if _charge_label != null:
				_charge_label.visible = false

	_dash_cooldown_left = max(0.0, _dash_cooldown_left - delta)

	if not _wall_attached and Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0 and _dash_time_left <= 0.0:
		if input_dir != 0.0:
			_facing = input_dir
			sprite.flip_h = input_dir < 0.0
		_dash_time_left = DASH_DURATION
		_dash_cooldown_left = DASH_COOLDOWN
		_dash_grace_left = 0.0
		_afterimage_timer = 0.0
		add_to_group("dashing")
		Audio.play_sfx("power_up")

	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_spawn_afterimage()
			_afterimage_timer = AFTERIMAGE_INTERVAL
		velocity.x = _facing * DASH_SPEED
		velocity.y = 0.0
		move_and_slide()
		if _dash_time_left <= 0.0:
			_dash_grace_left = DASH_DODGE_GRACE
		return

	if _dash_grace_left > 0.0:
		_dash_grace_left -= delta
		if _dash_grace_left <= 0.0 and is_in_group("dashing"):
			remove_from_group("dashing")

	if is_on_floor() and Input.is_action_just_pressed("slam") and _is_on_one_way_platform():
		global_position.y += 2.0

	if not is_on_floor() and not _slamming and Input.is_action_just_pressed("slam"):
		_slamming = true
		velocity.x = 0.0
		velocity.y = SLAM_SPEED
		_afterimage_timer = 0.0

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
			return

	if on_floor:
		_coyote_timer = COYOTE_TIME
		_wall_stick_left = WALL_STICK_TIME
	elif _wall_attached and _wall_stick_left > 0.0:
		velocity.y = 0.0
		_wall_stick_left -= delta
		_coyote_timer = 0.0
	elif _wall_attached:
		velocity += get_gravity() * delta
		velocity.y = min(velocity.y, WALL_SLIDE_MAX_FALL)
		_coyote_timer = 0.0
	else:
		velocity += get_gravity() * delta
		_coyote_timer -= delta
		if not on_vertical_wall:
			_wall_stick_left = WALL_STICK_TIME

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER
	else:
		_jump_buffer_timer -= delta

	var can_wall_jump: bool = not on_floor and (on_vertical_wall or _wall_grace_left > 0.0)
	var jump_normal_x: float = contact_normal_x if on_vertical_wall else _last_wall_normal_x
	if _jump_buffer_timer > 0.0 and can_wall_jump and jump_normal_x != 0.0:
		velocity.x = jump_normal_x * WALL_JUMP_PUSH_X
		velocity.y = WALL_JUMP_VELOCITY
		_wall_jump_lock_left = WALL_JUMP_INPUT_LOCK
		_ignore_wall_normal_x = jump_normal_x
		_wall_grace_left = 0.0
		_wall_attached = false
		_facing = jump_normal_x
		sprite.flip_h = jump_normal_x < 0.0
		_jump_buffer_timer = 0.0
		_wall_stick_left = WALL_STICK_TIME
		Audio.play_sfx("jump")
	elif _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		Audio.play_sfx("jump")

	if not _wall_attached and _wall_jump_lock_left <= 0.0:
		if input_dir != 0.0:
			velocity.x = input_dir * SPEED
			sprite.flip_h = input_dir < 0.0
			_facing = input_dir
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()


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


func _classify_wall_contact() -> Dictionary:
	var result := {"is_wall": false, "normal_x": 0.0}
	if is_on_wall_only():
		for i in range(get_slide_collision_count()):
			var collision := get_slide_collision(i)
			var n: Vector2 = collision.get_normal()
			if absf(n.x) <= 0.7:
				continue
			var collider: Object = collision.get_collider()
			if collider == null:
				continue
			var collider_node: Node = collider as Node
			if collider_node == null:
				continue
			var info: Dictionary = _shape_info(collider_node)
			var size_x: float = info.size_x
			var size_y: float = info.size_y
			if size_y <= size_x:
				continue
			if _ignore_wall_normal_x != 0.0 and signf(n.x) == signf(_ignore_wall_normal_x):
				continue
			result.is_wall = true
			result.normal_x = n.x
			return result

	# Fallback: short horizontal rays to detect walls flush against the
	# player even when no motion-into-wall is active (player not pressing
	# direction). is_on_wall_only() only fires when move_and_slide last
	# pushed into a wall, so without this the player would lose wall jump
	# the moment they release direction.
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


func _is_on_one_way_platform() -> bool:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var n: Vector2 = collision.get_normal()
		if n.y > -0.7:
			continue
		var collider: Object = collision.get_collider()
		if collider == null:
			continue
		var collider_node: Node = collider as Node
		if collider_node == null:
			continue
		for child in collider_node.get_children():
			if child is CollisionShape2D:
				var cs: CollisionShape2D = child
				if cs.one_way_collision:
					return true
	return false


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


func _shoot() -> void:
	var fruit := FRUIT_SCENE.instantiate()
	fruit.position = global_position + Vector2(_facing * SHOOT_OFFSET.x, SHOOT_OFFSET.y)
	fruit.direction = _facing
	get_parent().add_child(fruit)
	Audio.play_sfx("tap")


func _throw_grenade_charged(charge_seconds: float) -> void:
	var grenade := GRENADE_SCENE.instantiate()
	grenade.position = global_position + Vector2(_facing * THROW_OFFSET.x, THROW_OFFSET.y)
	grenade.direction = _facing
	if grenade.has_method("set_charge"):
		grenade.set_charge(charge_seconds)
	get_parent().add_child(grenade)
	Audio.play_sfx("tap")


func _do_swing(charge_seconds: float) -> void:
	_swing_cooldown_left = SWING_COOLDOWN
	Audio.play_sfx("tap")
	var dir: Vector2 = _get_swing_direction()
	_animate_bat(dir, charge_seconds)

	var charge_mult: float = 1.0 + charge_seconds * SWING_CHARGE_KB_MULT_PER_SEC
	var reach: float = SWING_REACH_BASE + charge_seconds * SWING_REACH_PER_CHARGE
	var enemy_kb: float = SWING_KNOCKBACK_ENEMY_BASE * charge_mult
	var grenade_kb: float = SWING_KNOCKBACK_GRENADE_BASE * charge_mult

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D and _in_swing_arc(enemy as Node2D, dir, reach):
			var e: Node = enemy
			if e.has_method("apply_knockback"):
				e.call("apply_knockback", dir.x * enemy_kb, dir.y * enemy_kb)
			if e.has_method("take_damage"):
				e.call("take_damage", SWING_DAMAGE)

	for g in get_tree().get_nodes_in_group("grenade"):
		if g is Node2D and _in_swing_arc(g as Node2D, dir, reach):
			var gn: Node = g
			if gn.has_method("apply_knockback"):
				gn.call("apply_knockback", dir.x * grenade_kb, dir.y * grenade_kb)
				Audio.play_sfx_layered("power_up")


func _do_grenade_lob(dir: Vector2, bat_charge: float, grenade_charge: float = 0.0) -> void:
	var grenade := GRENADE_SCENE.instantiate()
	grenade.position = global_position + Vector2(_facing * 2.0, -10.0)
	grenade.direction = 0.0
	get_parent().add_child(grenade)
	if grenade.has_method("set_player_safe"):
		grenade.set_player_safe(true)
	if grenade.has_method("set_charge"):
		grenade.set_charge(grenade_charge)
	if grenade.has_method("apply_knockback"):
		grenade.apply_knockback(0.0, -90.0)
	Audio.play_sfx("tap")
	_animate_bat(dir, bat_charge)
	_swing_cooldown_left = SWING_COOLDOWN
	var lob_speed: float = SWING_LOB_BASE_SPEED * (1.0 + bat_charge * SWING_LOB_MULT_PER_SEC)
	var grenade_ref: Node = grenade
	get_tree().create_timer(SWING_DURATION * 0.5).timeout.connect(func() -> void:
		if not is_instance_valid(grenade_ref):
			return
		if grenade_ref.has_method("apply_knockback"):
			grenade_ref.call("apply_knockback", dir.x * lob_speed, dir.y * lob_speed)
			Audio.play_sfx_layered("power_up")
	)


func _animate_bat(dir: Vector2, charge_seconds: float) -> void:
	var start_rot: float
	var end_rot: float
	if dir.y < -0.5:
		start_rot = -3.0 * PI / 4.0
		end_rot = -PI / 4.0
	elif dir.y > 0.5:
		start_rot = 3.0 * PI / 4.0
		end_rot = PI / 4.0
	elif dir.x < 0.0:
		start_rot = -PI / 2.0
		end_rot = -PI - PI / 6.0
	else:
		start_rot = -PI / 2.0
		end_rot = PI / 6.0
	_swing_visual.rotation = start_rot
	_swing_visual.visible = true
	var t: float = clampf(charge_seconds / SWING_CHARGE_MAX, 0.0, 1.0)
	_swing_visual.color = SWING_BAT_COLOR.lerp(SWING_BAT_FULL_COLOR, t)
	_swing_visual.scale = Vector2(1.0 + t * 0.3, 1.0 + t * 0.2)
	var tw := create_tween()
	tw.tween_property(_swing_visual, "rotation", end_rot, SWING_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(_hide_swing_visual)


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


func _in_swing_arc(target: Node2D, dir: Vector2, reach: float) -> bool:
	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()
	if dist > reach:
		return false
	# Point-blank: always hit anything inside this radius regardless of facing.
	if dist < SWING_POINT_BLANK:
		return true
	# Otherwise require the target to be roughly in the swing hemisphere.
	# dot > -0.15 widens it from 180° to ~198° for a more forgiving arc.
	return to_target.normalized().dot(dir) > -0.15


func _hide_swing_visual() -> void:
	if _swing_visual != null:
		_swing_visual.visible = false


func _do_slam_damage() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D:
			var e: Node2D = enemy
			if global_position.distance_to(e.global_position) <= SLAM_RADIUS:
				if e.has_method("take_damage"):
					e.take_damage(SLAM_DAMAGE)
				else:
					e.queue_free()
