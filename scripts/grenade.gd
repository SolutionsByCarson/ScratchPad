extends Area2D

const THROW_SPEED_X := 200.0
const THROW_SPEED_Y := -260.0
const GRAVITY := 700.0
const EXPLOSION_RADIUS := 48.0
const TRAIL_INTERVAL := 0.04
const TRAIL_DURATION := 0.28
const LIFETIME := 4.0

var direction: float = 1.0
var _velocity: Vector2 = Vector2.ZERO
var _trail_timer := 0.0
var _life_left := LIFETIME
var _exploded := false


func _ready() -> void:
	_velocity = Vector2(direction * THROW_SPEED_X, THROW_SPEED_Y)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_velocity.y += GRAVITY * delta
	position += _velocity * delta
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_spawn_trail()
		_trail_timer = TRAIL_INTERVAL
	_life_left -= delta
	if _life_left <= 0.0:
		_explode()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	Audio.play_sfx("explosion")
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D:
			var e: Node2D = enemy
			if global_position.distance_to(e.global_position) <= EXPLOSION_RADIUS:
				e.queue_free()
	queue_free()


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
