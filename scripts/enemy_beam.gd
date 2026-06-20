extends Area2D

signal hit_player

@export var speed := 340.0


func _ready() -> void:
	add_to_group("enemy_beam")
	collision_layer = 8
	collision_mask = 1
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	global_position += Vector2(0.0, speed * delta)
	if global_position.y > get_viewport_rect().size.y + 30.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-2.0, -8.0, 4.0, 20.0), Color("ff507d"))
	draw_rect(Rect2(-5.0, -6.0, 10.0, 16.0), Color(1.0, 0.35, 0.55, 0.25))


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		emit_signal("hit_player")
		queue_free()
