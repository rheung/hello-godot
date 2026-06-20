extends Node2D

@export var lifetime := 0.45

var _age := 0.0
var _scale_factor := 1.0
var _spark_dirs := PackedVector2Array()


func _ready() -> void:
	_randomize_sparks(14)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func set_size_scale(scale_factor: float) -> void:
	_scale_factor = maxf(0.2, scale_factor)
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / lifetime, 0.0, 1.0)
	var alpha := 1.0 - t
	var outer_radius := lerpf(6.0, 56.0 * _scale_factor, t)
	var inner_radius := lerpf(18.0, 5.0, t) * _scale_factor

	draw_circle(Vector2.ZERO, inner_radius, Color(1.0, 0.94, 0.55, 0.65 * alpha))
	draw_circle(Vector2.ZERO, inner_radius * 0.58, Color(1.0, 0.45, 0.12, 0.75 * alpha))
	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 40, Color(1.0, 0.52, 0.18, 0.95 * alpha), 4.0)
	draw_arc(Vector2.ZERO, outer_radius * 0.78, 0.0, TAU, 40, Color(1.0, 0.86, 0.2, 0.85 * alpha), 2.0)

	for spark_dir in _spark_dirs:
		var start := spark_dir * (outer_radius * 0.26)
		var end := spark_dir * (outer_radius + (24.0 * t * _scale_factor))
		draw_line(start, end, Color(1.0, 0.8, 0.2, 0.95 * alpha), 2.0)


func _randomize_sparks(spark_count: int) -> void:
	_spark_dirs.clear()
	for i in spark_count:
		var angle := TAU * (float(i) / float(spark_count))
		angle += randf_range(-0.16, 0.16)
		_spark_dirs.append(Vector2(cos(angle), sin(angle)).normalized())
