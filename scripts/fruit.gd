extends Area2D

const SPEED := 250.0
const LIFETIME := 1.5

var direction: float = 1.0
var _life_left := LIFETIME


func _ready() -> void:
	add_to_group("fruit")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		Audio.play_sfx("explosion")
		area.queue_free()
		queue_free()
