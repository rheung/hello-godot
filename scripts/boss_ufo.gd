extends Area2D

signal bullet_requested(spawn_position: Vector2)
signal bomb_requested(spawn_position: Vector2, drift_x: float)
signal noise_requested
signal destroyed(world_position: Vector2)

@export var min_speed := 55.0
@export var max_speed := 95.0
@export var top_band_height := 220.0
@export var screen_width := 1024.0
@export var scale_factor := 5.0
@export var max_health := 30
@export var bullet_delay_min := 0.24
@export var bullet_delay_max := 0.5
@export_range(0.0, 1.0, 0.01) var extra_bullet_chance := 0.48
@export var bomb_delay_min := 0.65
@export var bomb_delay_max := 1.2
@export var noise_delay_min := 0.85
@export var noise_delay_max := 1.8
@export_enum("dreadnought", "crystal", "serpent", "core") var shape_style := "dreadnought"
@export_enum("drift", "sweep", "pulse", "hunter") var movement_pattern := "drift"
@export var primary_color := Color(0.73, 0.1, 0.94, 1.0)
@export var secondary_color := Color(1.0, 0.16, 0.5, 0.95)
@export var core_color := Color(1.0, 0.86, 0.22, 0.95)

var _velocity := Vector2.ZERO
var _active := true
var _health := 30
var _rng := RandomNumberGenerator.new()
var _time := 0.0


func _ready() -> void:
	add_to_group("ufo")
	add_to_group("boss_ufo")
	collision_layer = 2
	collision_mask = 4
	_health = max_health
	_rng.randomize()
	_pick_new_velocity()
	_schedule_next_bullet_shot()
	_schedule_next_bomb_drop()
	_schedule_noise_ping()
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_apply_movement_pattern(delta)

	global_position += _velocity * delta

	var half_w := 24.0 * scale_factor
	var top_limit := 58.0
	var bottom_limit := top_band_height
	if global_position.x < half_w:
		global_position.x = half_w
		_velocity.x = absf(_velocity.x)
	elif global_position.x > screen_width - half_w:
		global_position.x = screen_width - half_w
		_velocity.x = - absf(_velocity.x)

	if global_position.y < top_limit:
		global_position.y = top_limit
		_velocity.y = absf(_velocity.y)
	elif global_position.y > bottom_limit:
		global_position.y = bottom_limit
		_velocity.y = - absf(_velocity.y)

	if _rng.randf() < 0.018:
		_velocity.y = lerpf(_velocity.y, _rng.randf_range(-28.0, 28.0), 0.38)

	queue_redraw()


func _draw() -> void:
	var pulse := 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.01)
	match shape_style:
		"crystal":
			draw_polygon(
				PackedVector2Array([
					Vector2(0.0, -22.0) * scale_factor,
					Vector2(22.0, -6.0) * scale_factor,
					Vector2(18.0, 12.0) * scale_factor,
					Vector2(0.0, 20.0) * scale_factor,
					Vector2(-18.0, 12.0) * scale_factor,
					Vector2(-22.0, -6.0) * scale_factor
				]),
				PackedColorArray([primary_color, secondary_color, primary_color, secondary_color, primary_color, secondary_color])
			)
			draw_arc(Vector2.ZERO, 19.0 * scale_factor, 0.0, TAU, 32, secondary_color, 3.0)
		"serpent":
			for i in 7:
				var t := float(i) / 6.0
				var x := lerpf(-24.0, 24.0, t) * scale_factor
				var y := sin(t * PI * 2.0 + _time * 3.0) * 4.0 * scale_factor
				draw_circle(Vector2(x, y), (8.0 - t * 3.0) * scale_factor * 0.5, Color(secondary_color, 0.9 - t * 0.08))
			draw_line(Vector2(-22.0, 0.0) * scale_factor, Vector2(22.0, 0.0) * scale_factor, primary_color, 4.0)
		"core":
			draw_circle(Vector2.ZERO, 20.0 * scale_factor, primary_color)
			draw_circle(Vector2.ZERO, 14.0 * scale_factor, secondary_color)
			draw_arc(Vector2.ZERO, 24.0 * scale_factor, _time * 1.6, _time * 1.6 + TAU * 0.72, 36, core_color, 4.0)
			draw_arc(Vector2.ZERO, 11.0 * scale_factor, -_time * 2.1, -_time * 2.1 + TAU * 0.6, 24, Color(1.0, 1.0, 1.0, 0.9), 2.0)
		_:
			# Angular hull to contrast heavily with regular smooth UFOs.
			draw_polygon(
				PackedVector2Array([
					Vector2(-28.0, 0.0) * scale_factor,
					Vector2(-16.0, -10.0) * scale_factor,
					Vector2(0.0, -15.0) * scale_factor,
					Vector2(16.0, -10.0) * scale_factor,
					Vector2(28.0, 0.0) * scale_factor,
					Vector2(16.0, 11.0) * scale_factor,
					Vector2(0.0, 15.0) * scale_factor,
					Vector2(-16.0, 11.0) * scale_factor
				]),
				PackedColorArray([
					primary_color,
					primary_color,
					secondary_color,
					primary_color,
					primary_color,
					primary_color,
					secondary_color,
					primary_color
				])
			)
			draw_arc(Vector2.ZERO, 22.0 * scale_factor, PI * 0.15, PI * 0.85, 24, Color(1.0, 0.45, 0.8, 0.85), 3.0)
			draw_arc(Vector2.ZERO, 22.0 * scale_factor, PI * 1.15, PI * 1.85, 24, Color(1.0, 0.45, 0.8, 0.85), 3.0)

	draw_circle(Vector2.ZERO, 7.0 * scale_factor * pulse, core_color)
	draw_circle(Vector2.ZERO, 3.8 * scale_factor * pulse, Color(1.0, 1.0, 1.0, 0.95))

	var bar_w := 180.0
	var ratio := clampf(float(_health) / float(max_health), 0.0, 1.0)
	draw_rect(Rect2(-bar_w * 0.5, -82.0, bar_w, 9.0), Color(0.12, 0.2, 0.26, 0.85), true)
	draw_rect(Rect2(-bar_w * 0.5 + 1.0, -81.0, (bar_w - 2.0) * ratio, 7.0), Color("ff5d6c"), true)


