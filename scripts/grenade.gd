extends CharacterBody2D

const THROW_SPEED_X := 200.0
const THROW_SPEED_Y := -180.0
const GRAVITY := 700.0
const EXPLOSION_RADIUS := 48.0
const CONTACT_RADIUS := 9.0
const PLAYER_CONTACT_RADIUS := 12.0
const PLAYER_DAMAGE := 2
const ENEMY_DAMAGE := 2
const BOUNCE_DAMP := 0.55
const LIFETIME := 5.0
const ARM_TIME := 0.15
const TRAIL_INTERVAL := 0.04
const TRAIL_DURATION := 0.28

const CLOUD_BALL_COUNT := 48
const CLOUD_BALL_RADIUS := 3.0
const CLOUD_DURATION := 0.45
const CLOUD_COLOR := Color(1.0, 0.6, 0.15, 1.0)

var direction: float = 1.0
var _trail_timer := 0.0
var _life_left := LIFETIME
var _arm_left := ARM_TIME
var _exploded := false


func _ready() -> void:
	velocity = Vector2(direction * THROW_SPEED_X, THROW_SPEED_Y)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_arm_left = max(0.0, _arm_left - delta)
	velocity.y += GRAVITY * delta
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var collider: Object = collision.get_collider()
		if _arm_left <= 0.0 and collider != null and (collider as Node).is_in_group("player"):
			_explode()
			return
		velocity = velocity.bounce(collision.get_normal()) * BOUNCE_DAMP

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D and global_position.distance_to((enemy as Node2D).global_position) <= CONTACT_RADIUS:
			_explode()
			return

	if _arm_left <= 0.0:
		var p := get_tree().get_first_node_in_group("player")
		if p is Node2D and global_position.distance_to((p as Node2D).global_position) <= PLAYER_CONTACT_RADIUS:
			_explode()
			return

	for f in get_tree().get_nodes_in_group("fruit"):
		if f is Node2D and global_position.distance_to((f as Node2D).global_position) <= CONTACT_RADIUS + 3.0:
			_explode()
			return

	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_spawn_trail()
		_trail_timer = TRAIL_INTERVAL

	_life_left -= delta
	if _life_left <= 0.0:
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	Audio.play_sfx("explosion")
	_spawn_explosion_cloud()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D:
			var e: Node2D = enemy
			if global_position.distance_to(e.global_position) <= EXPLOSION_RADIUS:
				if e.has_method("take_damage"):
					e.take_damage(ENEMY_DAMAGE)
				else:
					e.queue_free()
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D and player.has_method("take_damage"):
		if global_position.distance_to((player as Node2D).global_position) <= EXPLOSION_RADIUS:
			player.take_damage(PLAYER_DAMAGE)
	queue_free()


func _circle_polygon(r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in range(10):
		var a: float = TAU * float(i) / 10.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _spawn_explosion_cloud() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var poly_pts: PackedVector2Array = _circle_polygon(CLOUD_BALL_RADIUS)
	var center: Vector2 = global_position
	for i in range(CLOUD_BALL_COUNT):
		var ball := Polygon2D.new()
		ball.polygon = poly_pts
		ball.color = CLOUD_COLOR
		ball.z_index = 5
		ball.scale = Vector2(0.3, 0.3)
		parent.add_child(ball)
		var ang: float = randf() * TAU
		var dist: float = sqrt(randf()) * EXPLOSION_RADIUS
		ball.global_position = center + Vector2(cos(ang), sin(ang)) * dist
		var tween := ball.create_tween().set_parallel(true)
		tween.tween_property(ball, "scale", Vector2(1.3, 1.3), CLOUD_DURATION)
		tween.tween_property(ball, "modulate:a", 0.0, CLOUD_DURATION)
		tween.chain().tween_callback(ball.queue_free)


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
