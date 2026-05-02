extends CharacterBody2D

const SPEED := 140.0
const JUMP_VELOCITY := -350.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.10

const DASH_SPEED := 320.0
const DASH_DURATION := 0.15
const DASH_COOLDOWN := 0.5

const FRUIT_SCENE := preload("res://scenes/fruit.tscn")
const SHOOT_OFFSET := Vector2(12.0, -4.0)

@onready var sprite: Sprite2D = $Sprite2D

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _facing := 1.0
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0


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

	if not is_on_floor():
		velocity += get_gravity() * delta
		_coyote_timer -= delta
	else:
		_coyote_timer = COYOTE_TIME

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER
	else:
		_jump_buffer_timer -= delta

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		Audio.play_sfx("jump")

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0.0
		_facing = direction
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()


func _shoot() -> void:
	var fruit := FRUIT_SCENE.instantiate()
	fruit.position = global_position + Vector2(_facing * SHOOT_OFFSET.x, SHOOT_OFFSET.y)
	fruit.direction = _facing
	get_parent().add_child(fruit)
	Audio.play_sfx("tap")
