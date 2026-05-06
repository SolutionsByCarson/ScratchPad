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
const WALL_JUMP_INPUT_LOCK := 0.22
const WALL_GRACE_TIME := 0.06

const LEDGE_GRAB_TOLERANCE := 10.0
const MANTLE_NUDGE_X := 12.0
const AUTO_HANG_MAX_SPEED := 80.0

const SLAM_SPEED := 500.0
const SLAM_RADIUS := 36.0
const SLAM_LAND_DURATION := 0.18

const DASH_SCALE := Vector2(1.45, 0.7)
const SLAM_DESCENT_SCALE := Vector2(0.65, 1.45)
const SLAM_LAND_SCALE := Vector2(1.55, 0.55)

const FRUIT_SCENE := preload("res://scenes/fruit.tscn")
const SHOOT_OFFSET := Vector2(12.0, 2.0)

const COLLISION_HALF_HEIGHT := 9.0
const COLLISION_OFFSET_Y := 2.0
const COLLISION_TOP_FROM_CENTER := COLLISION_HALF_HEIGHT - COLLISION_OFFSET_Y  # 7.0
const COLLISION_BOTTOM_FROM_CENTER := COLLISION_HALF_HEIGHT + COLLISION_OFFSET_Y  # 11.0

@onready var sprite: Sprite2D = $Sprite2D

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _facing := 1.0
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _wall_stick_left := WALL_STICK_TIME
var _wall_jump_lock_left := 0.0
var _slamming := false
var _slam_land_timer := 0.0
var _hanging := false
var _hang_top_y := 0.0
var _hang_normal_x := 0.0
var _was_on_floor := false
var _last_floor_top_y := 0.0
var _ignore_wall_normal_x := 0.0
var _wall_grace_left := 0.0
var _last_wall_normal_x := 0.0


func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	_update_visual_scale(delta)

	if _hanging:
		velocity = Vector2.ZERO
		var input_dir_hang := Input.get_axis("move_left", "move_right")
		var pressing_into_ledge := input_dir_hang != 0.0 and signf(input_dir_hang) != signf(_hang_normal_x)
		if Input.is_action_just_pressed("jump") or pressing_into_ledge:
			global_position.y = _hang_top_y - COLLISION_BOTTOM_FROM_CENTER
			global_position.x += -_hang_normal_x * MANTLE_NUDGE_X
			_hanging = false
			Audio.play_sfx("jump")
		elif Input.is_action_just_pressed("slam"):
			_hanging = false
		move_and_slide()
		_update_floor_tracking()
		return

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
		_update_floor_tracking()
		return

	if is_on_floor() and Input.is_action_just_pressed("slam") and _is_on_one_way_platform():
		global_position.y += 2.0

	if not is_on_floor() and not _slamming and Input.is_action_just_pressed("slam"):
		_slamming = true
		_hanging = false
		velocity.x = 0.0
		velocity.y = SLAM_SPEED

	if _slamming:
		if is_on_floor():
			_slamming = false
			_slam_land_timer = SLAM_LAND_DURATION
			Audio.play_sfx("explosion")
			_do_slam_damage()
		else:
			velocity += get_gravity() * delta
			velocity.x = 0.0
			move_and_slide()
			_update_floor_tracking()
			return


	if _was_on_floor and not is_on_floor() and velocity.y >= -10.0:
		var hspeed: float = absf(velocity.x)
		if hspeed > 0.0 and hspeed < AUTO_HANG_MAX_SPEED:
			_hanging = true
			_hang_top_y = _last_floor_top_y
			_hang_normal_x = signf(velocity.x)
			global_position.y = _last_floor_top_y + COLLISION_TOP_FROM_CENTER
			velocity = Vector2.ZERO
			move_and_slide()
			_update_floor_tracking()
			return

	_wall_jump_lock_left = max(0.0, _wall_jump_lock_left - delta)
	if _wall_jump_lock_left <= 0.0:
		_ignore_wall_normal_x = 0.0

	var input_dir := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()
	var contact: Dictionary = _classify_wall_contact()
	var contact_type: String = contact.type
	var on_vertical_wall: bool = contact_type == "wall"
	var on_ledge: bool = contact_type == "ledge"
	var contact_normal_x: float = contact.normal_x
	if on_vertical_wall and _ignore_wall_normal_x != 0.0 and signf(contact_normal_x) != signf(_ignore_wall_normal_x):
		_ignore_wall_normal_x = 0.0
	if on_vertical_wall:
		_wall_grace_left = WALL_GRACE_TIME
		_last_wall_normal_x = contact_normal_x
	else:
		_wall_grace_left = max(0.0, _wall_grace_left - delta)
	var pressing_into_contact: bool = contact_normal_x != 0.0 and input_dir != 0.0 and signf(input_dir) != signf(contact_normal_x)
	var wall_clinging: bool = on_vertical_wall and pressing_into_contact and velocity.y >= 0.0

	if on_ledge and pressing_into_contact and not on_floor:
		_hanging = true
		var ledge_top: float = contact.top_y
		_hang_top_y = ledge_top
		_hang_normal_x = contact_normal_x
		global_position.y = ledge_top + COLLISION_TOP_FROM_CENTER
		velocity = Vector2.ZERO
		move_and_slide()
		_update_floor_tracking()
		return

	if not on_floor and not _hanging and input_dir != 0.0:
		var ray_ledge: Dictionary = _try_raycast_ledge(input_dir)
		if ray_ledge.hit:
			_hanging = true
			var rt: float = ray_ledge.top_y
			var rn: float = ray_ledge.normal_x
			_hang_top_y = rt
			_hang_normal_x = rn
			global_position.y = rt + COLLISION_TOP_FROM_CENTER
			velocity = Vector2.ZERO
			move_and_slide()
			_update_floor_tracking()
			return

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
		if not on_vertical_wall:
			_wall_stick_left = WALL_STICK_TIME

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER
	else:
		_jump_buffer_timer -= delta

	var can_wall_jump: bool = not on_floor and (on_vertical_wall or _wall_grace_left > 0.0)
	var jump_normal_x: float = contact_normal_x if on_vertical_wall else _last_wall_normal_x
	if _jump_buffer_timer > 0.0 and can_wall_jump and jump_normal_x != 0.0:
		velocity.x = jump_normal_x * WALL_JUMP_PUSH_X
		velocity.y = WALL_JUMP_VELOCITY
		_wall_jump_lock_left = WALL_JUMP_INPUT_LOCK
		_ignore_wall_normal_x = jump_normal_x
		_wall_grace_left = 0.0
		_facing = jump_normal_x
		sprite.flip_h = jump_normal_x < 0.0
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
	_update_floor_tracking()