func take_hit() -> void:
	if not _active:
		return
	_health -= 1
	if _health <= 0:
		_active = false
		emit_signal("destroyed", global_position)
		queue_free()
		return
	queue_redraw()


func stop_actions() -> void:
	_active = false


func get_health() -> int:
	return _health


func get_max_health() -> int:
	return max_health


func _pick_new_velocity() -> void:
	var direction := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.25, 0.25))
	if direction.length_squared() < 0.0001:
		direction = Vector2(1.0, 0.0)
	direction = direction.normalized()
	_velocity = direction * _rng.randf_range(min_speed, max_speed)


func _schedule_next_bullet_shot() -> void:
	var delay := _rng.randf_range(bullet_delay_min, bullet_delay_max)
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		if not _active:
			return
		var x_offset := _rng.randf_range(-88.0, 88.0)
		emit_signal("bullet_requested", global_position + Vector2(x_offset, 34.0))
		if _rng.randf() < extra_bullet_chance:
			emit_signal("bullet_requested", global_position + Vector2(_rng.randf_range(-104.0, 104.0), 34.0))
		_schedule_next_bullet_shot()
	)


func _schedule_next_bomb_drop() -> void:
	var delay := _rng.randf_range(bomb_delay_min, bomb_delay_max)
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		if not _active:
			return
		var x_offset := _rng.randf_range(-92.0, 92.0)
		var drift_x := _rng.randf_range(-95.0, 95.0)
		emit_signal("bomb_requested", global_position + Vector2(x_offset, 28.0), drift_x)
		_schedule_next_bomb_drop()
	)


func _schedule_noise_ping() -> void:
	var delay := _rng.randf_range(noise_delay_min, noise_delay_max)
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		if not _active:
			return
		emit_signal("noise_requested")
		_schedule_noise_ping()
	)


func _apply_movement_pattern(delta: float) -> void:
	match movement_pattern:
		"sweep":
			_velocity.x = lerpf(_velocity.x, cos(_time * 1.45) * max_speed * 0.9, minf(1.0, 1.4 * delta))
			_velocity.y = lerpf(_velocity.y, sin(_time * 2.4) * max_speed * 0.22, minf(1.0, 1.2 * delta))
		"pulse":
			_velocity.x = lerpf(_velocity.x, sin(_time * 2.9) * max_speed * 1.05, minf(1.0, 2.6 * delta))
			_velocity.y = lerpf(_velocity.y, cos(_time * 3.3) * max_speed * 0.18, minf(1.0, 1.8 * delta))
		"hunter":
			_velocity.x = lerpf(_velocity.x, signf(sin(_time * 0.9)) * max_speed * 1.15, minf(1.0, 1.7 * delta))
			_velocity.y = lerpf(_velocity.y, sin(_time * 2.0) * max_speed * 0.27, minf(1.0, 1.4 * delta))
		_:
			pass
