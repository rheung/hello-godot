extends Area2D

signal shoot_requested(spawn_position: Vector2)
signal hit

@export var speed_lerp := 18.0
@export var shoot_cooldown := 0.18
@export var bottom_margin := 48.0

var _shoot_cooldown_left := 0.0
var _alive := true


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 8
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if not _alive:
		return
	var view_size := get_viewport_rect().size
	global_position.y = view_size.y - bottom_margin
	var target_x := clampf(get_global_mouse_position().x, 28.0, view_size.x - 28.0)
	global_position.x = lerpf(global_position.x, target_x, minf(1.0, speed_lerp * delta))

	_shoot_cooldown_left = maxf(0.0, _shoot_cooldown_left - delta)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _shoot_cooldown_left <= 0.0:
		_shoot_cooldown_left = shoot_cooldown
		emit_signal("shoot_requested", global_position + Vector2(0.0, -20.0))

	queue_redraw()


func _draw() -> void:
	draw_polygon(
		PackedVector2Array([
			Vector2(0.0, -24.0),
			Vector2(20.0, 18.0),
			Vector2(8.0, 10.0),
			Vector2(-8.0, 10.0),
			Vector2(-20.0, 18.0)
		]),
		PackedColorArray([
			Color("6ec9ff"),
			Color("2e93d5"),
			Color("2e93d5"),
			Color("2e93d5"),
			Color("2e93d5")
		])
	)
	draw_line(Vector2(0.0, -10.0), Vector2(0.0, 14.0), Color("e9f8ff"), 2.0)


func _on_area_entered(area: Area2D) -> void:
	if not _alive:
		return
	if area.is_in_group("enemy_beam"):
		_alive = false
		emit_signal("hit")
