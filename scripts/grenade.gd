extends CharacterBody2D

const THROW_SPEED_X := 200.0
const THROW_SPEED_Y := -180.0
const GRAVITY := 700.0
const BASE_EXPLOSION_RADIUS := 48.0
const CHARGE_RADIUS_PER_SEC := 100.0 / 3.0
const CHARGE_MAX_TIME := 3.0
const WAVE_SPEED := 260.0
const CONTACT_RADIUS := 16.0
const PLAYER_CONTACT_RADIUS := 12.0
const PLAYER_DAMAGE := 8
const ENEMY_DAMAGE := 8
const BOUNCE_DAMP := 0.55
const LIFETIME := 5.0
const ARM_TIME := 0.15
const TRAIL_INTERVAL := 0.04
const TRAIL_DURATION := 0.28

const BLAST_COLOR := Color(1.0, 0.15, 0.15, 0.8)
const BLAST_SEGMENTS := 32
const PRIME_DELAY := 0.09
const TIMEOUT_BLINK_DURATION := 0.6
const TIMEOUT_BLINK_COUNT := 3

const KNOCKBACK_DURATION := 0.18
const GRAVITY_SUSPEND_DURATION := 0.12
const GROUNDED_AUTO_LIFT_VY := -160.0
const GROUND_PROBE_DISTANCE := 7.0

var direction: float = 1.0
var explosion_radius: float = BASE_EXPLOSION_RADIUS
var _trail_timer := 0.0
var _life_left := LIFETIME
var _arm_left := ARM_TIME
var _exploded := false
var _priming := false
var _wave_radius := 0.0
var _wave_duration := 0.0
var _damaged: Array = []
var _blink_started := false
var _blink_tween: Tween
var _player_safe := false
var _knockback_timer := 0.0
var _gravity_suspend_timer := 0.0


func _ready() -> void:
	add_to_group("grenade")
	if direction != 0.0:
		velocity = Vector2(direction * THROW_SPEED_X, THROW_SPEED_Y)


func set_charge(seconds: float) -> void:
	var s: float = clampf(seconds, 0.0, CHARGE_MAX_TIME)
	explosion_radius = BASE_EXPLOSION_RADIUS + s * CHARGE_RADIUS_PER_SEC
	var visual: Polygon2D = get_node_or_null("Visual") as Polygon2D
	if visual != null:
		var t: float = s / CHARGE_MAX_TIME
		visual.modulate = Color(1.0, 1.0 - 0.5 * t, 1.0 - 0.8 * t, 1.0)


func detonate() -> void:
	_prime_explode()


func apply_knockback(vx: float, vy: float = 0.0) -> void:
	if _exploded or _priming:
		return
	var grounded: bool = _check_grounded()
	var kb_y: float = vy
	if grounded:
		# Auto-lift so a flat horizontal swing still pops a resting grenade off the floor.
		kb_y = min(kb_y, GROUNDED_AUTO_LIFT_VY)
		velocity = Vector2(vx, kb_y)
	else:
		velocity += Vector2(vx, kb_y)
	_knockback_timer = KNOCKBACK_DURATION
	_gravity_suspend_timer = GRAVITY_SUSPEND_DURATION


func _check_grounded() -> bool:
	var space := get_world_2d().direct_space_state
	var origin: Vector2 = global_position
	var target: Vector2 = origin + Vector2(0.0, GROUND_PROBE_DISTANCE)
	var query := PhysicsRayQueryParameters2D.create(origin, target)
	query.exclude = [self]
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty()


func set_player_safe(safe: bool) -> void:
	_player_safe = safe
	if safe:
		var player := get_tree().get_first_node_in_group("player")
		if player is PhysicsBody2D:
			add_collision_exception_with(player)


func _prime_explode(immediate_target: Node = null) -> void:
	if _exploded or _priming:
		return
	_priming = true
	velocity = Vector2.ZERO
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	Audio.play_sfx("tap")
	var visual: Polygon2D = get_node_or_null("Visual") as Polygon2D
	if visual != null:
		visual.color = Color(1.0, 1.0, 1.0, 1.0)
		visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if immediate_target != null and not _damaged.has(immediate_target):
		_damaged.append(immediate_target)
		if immediate_target.has_method("take_damage"):
			if immediate_target.is_in_group("player"):
				immediate_target.take_damage(PLAYER_DAMAGE)
			else:
				immediate_target.take_damage(ENEMY_DAMAGE)
		elif not immediate_target.is_in_group("player"):
			immediate_target.queue_free()
	# take_damage on the player can call _die() → reload_current_scene(),
	# which removes us from the tree mid-function. Bail out cleanly.
	if not is_inside_tree():
		return
	get_tree().create_timer(PRIME_DELAY).timeout.connect(_explode)


func _start_timeout_blink() -> void:
	var visual: Polygon2D = get_node_or_null("Visual") as Polygon2D
	if visual == null:
		return
	var base_color: Color = visual.color
	var flash_color := Color(1.0, 1.0, 1.0, 1.0)
	var half: float = TIMEOUT_BLINK_DURATION / float(TIMEOUT_BLINK_COUNT * 2)
	_blink_tween = create_tween()
	for i in range(TIMEOUT_BLINK_COUNT):
		_blink_tween.tween_property(visual, "color", flash_color, half)
		_blink_tween.tween_property(visual, "color", base_color, half)


