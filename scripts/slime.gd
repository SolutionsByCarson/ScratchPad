extends Area2D

@export var is_floating: bool = false
@export var aggro_x_range: float = 100.0
@export var aggro_y_tolerance: float = 24.0
@export var aggro_duration: float = 30.0
@export var wander_radius: float = 48.0

const HURT_COOLDOWN := 0.6
const WANDER_SPEED := 24.0
const CHASE_SPEED := 56.0
const JUMP_ATTACK_DISTANCE := 56.0
const JUMP_VELOCITY_X := 110.0
const JUMP_VELOCITY_Y := -180.0
const GRAVITY := 600.0
const GROUND_OFFSET := 12.0  # slime center y + this = floor surface y
const WIND_UP_DURATION := 0.35
const LAND_RECOVER_DURATION := 0.25
const WORLD_MIN_X := 16.0
const WORLD_MAX_X := 2864.0

const NORMAL_SCALE := Vector2(1.0, 1.0)
const WIND_UP_SCALE := Vector2(1.3, 0.7)
const JUMP_SCALE := Vector2(0.75, 1.3)
const LAND_SCALE := Vector2(1.35, 0.65)

enum State { WANDER, CHASE, WIND_UP, JUMP, LAND }

@onready var sprite: Sprite2D = $Sprite2D

var _state: State = State.WANDER
var _state_timer := 0.0
var _hurt_cooldown_left := 0.0
var _wander_direction := 0
var _wander_change_left := 0.0
var _initial_x := 0.0
var _initial_y := 0.0
var _aggro_left := 0.0
var _velocity_y := 0.0
var _jump_dir := 0.0
var _player_rid: RID = RID()


func _ready() -> void:
	add_to_group("enemy")
	body_entered.connect(_on_body_entered)
	_initial_x = position.x
	_initial_y = position.y
	_pick_new_wander_direction()


func _process(delta: float) -> void:
	_hurt_cooldown_left = max(0.0, _hurt_cooldown_left - delta)
	_aggro_left = max(0.0, _aggro_left - delta)

	var player: Node2D = get_tree().get_first_node_in_group("player")
	var dx: float = 0.0
	var dy: float = 0.0
	if player != null:
		dx = player.global_position.x - global_position.x
		dy = player.global_position.y - global_position.y
		if absf(dx) <= aggro_x_range and absf(dy) <= aggro_y_tolerance:
			_aggro_left = aggro_duration
		if not _player_rid.is_valid() and player is CollisionObject2D:
			_player_rid = (player as CollisionObject2D).get_rid()

	var aggroed: bool = _aggro_left > 0.0

	if not is_floating and (_state == State.WANDER or _state == State.CHASE):
		var ground_below: float = _ground_y_below(position.x, position.y - 8.0)
		if ground_below == INF or position.y + GROUND_OFFSET < ground_below - 2.0:
			_state = State.JUMP
			_velocity_y = 0.0
			_jump_dir = 0.0

	match _state:
		State.WANDER:
			_do_wander(delta)
			if aggroed:
				_state = State.CHASE
		State.CHASE:
			if not aggroed:
				_state = State.WANDER
				_pick_new_wander_direction()
			elif absf(dx) < JUMP_ATTACK_DISTANCE:
				_state = State.WIND_UP
				_state_timer = WIND_UP_DURATION
				_jump_dir = signf(dx) if dx != 0.0 else _facing_sign()
				if _jump_dir != 0.0:
					sprite.flip_h = _jump_dir < 0.0
			else:
				_do_chase(delta, dx)
		State.WIND_UP:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.JUMP
				_velocity_y = JUMP_VELOCITY_Y
		State.JUMP:
			if _jump_dir != 0.0:
				var next_x: float = position.x + _jump_dir * JUMP_VELOCITY_X * delta
				if _is_blocked_at(next_x + _jump_dir * 4.0, position.y):
					_jump_dir = 0.0
				else:
					position.x = next_x
			_velocity_y += GRAVITY * delta
			position.y += _velocity_y * delta
			if _velocity_y > 0.0:
				var ground_y: float = _ground_y_below(position.x, position.y - 8.0)
				if ground_y != INF and position.y + GROUND_OFFSET >= ground_y:
					position.y = ground_y - GROUND_OFFSET
					_velocity_y = 0.0
					_initial_x = position.x
					_initial_y = position.y
					_state = State.LAND
					_state_timer = LAND_RECOVER_DURATION
		State.LAND:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.CHASE if aggroed else State.WANDER
				if not aggroed:
					_pick_new_wander_direction()

	position.x = clamp(position.x, WORLD_MIN_X, WORLD_MAX_X)
	_update_sprite_scale()


