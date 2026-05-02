extends Area2D

const HURT_COOLDOWN := 0.6

var _hurt_cooldown_left := 0.0


func _ready() -> void:
	add_to_group("enemy")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_hurt_cooldown_left = max(0.0, _hurt_cooldown_left - delta)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and _hurt_cooldown_left <= 0.0:
		_hurt_cooldown_left = HURT_COOLDOWN
		Audio.play_sfx("hurt")
