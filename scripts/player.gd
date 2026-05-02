extends CharacterBody2D

const SPEED := 140.0
const JUMP_VELOCITY := -350.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.10

const DASH_SPEED := 320.0
const DASH_DURATION := 0.15
const DASH_COOLDOWN := 0.5

const WALL_STICK_TIME := 0.20
const WALL_SLIDE_MAX_FALL := 80.0
const WALL_JUMP_PUSH_X := 220.0
const WALL_JUMP_VELOCITY := -300.0
const WALL_JUMP_INPUT_LOCK := 0.15

const FRUIT_SCENE := preload("res://scenes/fruit.tscn")
const SHOOT_OFFSET := Vector2(12.0, 2.0)

@onready var sprite: Sprite2D = $Sprite2D

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _facing := 1.0
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _wall_stick_left := WALL_STICK_TIME
var _wall_jump_lock_left := 0.0


func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot"):
		_shoot()

	_dash_cooldown_left = max(0.0, _dash_cooldown_left - delta)

	if Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0 and _dash_time_left <= 0.0:
		_dash_time_left = DASH_DURATION
		_dash_cooldown_left = DASH_COOLDOWN
		Audio.play_sfx("power_up")

	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity.x = _facing * DASH_SPEED
		velocity.y = 0.0
		move_and_slide()
		return

	_wall_jump_lock_left = max(0.0, _wall_jump_lock_left - delta)

	var input_dir := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()
	var on_wall := is_on_wall_only()
	var wall_normal := get_wall_normal()
	var pressing_into_wall := on_wall and input_dir != 0.0 and signf(input_dir) != signf(wall_normal.x)
	var wall_clinging := pressing_into_wall and velocity.y >= 0.0

	if on_floor:
		_coyote_timer = COYOTE_TIME
		_wall_stick_left = WALL_STICK_TIME
	elif wall_clinging and _wall_stick_left > 0.0:
		velocity.y = 0.0
		_wall_stick_left -= delta
		_coyote_timer = 0.0
	elif wall_clinging:
		velocity += get_gravity() * delta
		velocity.y = min(velocity.y, WALL_SLIDE_MAX_FALL)
		_coyote_timer = 0.0
	else:
		velocity += get_gravity() * delta
		_coyote_timer -= delta
		if not on_wall:
			_wall_stick_left = WALL_STICK_TIME

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER
	else:
		_jump_buffer_timer -= delta

	if _jump_buffer_timer > 0.0 and not on_floor and on_wall:
		velocity.x = wall_normal.x * WALL_JUMP_PUSH_X
		velocity.y = WALL_JUMP_VELOCITY
		_wall_jump_lock_left = WALL_JUMP_INPUT_LOCK
		_facing = wall_normal.x
		sprite.flip_h = wall_normal.x < 0.0
		_jump_buffer_timer = 0.0
		_wall_stick_left = WALL_STICK_TIME
		Audio.play_sfx("jump")
	elif _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		Audio.play_sfx("jump")

	if _wall_jump_lock_left <= 0.0:
		if input_dir != 0.0:
			velocity.x = input_dir * SPEED
			sprite.flip_h = input_dir < 0.0
			_facing = input_dir
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()


func _shoot() -> void:
	var fruit := FRUIT_SCENE.instantiate()
	fruit.position = global_position + Vector2(_facing * SHOOT_OFFSET.x, SHOOT_OFFSET.y)
	fruit.direction = _facing
	get_parent().add_child(fruit)
	Audio.play_sfx("tap")