func _update_visual_scale(delta: float) -> void:
	_slam_land_timer = max(0.0, _slam_land_timer - delta)
	if _slam_land_timer > 0.0:
		sprite.scale = SLAM_LAND_SCALE
	elif _slamming:
		sprite.scale = SLAM_DESCENT_SCALE
	elif _dash_time_left > 0.0:
		sprite.scale = DASH_SCALE
	else:
		sprite.scale = Vector2.ONE


func _update_floor_tracking() -> void:
	_was_on_floor = is_on_floor()
	if _was_on_floor:
		_last_floor_top_y = global_position.y + COLLISION_BOTTOM_FROM_CENTER


func _classify_wall_contact() -> Dictionary:
	var result := {"type": "none", "normal_x": 0.0, "top_y": 0.0}
	if not is_on_wall_only():
		return result
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var n: Vector2 = collision.get_normal()
		if absf(n.x) <= 0.7:
			continue
		var collider: Object = collision.get_collider()
		if collider == null:
			continue
		var collider_node: Node = collider as Node
		if collider_node == null:
			continue
		var info: Dictionary = _shape_info(collider_node)
		var size_x: float = info.size_x
		var size_y: float = info.size_y
		var top_y: float = info.top_y
		if size_y > size_x:
			if _ignore_wall_normal_x != 0.0 and signf(n.x) == signf(_ignore_wall_normal_x):
				continue
			result.normal_x = n.x
			result.type = "wall"
			return result
		result.normal_x = n.x
		var player_top: float = global_position.y - COLLISION_TOP_FROM_CENTER
		if absf(player_top - top_y) <= LEDGE_GRAB_TOLERANCE:
			result.type = "ledge"
			result.top_y = top_y
		else:
			result.type = "platform_side"
		return result
	return result


func _try_raycast_ledge(input_dir: float) -> Dictionary:
	var result := {"hit": false, "top_y": 0.0, "normal_x": 0.0}
	if input_dir == 0.0:
		return result
	var space := get_world_2d().direct_space_state
	var origin: Vector2 = global_position + Vector2(0.0, -COLLISION_TOP_FROM_CENTER + 4.0)
	var target: Vector2 = origin + Vector2(input_dir * 14.0, 0.0)
	var query := PhysicsRayQueryParameters2D.create(origin, target)
	query.exclude = [self]
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return result
	var collider: Object = hit.collider
	var collider_node: Node = collider as Node
	if collider_node == null:
		return result
	var info: Dictionary = _shape_info(collider_node)
	var size_x: float = info.size_x
	var size_y: float = info.size_y
	if size_y > size_x:
		return result
	var top_y: float = info.top_y
	var player_top: float = global_position.y - COLLISION_TOP_FROM_CENTER
	if absf(player_top - top_y) > LEDGE_GRAB_TOLERANCE:
		return result
	var hit_normal: Vector2 = hit.normal
	result.hit = true
	result.top_y = top_y
	result.normal_x = hit_normal.x
	return result


func _is_on_one_way_platform() -> bool:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var n: Vector2 = collision.get_normal()
		if n.y > -0.7:
			continue
		var collider: Object = collision.get_collider()
		if collider == null:
			continue
		var collider_node: Node = collider as Node
		if collider_node == null:
			continue
		for child in collider_node.get_children():
			if child is CollisionShape2D:
				var cs: CollisionShape2D = child
				if cs.one_way_collision:
					return true
	return false


func _shape_info(node: Node) -> Dictionary:
	var info := {"size_x": 0.0, "size_y": 0.0, "top_y": INF}
	for child in node.get_children():
		if child is CollisionShape2D:
			var cs: CollisionShape2D = child
			if cs.shape is RectangleShape2D:
				var rect: RectangleShape2D = cs.shape
				info.size_x = rect.size.x
				info.size_y = rect.size.y
				if node is Node2D:
					var n2d: Node2D = node
					info.top_y = n2d.global_position.y + cs.position.y - rect.size.y / 2.0
			break
	return info


func _shoot() -> void:
	var fruit := FRUIT_SCENE.instantiate()
	fruit.position = global_position + Vector2(_facing * SHOOT_OFFSET.x, SHOOT_OFFSET.y)
	fruit.direction = _facing
	get_parent().add_child(fruit)
	Audio.play_sfx("tap")


func _do_slam_damage() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D:
			var e: Node2D = enemy
			if global_position.distance_to(e.global_position) <= SLAM_RADIUS:
				e.queue_free()
