extends Area2D

@export var is_floating: bool = false
@export var aggro_x_range: float = 100.0
@export var aggro_y_tolerance: float = 24.0
@export var aggro_duration: float = 30.0
@export var wander_radius: float = 48.0
@export var max_health: int = 3

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

const HP_BAR_WIDTH := 16.0
const HP_BAR_HEIGHT := 2.0
const HP_BAR_TOP_Y := -14.0
const HP_BAR_SHOW_TIME := 2.0
const HP_BAR_FADE_TIME := 0.4

const KNOCKBACK_DECAY := 600.0

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
var _health: int = 1
var _hp_bar_bg: ColorRect
var _hp_bar_fg: ColorRect
var _hp_bar_visible_left := 0.0
var _knockback_vx := 0.0


func _ready() -> void:
	add_to_group("enemy")
	body_entered.connect(_on_body_entered)
	_initial_x = position.x
	_initial_y = position.y
	_health = max_health
	_setup_hp_bar()
	_pick_new_wander_direction()


func _setup_hp_bar() -> void:
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.1, 0.0, 0.0, 0.85)
	_hp_bar_bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_bg.position = Vector2(-HP_BAR_WIDTH / 2.0, HP_BAR_TOP_Y)
	_hp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar_bg.visible = false
	add_child(_hp_bar_bg)
	_hp_bar_fg = ColorRect.new()
	_hp_bar_fg.color = Color(0.3, 0.9, 0.3, 1.0)
	_hp_bar_fg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_fg.position = Vector2(-HP_BAR_WIDTH / 2.0, HP_BAR_TOP_Y)
	_hp_bar_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar_fg.visible = false
	add_child(_hp_bar_fg)


func _refresh_hp_bar_size() -> void:
	if _hp_bar_fg == null or max_health <= 0:
		return
	var t: float = clampf(float(_health) / float(max_health), 0.0, 1.0)
	_hp_bar_fg.size.x = HP_BAR_WIDTH * t
	if t > 0.5:
		_hp_bar_fg.color = Color(0.3, 0.9, 0.3, 1.0)
	elif t > 0.25:
		_hp_bar_fg.color = Color(0.95, 0.8, 0.2, 1.0)
	else:
		_hp_bar_fg.color = Color(0.9, 0.25, 0.25, 1.0)


func _show_hp_bar() -> void:
	if _hp_bar_bg == null or _hp_bar_fg == null:
		return
	_hp_bar_visible_left = HP_BAR_SHOW_TIME
	_hp_bar_bg.visible = true
	_hp_bar_fg.visible = true
	_hp_bar_bg.modulate.a = 1.0
	_hp_bar_fg.modulate.a = 1.0


func _tick_hp_bar(delta: float) -> void:
	if _hp_bar_visible_left <= 0.0:
		return
	_hp_bar_visible_left -= delta
	if _hp_bar_visible_left <= 0.0:
		if _hp_bar_bg != null:
			_hp_bar_bg.visible = false
		if _hp_bar_fg != null:
			_hp_bar_fg.visible = false
	elif _hp_bar_visible_left < HP_BAR_FADE_TIME:
		var a: float = _hp_bar_visible_left / HP_BAR_FADE_TIME
		if _hp_bar_bg != null:
			_hp_bar_bg.modulate.a = a
		if _hp_bar_fg != null:
			_hp_bar_fg.modulate.a = a


func take_damage(amount: int = 1) -> void:
	_health -= amount
	_refresh_hp_bar_size()
	_show_hp_bar()
	if _health <= 0:
		queue_free()


func apply_knockback(vx: float) -> void:
	_knockback_vx = vx
	_state = State.WANDER
	_velocity_y = 0.0
	_jump_dir = 0.0


func _process(delta: float) -> void:
	_hurt_cooldown_left = max(0.0, _hurt_cooldown_left - delta)
	_aggro_left = max(0.0, _aggro_left - delta)
	_tick_hp_bar(delta)

	if _tick_knockback(delta):
		position.x = clamp(position.x, WORLD_MIN_X, WORLD_MAX_X)
		sprite.scale = NORMAL_SCALE
		return

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


func _tick_knockback(delta: float) -> bool:
	if absf(_knockback_vx) < 1.0:
		_knockback_vx = 0.0
		return false
	position.x += _knockback_vx * delta
	var decay: float = signf(_knockback_vx) * KNOCKBACK_DECAY * delta
	if absf(_knockback_vx) <= absf(decay):
		_knockback_vx = 0.0
	else:
		_knockback_vx -= decay
	return true


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
	if not body.is_in_group("player") or _hurt_cooldown_left > 0.0:
		return
	if body.is_in_group("dashing"):
		return
	_hurt_cooldown_left = HURT_COOLDOWN
	if body.has_method("take_damage"):
		body.take_damage(1)
