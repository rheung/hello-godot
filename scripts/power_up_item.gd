extends Area2D

signal collected(kind: String)

@export var fall_speed := 145.0

var kind := "double_shot"


func _ready() -> void:
	add_to_group("power_up")
	collision_layer = 16
	collision_mask = 1
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _process(delta: float) -> void:
	global_position.y += fall_speed * delta
	if global_position.y > get_viewport_rect().size.y + 32.0:
		queue_free()
		return
	queue_redraw()


func set_kind(new_kind: String) -> void:
	kind = new_kind
	queue_redraw()


func _draw() -> void:
	var fill_color := _get_kind_color()
	draw_circle(Vector2.ZERO, 14.0, fill_color)
	draw_circle(Vector2.ZERO, 10.0, Color(1.0, 1.0, 1.0, 0.2))

	match kind:
		"double_shot":
			draw_rect(Rect2(-7.0, -6.0, 4.0, 12.0), Color("ffffff"), true)
			draw_rect(Rect2(3.0, -6.0, 4.0, 12.0), Color("ffffff"), true)
		"laser_beam":
			draw_rect(Rect2(-2.0, -9.0, 4.0, 18.0), Color("ffffff"), true)
			draw_rect(Rect2(-5.0, -7.0, 10.0, 14.0), Color(1.0, 1.0, 1.0, 0.35), true)
		"split_ship":
			draw_polygon(
				PackedVector2Array([
					Vector2(-8.0, 4.0),
					Vector2(-3.0, -7.0),
					Vector2(0.0, 4.0)
				]),
				PackedColorArray([Color("ffffff"), Color("ffffff"), Color("ffffff")])
			)
			draw_polygon(
				PackedVector2Array([
					Vector2(0.0, 4.0),
					Vector2(3.0, -7.0),
					Vector2(8.0, 4.0)
				]),
				PackedColorArray([Color("ffffff"), Color("ffffff"), Color("ffffff")])
			)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		emit_signal("collected", kind)
		queue_free()


func _get_kind_color() -> Color:
	match kind:
		"double_shot":
			return Color("4ac5ff")
		"laser_beam":
			return Color("ff4a7d")
		"split_ship":
			return Color("9bff69")
		_:
			return Color("ffffff")
