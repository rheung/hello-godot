extends Area2D

signal hit_ufo(ufo: Area2D)

@export var speed := 880.0


func _ready() -> void:
	add_to_group("player_bullet")
	collision_layer = 4
	collision_mask = 2
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	global_position += Vector2(0.0, -speed * delta)
	if global_position.y < -40.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-3.0, -24.0, 6.0, 48.0), Color("ff5f8f"), true)
	draw_rect(Rect2(-6.0, -20.0, 12.0, 40.0), Color(1.0, 0.35, 0.6, 0.3), true)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("ufo"):
		emit_signal("hit_ufo", area)
		queue_free()
