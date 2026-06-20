extends Area2D

signal hit_player

@export var speed := 245.0
@export var max_speed := 405.0
@export var acceleration := 145.0
@export var wobble_strength := 42.0
@export var wobble_frequency := 4.0

var _drift_x := 0.0
var _rotation_speed := 3.0
var _life_time := 0.0


func _ready() -> void:
	add_to_group("enemy_bomb")
	collision_layer = 8
	collision_mask = 1
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_life_time += delta
	speed = minf(max_speed, speed + acceleration * delta)
	rotation += _rotation_speed * delta
	var wobble_x := sin(_life_time * wobble_frequency) * wobble_strength
	global_position += Vector2(_drift_x + wobble_x, speed) * delta
	if global_position.y > get_viewport_rect().size.y + 36.0:
		queue_free()
		return
	queue_redraw()


func set_drift_x(value: float) -> void:
	_drift_x = value


func _draw() -> void:
	draw_circle(Vector2.ZERO, 11.0, Color("ff8b3d"))
	draw_circle(Vector2.ZERO, 7.0, Color("fff3b0"))
	draw_line(Vector2(-10.0, -6.0), Vector2(10.0, 6.0), Color(1.0, 0.35, 0.2, 0.35), 3.0)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		emit_signal("hit_player")
		queue_free()
