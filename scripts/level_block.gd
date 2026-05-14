@tool
extends StaticBody2D

@export var size: Vector2 = Vector2(64, 8):
	set(value):
		size = value
		_sync()


func _ready() -> void:
	_sync()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sync()


func _sync() -> void:
	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
	var visual: ColorRect = get_node_or_null("ColorRect")
	if cs != null and cs.shape is RectangleShape2D:
		var rect: RectangleShape2D = cs.shape
		rect.size = size
	if visual != null:
		visual.size = size
		var cs_pos: Vector2 = cs.position if cs != null else Vector2.ZERO
		visual.position = cs_pos - size / 2.0
