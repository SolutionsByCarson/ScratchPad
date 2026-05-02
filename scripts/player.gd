extends CharacterBody2D

const SPEED := 140.0
const JUMP_VELOCITY := -350.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.10

@onready var sprite: Sprite2D = $Sprite2D

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0


func _physics_process(delta: float) -> void:
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
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()
