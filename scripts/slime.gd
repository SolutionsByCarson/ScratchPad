extends Area2D

const HURT_COOLDOWN := 0.6
const WANDER_SPEED := 24.0
const CHASE_SPEED := 56.0
const DETECT_RADIUS := 80.0
const WORLD_MIN_X := 16.0
const WORLD_MAX_X := 944.0

@onready var sprite: Sprite2D = $Sprite2D

var _hurt_cooldown_left := 0.0
var _wander_direction := 0
var _wander_change_left := 0.0
var _initial_x := 0.0
var _wander_radius := 48.0


func _ready() -> void:
	add_to_group("enemy")
	body_entered.connect(_on_body_entered)
	_initial_x = position.x
	_pick_new_wander_direction()


func _process(delta: float) -> void:
	_hurt_cooldown_left = max(0.0, _hurt_cooldown_left - delta)

	var player: Node2D = get_tree().get_first_node_in_group("player")
	var move_dir: float = 0.0
	var move_speed: float = WANDER_SPEED

	if player != null:
		var player_pos: Vector2 = player.global_position
		var dx: float = player_pos.x - global_position.x
		var dy: float = player_pos.y - global_position.y
		var dist_sq: float = dx * dx + dy * dy
		if dist_sq < DETECT_RADIUS * DETECT_RADIUS:
			move_dir = signf(dx)
			move_speed = CHASE_SPEED
		else:
			move_dir = _update_wander(delta)
	else:
		move_dir = _update_wander(delta)

	position.x += move_dir * move_speed * delta
	position.x = clamp(position.x, WORLD_MIN_X, WORLD_MAX_X)

	if move_dir != 0.0:
		sprite.flip_h = move_dir < 0.0


func _update_wander(delta: float) -> float:
	_wander_change_left -= delta
	if _wander_change_left <= 0.0:
		_pick_new_wander_direction()

	var bound_min := _initial_x - _wander_radius
	var bound_max := _initial_x + _wander_radius
	if position.x <= bound_min:
		_wander_direction = 1
	elif position.x >= bound_max:
		_wander_direction = -1

	return float(_wander_direction)


func _pick_new_wander_direction() -> void:
	_wander_change_left = randf_range(1.0, 3.0)
	var choices: Array[int] = [-1, 0, 1]
	_wander_direction = choices.pick_random()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and _hurt_cooldown_left <= 0.0:
		_hurt_cooldown_left = HURT_COOLDOWN
		Audio.play_sfx("hurt")
