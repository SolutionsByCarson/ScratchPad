@tool
extends StaticBody2D


func _ready() -> void:
	_sync_visual()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_visual()


func _sync_visual() -> void:
	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
	var visual: ColorRect = get_node_or_null("ColorRect")
	if cs == null or visual == null:
		return
	if not (cs.shape is RectangleShape2D):
		return
	var rect: RectangleShape2D = cs.shape
	var size: Vector2 = rect.size
	visual.size = size
	visual.position = cs.position - size / 2.0