func _do_wander(delta: float) -> void:
	_wander_change_left -= delta
	if _wander_change_left <= 0.0:
		_pick_new_wander_direction()

	var bound_min: float = _initial_x - wander_radius
	var bound_max: float = _initial_x + wander_radius
	if position.x <= bound_min:
		_wander_direction = 1
	elif position.x >= bound_max:
		_wander_direction = -1

	if _wander_direction == 0:
		return

	var move_dir: float = float(_wander_direction)
	var next_x: float = position.x + move_dir * WANDER_SPEED * delta

	if not is_floating and not _has_ground_at(next_x):
		_wander_direction = -_wander_direction
		return

	if _is_blocked_at(next_x + move_dir * 8.0, position.y):
		_wander_direction = -_wander_direction
		return

	position.x = next_x
	sprite.flip_h = move_dir < 0.0


func _do_chase(delta: float, dx: float) -> void:
	var move_dir: float = signf(dx)
	if move_dir == 0.0:
		return
	var next_x: float = position.x + move_dir * CHASE_SPEED * delta

	if not is_floating and not _has_ground_at(next_x):
		return

	if _is_blocked_at(next_x + move_dir * 8.0, position.y):
		return

	position.x = next_x
	sprite.flip_h = move_dir < 0.0


func _has_ground_at(x: float) -> bool:
	var space := get_world_2d().direct_space_state
	var origin: Vector2 = Vector2(x, _initial_y - 4.0)
	var target: Vector2 = origin + Vector2(0.0, 32.0)
	var query := PhysicsRayQueryParameters2D.create(origin, target)
	query.collide_with_areas = false
	if _player_rid.is_valid():
		query.exclude = [_player_rid]
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty()


func _is_blocked_at(x: float, y: float) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = Vector2(x, y)
	query.collide_with_areas = false
	if _player_rid.is_valid():
		query.exclude = [_player_rid]
	var results: Array = space.intersect_point(query)
	return results.size() > 0


func _ground_y_below(x: float, from_y: float) -> float:
	var space := get_world_2d().direct_space_state
	var origin: Vector2 = Vector2(x, from_y)
	var target: Vector2 = origin + Vector2(0.0, 800.0)
	var query := PhysicsRayQueryParameters2D.create(origin, target)
	query.collide_with_areas = false
	if _player_rid.is_valid():
		query.exclude = [_player_rid]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return INF
	var hit_pos: Vector2 = hit.position
	return hit_pos.y


func _pick_new_wander_direction() -> void:
	_wander_change_left = randf_range(1.0, 3.0)
	var choices: Array[int] = [-1, 0, 1]
	_wander_direction = choices.pick_random()


func _facing_sign() -> float:
	return -1.0 if sprite.flip_h else 1.0


func _update_sprite_scale() -> void:
	match _state:
		State.WIND_UP:
			sprite.scale = WIND_UP_SCALE
		State.JUMP:
			sprite.scale = JUMP_SCALE
		State.LAND:
			sprite.scale = LAND_SCALE
		_:
			sprite.scale = NORMAL_SCALE


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and _hurt_cooldown_left <= 0.0:
		_hurt_cooldown_left = HURT_COOLDOWN
		Audio.play_sfx("hurt")