func _physics_process(delta: float) -> void:
	if _exploded:
		_tick_wave(delta)
		return
	if _priming:
		return
	_arm_left = max(0.0, _arm_left - delta)
	_knockback_timer = max(0.0, _knockback_timer - delta)
	_gravity_suspend_timer = max(0.0, _gravity_suspend_timer - delta)
	if _gravity_suspend_timer <= 0.0:
		velocity.y += GRAVITY * delta
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var collider: Object = collision.get_collider()
		var collider_node: Node = collider as Node
		var player_contact: bool = collider_node != null and collider_node.is_in_group("player")
		var dodging: bool = player_contact and collider_node.is_in_group("dashing")
		if _arm_left <= 0.0 and player_contact and not dodging and not _player_safe:
			_prime_explode(collider_node)
			return
		if _knockback_timer > 0.0:
			# Slide along the surface instead of bouncing, so the floor doesn't eat
			# the horizontal energy of a fresh knockback impulse.
			velocity = velocity.slide(collision.get_normal())
		else:
			velocity = velocity.bounce(collision.get_normal()) * BOUNCE_DAMP

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D and global_position.distance_to((enemy as Node2D).global_position) <= CONTACT_RADIUS:
			_prime_explode(enemy)
			return

	if _arm_left <= 0.0 and not _player_safe:
		var p := get_tree().get_first_node_in_group("player")
		if p is Node2D and not (p as Node).is_in_group("dashing") \
				and global_position.distance_to((p as Node2D).global_position) <= PLAYER_CONTACT_RADIUS:
			_prime_explode(p)
			return

	for f in get_tree().get_nodes_in_group("fruit"):
		if f is Node2D and global_position.distance_to((f as Node2D).global_position) <= CONTACT_RADIUS + 3.0:
			_prime_explode()
			return

	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_spawn_trail()
		_trail_timer = TRAIL_INTERVAL

	_life_left -= delta
	if not _blink_started and _life_left <= TIMEOUT_BLINK_DURATION and _life_left > 0.0:
		_blink_started = true
		_start_timeout_blink()
	if _life_left <= 0.0:
		_prime_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_wave_duration = explosion_radius / WAVE_SPEED
	_wave_radius = 0.0
	Audio.play_sfx("explosion")
	_spawn_explosion_ring()
	remove_from_group("grenade")
	var visual := get_node_or_null("Visual") as CanvasItem
	if visual != null:
		visual.visible = false
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs != null:
		cs.set_deferred("disabled", true)


func _tick_wave(delta: float) -> void:
	_wave_radius = min(_wave_radius + WAVE_SPEED * delta, explosion_radius)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if _damaged.has(enemy):
			continue
		if enemy is Node2D and global_position.distance_to((enemy as Node2D).global_position) <= _wave_radius:
			_damaged.append(enemy)
			var e: Node = enemy
			if e.has_method("take_damage"):
				e.take_damage(ENEMY_DAMAGE)
			else:
				e.queue_free()
	var player := get_tree().get_first_node_in_group("player")
	if player != null and not _damaged.has(player):
		if player is Node2D and global_position.distance_to((player as Node2D).global_position) <= _wave_radius:
			_damaged.append(player)
			if (player as Node).has_method("take_damage"):
				(player as Node).take_damage(PLAYER_DAMAGE)
	if _wave_radius >= explosion_radius:
		queue_free()


func _spawn_explosion_ring() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var pts: PackedVector2Array = []
	for i in range(BLAST_SEGMENTS):
		var a: float = TAU * float(i) / float(BLAST_SEGMENTS)
		pts.append(Vector2(cos(a), sin(a)) * explosion_radius)
	var ring := Polygon2D.new()
	ring.polygon = pts
	ring.color = BLAST_COLOR
	ring.scale = Vector2(0.05, 0.05)
	ring.z_index = 5
	parent.add_child(ring)
	ring.global_position = global_position

	var scale_tw := ring.create_tween()
	scale_tw.tween_property(ring, "scale", Vector2.ONE, _wave_duration) \
		.set_trans(Tween.TRANS_LINEAR)

	var flash_time: float = _wave_duration / 6.0
	var flash_tw := ring.create_tween()
	flash_tw.tween_property(ring, "modulate:a", 0.25, flash_time)
	flash_tw.tween_property(ring, "modulate:a", 1.0, flash_time)
	flash_tw.tween_property(ring, "modulate:a", 0.25, flash_time)
	flash_tw.tween_property(ring, "modulate:a", 1.0, flash_time)
	flash_tw.tween_property(ring, "modulate:a", 0.0, flash_time * 2.0)
	flash_tw.tween_callback(ring.queue_free)


func _spawn_trail() -> void:
	var src: Polygon2D = get_node_or_null("Visual") as Polygon2D
	if src == null:
		return
	var ghost: Polygon2D = src.duplicate()
	ghost.z_index = -1
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.55)
	get_parent().add_child(ghost)
	ghost.global_position = src.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, TRAIL_DURATION)
	tween.tween_callback(ghost.queue_free)
