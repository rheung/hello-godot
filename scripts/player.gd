extends Area2D

signal shoot_requested(spawn_position: Vector2)
signal hit

@export var controller_move_speed := 520.0
@export_range(0.0, 1.0, 0.01) var controller_deadzone := 0.2
@export var shoot_cooldown := 0.18
@export var bottom_margin := 48.0
@export_range(0.0, 1.0, 0.01) var fire_rumble_weak := 0.2
@export_range(0.0, 1.0, 0.01) var fire_rumble_strong := 0.05
@export var fire_rumble_duration := 0.08
@export_range(0.0, 1.0, 0.01) var hit_rumble_weak := 0.75
@export_range(0.0, 1.0, 0.01) var hit_rumble_strong := 0.95
@export var hit_rumble_duration := 0.3

var _shoot_cooldown_left := 0.0
var _active := true
var _split_active := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 8 | 16
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if not _active:
		return
	var view_size := get_viewport_rect().size
	global_position.y = view_size.y - bottom_margin

	var stick_axis := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if absf(stick_axis) > controller_deadzone:
		global_position.x += stick_axis * controller_move_speed * delta
	global_position.x = clampf(global_position.x, 28.0, view_size.x - 28.0)

	_shoot_cooldown_left = maxf(0.0, _shoot_cooldown_left - delta)
	if Input.is_action_pressed("player_fire") and _shoot_cooldown_left <= 0.0:
		_shoot_cooldown_left = shoot_cooldown
		_rumble_connected_gamepads(fire_rumble_weak, fire_rumble_strong, fire_rumble_duration)
		emit_signal("shoot_requested", global_position + Vector2(0.0, -20.0))

	queue_redraw()


func _draw() -> void:
	if _split_active:
		_draw_ship(Vector2(-14.0, 0.0), 0.85)
		_draw_ship(Vector2(14.0, 0.0), 0.85)
	else:
		_draw_ship(Vector2.ZERO, 1.0)


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if area.is_in_group("enemy_beam") or area.is_in_group("enemy_bomb"):
		_rumble_connected_gamepads(hit_rumble_weak, hit_rumble_strong, hit_rumble_duration)
		emit_signal("hit")


func _rumble_connected_gamepads(weak_magnitude: float, strong_magnitude: float, duration: float) -> void:
	for device_id in Input.get_connected_joypads():
		Input.start_joy_vibration(device_id, weak_magnitude, strong_magnitude, duration)


func set_split_active(is_active: bool) -> void:
	_split_active = is_active
	queue_redraw()


func set_active(is_active: bool) -> void:
	_active = is_active


func _draw_ship(offset: Vector2, scale_factor: float) -> void:
	var points := PackedVector2Array([
		Vector2(0.0, -24.0),
		Vector2(20.0, 18.0),
		Vector2(8.0, 10.0),
		Vector2(-8.0, 10.0),
		Vector2(-20.0, 18.0)
	])
	for i in points.size():
		points[i] = points[i] * scale_factor + offset

	draw_polygon(
		points,
		PackedColorArray([
			Color("6ec9ff"),
			Color("2e93d5"),
			Color("2e93d5"),
			Color("2e93d5"),
			Color("2e93d5")
		])
	)
	draw_line(offset + Vector2(0.0, -10.0) * scale_factor, offset + Vector2(0.0, 14.0) * scale_factor, Color("e9f8ff"), 2.0)
