extends Area2D

const SPEED := 250.0
const LIFETIME := 1.5
const TRAIL_INTERVAL := 0.04
const TRAIL_DURATION := 0.22

var direction: float = 1.0
var _life_left := LIFETIME
var _trail_timer := 0.0


func _ready() -> void:
	add_to_group("fruit")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_spawn_trail()
		_trail_timer = TRAIL_INTERVAL


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		Audio.play_sfx("explosion")
		area.queue_free()
		queue_free()


func _spawn_trail() -> void:
	var src: Polygon2D = get_node_or_null("Visual") as Polygon2D
	if src == null:
		return
	var ghost: Polygon2D = src.duplicate()
	ghost.z_index = -1
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.5)
	get_parent().add_child(ghost)
	ghost.global_position = src.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, TRAIL_DURATION)
	tween.tween_callback(ghost.queue_free)
