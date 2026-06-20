extends Area2D

signal hit_ufo(ufo: Area2D)

@export var speed := 560.0


func _ready() -> void:
	add_to_group("player_bullet")
	collision_layer = 4
	collision_mask = 2
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	global_position += Vector2(0.0, -speed * delta)
	if global_position.y < -20.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color("ffe066"))
	_draw_glow()


func _draw_glow() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.9, 0.3, 0.25))


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("ufo"):
		emit_signal("hit_ufo", area)
		queue_free()
