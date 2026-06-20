extends Area2D

signal shoot_requested(spawn_position: Vector2)
signal destroyed(world_position: Vector2)

@export var min_speed := 70.0
@export var max_speed := 140.0
@export var top_band_height := 240.0
@export var screen_width := 1024.0
@export var shot_delay_min := 0.9
@export var shot_delay_max := 2.3
@export_enum("classic", "diamond", "saucer", "spike") var shape_style := "classic"
@export_enum("wander", "zigzag", "wave", "dash") var movement_pattern := "wander"
@export var primary_color := Color("87ff9f")
@export var secondary_color := Color("67d8ff")
@export var detail_color := Color("c7ffe4")

var _velocity := Vector2.ZERO
var _active := true
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _dash_cooldown := 0.0


func _ready() -> void:
	add_to_group("ufo")
	collision_layer = 2
	collision_mask = 4
	_rng.randomize()
	_pick_new_velocity()
	_schedule_next_shot()
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_apply_movement_pattern(delta)

	global_position += _velocity * delta

	if global_position.x < 36.0:
		global_position.x = 36.0
		_velocity.x = absf(_velocity.x)
	elif global_position.x > screen_width - 36.0:
		global_position.x = screen_width - 36.0
		_velocity.x = - absf(_velocity.x)

	if global_position.y < 48.0:
		global_position.y = 48.0
		_velocity.y = absf(_velocity.y)
	elif global_position.y > top_band_height:
		global_position.y = top_band_height
		_velocity.y = - absf(_velocity.y)

	if _rng.randf() < 0.018:
		_velocity.y = lerpf(_velocity.y, _rng.randf_range(-45.0, 45.0), 0.45)

	queue_redraw()


func _draw() -> void:
	match shape_style:
		"diamond":
			draw_polygon(
				PackedVector2Array([
					Vector2(0.0, -18.0),
					Vector2(24.0, 0.0),
					Vector2(0.0, 14.0),
					Vector2(-24.0, 0.0)
				]),
				PackedColorArray([primary_color, secondary_color, primary_color, secondary_color])
			)
			draw_circle(Vector2.ZERO, 5.0, detail_color)
		"saucer":
			draw_ellipse(Vector2.ZERO, 26.0, 9.0, primary_color, true)
			draw_ellipse(Vector2(0.0, -6.0), 10.0, 6.0, secondary_color, true)
			draw_arc(Vector2.ZERO, 18.0, PI * 0.1, PI * 0.9, 18, detail_color, 2.0)
			_draw_lights(detail_color)
		"spike":
			draw_polygon(
				PackedVector2Array([
					Vector2(-22.0, 8.0),
					Vector2(-10.0, -8.0),
					Vector2(-2.0, 9.0),
					Vector2(6.0, -10.0),
					Vector2(14.0, 8.0),
					Vector2(22.0, -7.0),
					Vector2(20.0, 14.0),
					Vector2(-20.0, 14.0)
				]),
				PackedColorArray([
					primary_color,
					secondary_color,
					primary_color,
					secondary_color,
					primary_color,
					secondary_color,
					primary_color,
					primary_color
				])
			)
			draw_line(Vector2(-14.0, 6.0), Vector2(14.0, 6.0), detail_color, 2.0)
		_:
			draw_ellipse(Vector2.ZERO, 24.0, 10.0, primary_color, true)
			draw_ellipse(Vector2(0.0, -8.0), 14.0, 8.0, secondary_color, true)
			draw_line(Vector2(-16.0, 7.0), Vector2(16.0, 7.0), detail_color, 2.0)


func take_hit() -> void:
	if not _active:
		return
	_active = false
	emit_signal("destroyed", global_position)
	queue_free()


func stop_actions() -> void:
	_active = false


func _pick_new_velocity() -> void:
	var direction := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.35, 0.35))
	if direction.length_squared() < 0.0001:
		direction = Vector2(1.0, 0.0)
	direction = direction.normalized()
	_velocity = direction * _rng.randf_range(min_speed, max_speed)


func _schedule_next_shot() -> void:
	var delay := _rng.randf_range(shot_delay_min, shot_delay_max)
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		if _active:
			emit_signal("shoot_requested", global_position + Vector2(0.0, 16.0))
			_schedule_next_shot()
	)


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if area.is_in_group("player_bullet"):
		take_hit()


func _apply_movement_pattern(delta: float) -> void:
	match movement_pattern:
		"zigzag":
			_velocity.y = sin(_time * 3.5) * max_speed * 0.28
		"wave":
			_velocity.x = lerpf(_velocity.x, cos(_time * 2.1) * max_speed * 0.72, minf(1.0, 1.8 * delta))
			_velocity.y = sin(_time * 4.2) * max_speed * 0.18
		"dash":
			if _dash_cooldown <= 0.0:
				_dash_cooldown = _rng.randf_range(1.1, 2.1)
				var dash_dir := 1.0 if _rng.randf() > 0.5 else -1.0
				_velocity.x = dash_dir * _rng.randf_range(max_speed * 1.1, max_speed * 1.9)
			_velocity.y = lerpf(_velocity.y, sin(_time * 2.2) * max_speed * 0.16, minf(1.0, 2.4 * delta))
		_:
			pass


func _draw_lights(color: Color) -> void:
	for i in 6:
		var x := lerpf(-16.0, 16.0, float(i) / 5.0)
		draw_circle(Vector2(x, 4.0), 1.8, color)
