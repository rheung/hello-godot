extends Area2D

signal shoot_requested(spawn_position: Vector2)
signal destroyed(world_position: Vector2)

@export var min_speed := 70.0
@export var max_speed := 140.0
@export var top_band_height := 240.0
@export var screen_width := 1024.0

var _velocity := Vector2.ZERO
var _active := true
var _rng := RandomNumberGenerator.new()


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

	global_position += _velocity * delta

	if global_position.x < 36.0:
		global_position.x = 36.0
		_velocity.x = absf(_velocity.x)
	elif global_position.x > screen_width - 36.0:
		global_position.x = screen_width - 36.0
		_velocity.x = -absf(_velocity.x)

	if global_position.y < 48.0:
		global_position.y = 48.0
		_velocity.y = absf(_velocity.y)
	elif global_position.y > top_band_height:
		global_position.y = top_band_height
		_velocity.y = -absf(_velocity.y)

	if _rng.randf() < 0.018:
		_velocity.y = lerpf(_velocity.y, _rng.randf_range(-45.0, 45.0), 0.45)


func _draw() -> void:
	draw_ellipse(Vector2.ZERO, 24.0, 10.0, Color("87ff9f"), true)
	draw_ellipse(Vector2(0.0, -8.0), 14.0, 8.0, Color("67d8ff"), true)
	draw_line(Vector2(-16.0, 7.0), Vector2(16.0, 7.0), Color("c7ffe4"), 2.0)


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
	var delay := _rng.randf_range(0.9, 2.3)
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
