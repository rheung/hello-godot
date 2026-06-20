extends Node2D

const UFO_SCENE := preload("res://scenes/ufo.tscn")
const BOSS_UFO_SCENE := preload("res://scenes/boss_ufo.tscn")
const PLAYER_BULLET_SCENE := preload("res://scenes/player_bullet.tscn")
const PLAYER_LASER_SCENE := preload("res://scenes/player_laser.tscn")
const ENEMY_BEAM_SCENE := preload("res://scenes/enemy_beam.tscn")
const BOSS_BOMB_SCENE := preload("res://scenes/boss_bomb.tscn")
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const POWER_UP_SCENE := preload("res://scenes/power_up_item.tscn")
const SFX_SCENE := preload("res://scripts/sfx.gd")

const UFO_COUNT := 4
const REGULAR_UFO_KILLS_FOR_BOSS := 5
const BOSS_SCORE := 300
const LEVEL_UP_EVERY_KILLS := 8
const POWER_UP_DURATION := 15.0
const POWER_UP_TYPES := ["double_shot", "laser_beam", "split_ship"]
const UFO_SHAPES := ["classic", "diamond", "saucer", "spike"]
const UFO_PATTERNS := ["wander", "zigzag", "wave", "dash"]
const BOSS_SHAPES := ["dreadnought", "crystal", "serpent", "core"]
const BOSS_PATTERNS := ["drift", "sweep", "pulse", "hunter"]
const MAX_LIVES := 3
const HITS_PER_LIFE := 10
const PLAYER_HIT_COOLDOWN := 0.12

@onready var player: Area2D = $Player
@onready var background: ColorRect = $Background
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var enemy_projectiles: Node2D = $EnemyProjectiles
@onready var explosions: Node2D = $Explosions
@onready var power_ups: Node2D = $PowerUps
@onready var score_label: Label = $HUD/ScoreLabel
@onready var lives_label: Label = $HUD/LivesLabel
@onready var life_bar_1: ProgressBar = $HUD/LifeBar1
@onready var life_bar_2: ProgressBar = $HUD/LifeBar2
@onready var life_bar_3: ProgressBar = $HUD/LifeBar3
@onready var level_label: Label = $HUD/LevelLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var boss_warning_label: Label = $HUD/BossWarningLabel

var _rng := RandomNumberGenerator.new()
var _score := 0
var _game_over := false
var _sfx: Node
var _active_power_up := ""
var _active_power_up_expires_at := 0.0
var _power_up_seconds_left := -1
var _level := 1
var _biome_name := "Neon"
var _total_regular_ufo_destroyed := 0
var _bosses_defeated := 0
var _lives_left := MAX_LIVES
var _life_health := HITS_PER_LIFE
var _player_hit_cooldown_left := 0.0
var _regular_ufo_destroyed := 0
var _boss_active := false
var _boss_ufo: Area2D
var _boss_health_cache := -1
var _boss_warning_tween: Tween
var _life_bars: Array[ProgressBar]


func _ready() -> void:
	_ensure_input_actions()
	_sfx = SFX_SCENE.new()
	add_child(_sfx)
	_rng.randomize()
	player.shoot_requested.connect(_on_player_shoot_requested)
	player.hit.connect(_on_player_hit)
	_life_bars = [life_bar_1, life_bar_2, life_bar_3]
	for bar in _life_bars:
		bar.max_value = HITS_PER_LIFE
		bar.value = HITS_PER_LIFE
	for i in UFO_COUNT:
		_spawn_ufo()
	_schedule_next_power_up_spawn()
	_apply_biome_theme()
	boss_warning_label.visible = false
	_update_hud()


func _process(_delta: float) -> void:
	if _game_over:
		return
	_player_hit_cooldown_left = maxf(0.0, _player_hit_cooldown_left - _delta)

	if _boss_active and is_instance_valid(_boss_ufo) and _boss_ufo.has_method("get_health"):
		var boss_health: int = int(_boss_ufo.get_health())
		if boss_health != _boss_health_cache:
			_boss_health_cache = boss_health
			_update_hud()

	if _active_power_up == "":
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now >= _active_power_up_expires_at:
		_clear_power_up()
		return

	var seconds_left := maxi(0, int(ceili(_active_power_up_expires_at - now)))
	if seconds_left != _power_up_seconds_left:
		_power_up_seconds_left = seconds_left
		_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not _game_over:
		return
	if event.is_action_pressed("player_fire"):
		get_tree().reload_current_scene()


func _ensure_input_actions() -> void:
	if not InputMap.has_action("player_fire"):
		InputMap.add_action("player_fire")
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")

	if not _has_joy_button_binding("player_fire", JOY_BUTTON_A):
		var fire_event := InputEventJoypadButton.new()
		fire_event.button_index = JOY_BUTTON_A
		InputMap.action_add_event("player_fire", fire_event)
	if not _has_key_binding("player_fire", KEY_SPACE):
		var fire_key_event := InputEventKey.new()
		fire_key_event.keycode = KEY_SPACE
		InputMap.action_add_event("player_fire", fire_key_event)

	if not _has_joy_axis_binding("move_left", JOY_AXIS_LEFT_X, -1.0):
		var left_event := InputEventJoypadMotion.new()
		left_event.axis = JOY_AXIS_LEFT_X
		left_event.axis_value = -1.0
		InputMap.action_add_event("move_left", left_event)
	if not _has_joy_button_binding("move_left", JOY_BUTTON_DPAD_LEFT):
		var dpad_left_event := InputEventJoypadButton.new()
		dpad_left_event.button_index = JOY_BUTTON_DPAD_LEFT
		InputMap.action_add_event("move_left", dpad_left_event)
	if not _has_key_binding("move_left", KEY_A):
		var key_left_a_event := InputEventKey.new()
		key_left_a_event.keycode = KEY_A
		InputMap.action_add_event("move_left", key_left_a_event)
	if not _has_key_binding("move_left", KEY_LEFT):
		var key_left_event := InputEventKey.new()
		key_left_event.keycode = KEY_LEFT
		InputMap.action_add_event("move_left", key_left_event)

	if not _has_joy_axis_binding("move_right", JOY_AXIS_LEFT_X, 1.0):
		var right_event := InputEventJoypadMotion.new()
		right_event.axis = JOY_AXIS_LEFT_X
		right_event.axis_value = 1.0
		InputMap.action_add_event("move_right", right_event)
	if not _has_joy_button_binding("move_right", JOY_BUTTON_DPAD_RIGHT):
		var dpad_right_event := InputEventJoypadButton.new()
		dpad_right_event.button_index = JOY_BUTTON_DPAD_RIGHT
		InputMap.action_add_event("move_right", dpad_right_event)
	if not _has_key_binding("move_right", KEY_D):
		var key_right_d_event := InputEventKey.new()
		key_right_d_event.keycode = KEY_D
		InputMap.action_add_event("move_right", key_right_d_event)
	if not _has_key_binding("move_right", KEY_RIGHT):
		var key_right_event := InputEventKey.new()
		key_right_event.keycode = KEY_RIGHT
		InputMap.action_add_event("move_right", key_right_event)


func _has_joy_button_binding(action_name: StringName, button_index: JoyButton) -> bool:
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventJoypadButton and existing_event.button_index == button_index:
			return true
	return false


func _has_joy_axis_binding(action_name: StringName, axis: JoyAxis, direction: float) -> bool:
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventJoypadMotion and existing_event.axis == axis and signf(existing_event.axis_value) == signf(direction):
			return true
	return false


func _has_key_binding(action_name: StringName, keycode: Key) -> bool:
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey and existing_event.keycode == keycode:
			return true
	return false


func _spawn_ufo() -> void:
	if _boss_active:
		return
	var ufo := UFO_SCENE.instantiate()
	var view_size := get_viewport_rect().size
	var speed_multiplier := _get_ufo_speed_multiplier()
	var shot_delay_multiplier := _get_ufo_shot_delay_multiplier()
	var ufo_variant_index := _pick_variant_index(UFO_SHAPES.size(), 2)
	var ufo_palette := _ufo_palette_for_index(ufo_variant_index)
	ufo.screen_width = view_size.x
	ufo.top_band_height = minf(view_size.y * 0.45, 280.0)
	ufo.min_speed = 70.0 * speed_multiplier
	ufo.max_speed = 140.0 * speed_multiplier
	ufo.shot_delay_min = 0.9 * shot_delay_multiplier
	ufo.shot_delay_max = 2.3 * shot_delay_multiplier
	ufo.shape_style = UFO_SHAPES[ufo_variant_index]
	ufo.movement_pattern = UFO_PATTERNS[ufo_variant_index]
	ufo.primary_color = ufo_palette["primary"]
	ufo.secondary_color = ufo_palette["secondary"]
	ufo.detail_color = ufo_palette["detail"]
	ufo.global_position = Vector2(
		_rng.randf_range(80.0, maxf(80.0, view_size.x - 80.0)),
		_rng.randf_range(60.0, maxf(60.0, ufo.top_band_height - 40.0))
	)
	ufo.shoot_requested.connect(_on_ufo_shoot_requested)
	ufo.destroyed.connect(_on_ufo_destroyed.bind(false))
	enemies.add_child(ufo)


func _spawn_boss_ufo() -> void:
	_boss_active = true
	for enemy in enemies.get_children():
		if enemy != _boss_ufo:
			enemy.queue_free()

	var boss := BOSS_UFO_SCENE.instantiate()
	var view_size := get_viewport_rect().size
	var boss_variant_index := _pick_variant_index(BOSS_SHAPES.size(), 3)
	var boss_palette := _boss_palette_for_index(boss_variant_index)
	boss.screen_width = view_size.x
	boss.top_band_height = minf(view_size.y * 0.35, 210.0)
	boss.min_speed = 72.0
	boss.max_speed = 118.0
	boss.bullet_delay_min = 0.22
	boss.bullet_delay_max = 0.46
	boss.extra_bullet_chance = 0.54
	boss.bomb_delay_min = 0.6
	boss.bomb_delay_max = 1.06
	boss.noise_delay_min = 0.8
	boss.noise_delay_max = 1.6
	var boss_level_scale := _get_boss_level_multiplier()
	boss.min_speed *= boss_level_scale
	boss.max_speed *= boss_level_scale
	boss.bullet_delay_min *= maxf(0.62, 1.0 - float(_level - 1) * 0.03)
	boss.bullet_delay_max *= maxf(0.62, 1.0 - float(_level - 1) * 0.03)
	boss.bomb_delay_min *= maxf(0.65, 1.0 - float(_level - 1) * 0.025)
	boss.bomb_delay_max *= maxf(0.65, 1.0 - float(_level - 1) * 0.025)
	boss.extra_bullet_chance = minf(0.78, boss.extra_bullet_chance + float(_level - 1) * 0.02)
	boss.shape_style = BOSS_SHAPES[boss_variant_index]
	boss.movement_pattern = BOSS_PATTERNS[boss_variant_index]
	boss.primary_color = boss_palette["primary"]
	boss.secondary_color = boss_palette["secondary"]
	boss.core_color = boss_palette["core"]
	boss.global_position = Vector2(view_size.x * 0.5, 120.0)
	boss.bullet_requested.connect(_on_ufo_shoot_requested)
	boss.bomb_requested.connect(_on_boss_bomb_requested)
	boss.noise_requested.connect(_on_boss_noise_requested)
	boss.destroyed.connect(_on_ufo_destroyed.bind(true))
	enemies.add_child(boss)
	_boss_ufo = boss
	_boss_health_cache = boss.get_health()
	if _sfx and _sfx.has_method("play_boss_spawn"):
		_sfx.play_boss_spawn()
	if _sfx and _sfx.has_method("play_boss_theme"):
		_sfx.play_boss_theme()
	_show_boss_warning()
	_update_hud()


func _on_player_shoot_requested(spawn_position: Vector2) -> void:
	if _game_over:
		return
	if _sfx and _sfx.has_method("play_fire"):
		_sfx.play_fire()

	match _active_power_up:
		"double_shot":
			_spawn_player_bullet(spawn_position + Vector2(-10.0, 0.0))
			_spawn_player_bullet(spawn_position + Vector2(10.0, 0.0))
		"laser_beam":
			_spawn_player_laser(spawn_position + Vector2(0.0, -14.0))
		"split_ship":
			_spawn_player_bullet(spawn_position + Vector2(-18.0, 0.0))
			_spawn_player_bullet(spawn_position + Vector2(18.0, 0.0))
		_:
			_spawn_player_bullet(spawn_position)


func _on_ufo_shoot_requested(spawn_position: Vector2) -> void:
	if _game_over:
		return
	if _sfx and _sfx.has_method("play_enemy_fire"):
		_sfx.play_enemy_fire()
	var beam := ENEMY_BEAM_SCENE.instantiate()
	beam.global_position = spawn_position
	beam.speed = 340.0 * _get_enemy_projectile_speed_multiplier()
	enemy_projectiles.add_child(beam)


func _on_boss_bomb_requested(spawn_position: Vector2, drift_x: float) -> void:
	if _game_over:
		return
	if _sfx and _sfx.has_method("play_boss_bomb"):
		_sfx.play_boss_bomb()
	var bomb := BOSS_BOMB_SCENE.instantiate()
	var projectile_multiplier := _get_enemy_projectile_speed_multiplier()
	bomb.global_position = spawn_position
	bomb.speed = _rng.randf_range(255.0, 300.0) * projectile_multiplier
	bomb.max_speed = _rng.randf_range(390.0, 460.0) * projectile_multiplier
	bomb.acceleration = _rng.randf_range(140.0, 180.0) * projectile_multiplier
	bomb.wobble_strength = _rng.randf_range(32.0, 52.0)
	bomb.wobble_frequency = _rng.randf_range(3.2, 5.4)
	if bomb.has_method("set_drift_x"):
		bomb.set_drift_x(drift_x)
	enemy_projectiles.add_child(bomb)


func _on_boss_noise_requested() -> void:
	if _game_over:
		return
	if _sfx and _sfx.has_method("play_boss_noise"):
		_sfx.play_boss_noise()


func _on_player_bullet_hit_ufo(ufo: Area2D) -> void:
	if not is_instance_valid(ufo):
		return
	if ufo.has_method("take_hit"):
		ufo.take_hit()


func _on_ufo_destroyed(_world_position: Vector2, is_boss: bool = false) -> void:
	_spawn_explosion(_world_position, 2.1 if is_boss else 1.0)
	if is_boss:
		_score += BOSS_SCORE
		_boss_active = false
		_boss_ufo = null
		_boss_health_cache = -1
		_bosses_defeated += 1
		_regular_ufo_destroyed = 0
		_update_level_progression()
		if _sfx and _sfx.has_method("play_enemy_destroyed"):
			_sfx.play_enemy_destroyed()
		_update_hud()
		for i in UFO_COUNT:
			_spawn_ufo()
		return

	_score += 10
	_total_regular_ufo_destroyed += 1
	_regular_ufo_destroyed += 1
	_update_level_progression()
	if _sfx and _sfx.has_method("play_enemy_destroyed"):
		_sfx.play_enemy_destroyed()
	_update_hud()

	if _regular_ufo_destroyed >= REGULAR_UFO_KILLS_FOR_BOSS and not _boss_active:
		_spawn_boss_ufo()
		return

	var respawn_timer := get_tree().create_timer(0.9)
	respawn_timer.timeout.connect(func() -> void:
		if not _game_over and not _boss_active:
			_spawn_ufo()
	)


func _on_player_hit() -> void:
	if _game_over:
		return
	if _player_hit_cooldown_left > 0.0:
		return
	_player_hit_cooldown_left = PLAYER_HIT_COOLDOWN
	_life_health -= 1
	_spawn_explosion(player.global_position, 0.95)
	_update_life_ui()
	if _life_health > 0:
		if _sfx and _sfx.has_method("play_player_hit"):
			_sfx.play_player_hit()
		return

	_lives_left -= 1
	if _lives_left > 0:
		_life_health = HITS_PER_LIFE
		_spawn_explosion(player.global_position, 1.25)
		if _sfx and _sfx.has_method("play_player_hit"):
			_sfx.play_player_hit()
		_update_life_ui()
		return

	if _sfx and _sfx.has_method("play_player_hit"):
		_sfx.play_player_hit()
	_clear_power_up()
	_game_over = true
	if player.has_method("set_active"):
		player.set_active(false)
	boss_warning_label.visible = false
	if _sfx and _sfx.has_method("play_game_over"):
		_sfx.play_game_over()
	status_label.text = "Game Over! Press A or Space to restart."
	for projectile in enemy_projectiles.get_children():
		projectile.queue_free()
	for ufo in enemies.get_children():
		if ufo.has_method("stop_actions"):
			ufo.stop_actions()


func _update_hud() -> void:
	score_label.text = "Score: %d" % _score
	level_label.text = "Level: %d | %s" % [_level, _biome_name]
	lives_label.text = "Lives: %d" % _lives_left
	_update_life_ui()
	if not _game_over:
		var controls_text := "Move left stick, D-pad, or A/D/Arrows. Press A or Space to shoot."
		if _boss_active:
			controls_text += "  BOSS FIGHT: dodge bombs and stay aggressive!"
		else:
			controls_text += "  UFO defeated: %d/%d" % [_regular_ufo_destroyed, REGULAR_UFO_KILLS_FOR_BOSS]
		if _active_power_up != "":
			var pretty_name := _pretty_power_up_name(_active_power_up)
			status_label.text = "%s  Power-up: %s (%ds)" % [controls_text, pretty_name, _power_up_seconds_left]
		else:
			status_label.text = controls_text


func _spawn_player_bullet(spawn_position: Vector2) -> void:
	var bullet := PLAYER_BULLET_SCENE.instantiate()
	bullet.global_position = spawn_position
	bullet.hit_ufo.connect(_on_player_bullet_hit_ufo)
	projectiles.add_child(bullet)


func _spawn_player_laser(spawn_position: Vector2) -> void:
	var laser := PLAYER_LASER_SCENE.instantiate()
	laser.global_position = spawn_position
	laser.hit_ufo.connect(_on_player_bullet_hit_ufo)
	projectiles.add_child(laser)


func _schedule_next_power_up_spawn() -> void:
	var timer := get_tree().create_timer(_rng.randf_range(5.5, 10.0))
	timer.timeout.connect(func() -> void:
		if _game_over:
			return
		_spawn_power_up()
		_schedule_next_power_up_spawn()
	)


func _spawn_power_up() -> void:
	var pickup := POWER_UP_SCENE.instantiate()
	var view_size := get_viewport_rect().size
	pickup.global_position = Vector2(_rng.randf_range(42.0, view_size.x - 42.0), -24.0)
	pickup.set_kind(POWER_UP_TYPES[_rng.randi_range(0, POWER_UP_TYPES.size() - 1)])
	pickup.collected.connect(_on_power_up_collected)
	power_ups.add_child(pickup)


func _on_power_up_collected(power_up_kind: String) -> void:
	if _game_over:
		return
	if _sfx and _sfx.has_method("play_power_up"):
		_sfx.play_power_up()
	_active_power_up = power_up_kind
	_active_power_up_expires_at = Time.get_ticks_msec() / 1000.0 + POWER_UP_DURATION
	_power_up_seconds_left = int(POWER_UP_DURATION)
	if player.has_method("set_split_active"):
		player.set_split_active(_active_power_up == "split_ship")
	_update_hud()


func _clear_power_up() -> void:
	_active_power_up = ""
	_active_power_up_expires_at = 0.0
	_power_up_seconds_left = -1
	if player.has_method("set_split_active"):
		player.set_split_active(false)
	_update_hud()


func _pretty_power_up_name(power_up_kind: String) -> String:
	match power_up_kind:
		"double_shot":
			return "Double Shot"
		"laser_beam":
			return "Laser Beam"
		"split_ship":
			return "Split Ship"
		_:
			return "Unknown"


func _show_boss_warning() -> void:
	if is_instance_valid(_boss_warning_tween):
		_boss_warning_tween.kill()

	boss_warning_label.visible = true
	boss_warning_label.modulate = Color(1.0, 0.31, 0.31, 0.0)
	boss_warning_label.scale = Vector2(0.72, 0.72)

	_boss_warning_tween = create_tween()
	_boss_warning_tween.tween_property(boss_warning_label, "modulate:a", 1.0, 0.16)
	_boss_warning_tween.parallel().tween_property(boss_warning_label, "scale", Vector2.ONE, 0.16)
	for i in 3:
		_boss_warning_tween.tween_property(boss_warning_label, "modulate:a", 0.42, 0.14)
		_boss_warning_tween.tween_property(boss_warning_label, "modulate:a", 1.0, 0.14)
	_boss_warning_tween.tween_interval(0.42)
	_boss_warning_tween.tween_property(boss_warning_label, "modulate:a", 0.0, 0.2)
	_boss_warning_tween.finished.connect(func() -> void:
		boss_warning_label.visible = false
	)


func _update_life_ui() -> void:
	if _life_bars.is_empty():
		return
	for i in _life_bars.size():
		var bar := _life_bars[i]
		if i < _lives_left - 1:
			bar.value = HITS_PER_LIFE
			bar.modulate = Color(0.25, 0.95, 0.35, 1.0)
		elif i == _lives_left - 1:
			bar.value = maxf(0.0, _life_health)
			bar.modulate = _life_color_for_ratio(float(bar.value) / float(HITS_PER_LIFE))
		else:
			bar.value = 0.0
			bar.modulate = Color(0.38, 0.38, 0.42, 0.78)


func _life_color_for_ratio(ratio: float) -> Color:
	if ratio > 0.6:
		return Color(0.25, 0.95, 0.35, 1.0)
	if ratio > 0.3:
		return Color(1.0, 0.85, 0.2, 1.0)
	return Color(1.0, 0.3, 0.3, 1.0)


func _update_level_progression() -> void:
	var new_level := 1 + int(_total_regular_ufo_destroyed / LEVEL_UP_EVERY_KILLS) + _bosses_defeated
	if new_level == _level:
		return
	_level = new_level
	_apply_biome_theme()
	_update_hud()


func _get_ufo_speed_multiplier() -> float:
	return 1.0 + minf(0.85, float(_level - 1) * 0.08)


func _get_ufo_shot_delay_multiplier() -> float:
	return maxf(0.56, 1.0 - float(_level - 1) * 0.05)


func _get_enemy_projectile_speed_multiplier() -> float:
	return 1.0 + minf(0.75, float(_level - 1) * 0.06)


func _get_boss_level_multiplier() -> float:
	return 1.0 + minf(0.55, float(_level - 1) * 0.05)


func _spawn_explosion(world_position: Vector2, size_scale: float = 1.0) -> void:
	var explosion := EXPLOSION_SCENE.instantiate()
	explosion.global_position = world_position
	if explosion.has_method("set_size_scale"):
		explosion.set_size_scale(size_scale)
	explosions.add_child(explosion)


func _pick_variant_index(total_variants: int, levels_per_unlock: int) -> int:
	if total_variants <= 1:
		return 0
	var unlocked := mini(total_variants, 1 + int((_level - 1) / levels_per_unlock))
	return _rng.randi_range(0, unlocked - 1)


func _ufo_palette_for_index(index: int) -> Dictionary:
	var palettes := _ufo_palettes_for_biome(_current_biome_index())
	var safe_index := clampi(index, 0, palettes.size() - 1)
	return palettes[safe_index]


func _boss_palette_for_index(index: int) -> Dictionary:
	var palettes := _boss_palettes_for_biome(_current_biome_index())
	var safe_index := clampi(index, 0, palettes.size() - 1)
	return palettes[safe_index]


func _current_biome_index() -> int:
	return mini(3, int((_level - 1) / 3))


func _apply_biome_theme() -> void:
	var biome_index := _current_biome_index()
	_biome_name = _biome_name_for_index(biome_index)
	var bg_colors := [
		Color(0.03, 0.08, 0.15, 1.0),
		Color(0.18, 0.06, 0.04, 1.0),
		Color(0.04, 0.15, 0.08, 1.0),
		Color(0.06, 0.04, 0.11, 1.0)
	]
	background.color = bg_colors[biome_index]


func _biome_name_for_index(index: int) -> String:
	match index:
		1:
			return "Inferno"
		2:
			return "Toxic"
		3:
			return "Void"
		_:
			return "Neon"


func _ufo_palettes_for_biome(biome_index: int) -> Array[Dictionary]:
	match biome_index:
		1:
			return [
				{"primary": Color(1.0, 0.72, 0.28, 1.0), "secondary": Color(1.0, 0.36, 0.2, 1.0), "detail": Color(1.0, 0.9, 0.68, 1.0)},
				{"primary": Color(1.0, 0.5, 0.24, 1.0), "secondary": Color(0.95, 0.24, 0.16, 1.0), "detail": Color(1.0, 0.8, 0.55, 1.0)},
				{"primary": Color(1.0, 0.62, 0.2, 1.0), "secondary": Color(1.0, 0.26, 0.22, 1.0), "detail": Color(1.0, 0.88, 0.52, 1.0)},
				{"primary": Color(0.95, 0.34, 0.18, 1.0), "secondary": Color(0.82, 0.12, 0.08, 1.0), "detail": Color(1.0, 0.72, 0.42, 1.0)}
			]
		2:
			return [
				{"primary": Color(0.52, 1.0, 0.34, 1.0), "secondary": Color(0.17, 0.88, 0.36, 1.0), "detail": Color(0.88, 1.0, 0.72, 1.0)},
				{"primary": Color(0.66, 1.0, 0.24, 1.0), "secondary": Color(0.22, 0.8, 0.18, 1.0), "detail": Color(0.94, 1.0, 0.56, 1.0)},
				{"primary": Color(0.3, 0.95, 0.58, 1.0), "secondary": Color(0.1, 0.72, 0.42, 1.0), "detail": Color(0.76, 1.0, 0.86, 1.0)},
				{"primary": Color(0.78, 1.0, 0.3, 1.0), "secondary": Color(0.3, 0.9, 0.16, 1.0), "detail": Color(0.98, 1.0, 0.6, 1.0)}
			]
		3:
			return [
				{"primary": Color(0.8, 0.56, 1.0, 1.0), "secondary": Color(0.45, 0.36, 1.0, 1.0), "detail": Color(0.95, 0.9, 1.0, 1.0)},
				{"primary": Color(0.95, 0.44, 1.0, 1.0), "secondary": Color(0.38, 0.24, 0.96, 1.0), "detail": Color(1.0, 0.84, 1.0, 1.0)},
				{"primary": Color(0.62, 0.48, 1.0, 1.0), "secondary": Color(0.26, 0.2, 0.78, 1.0), "detail": Color(0.88, 0.86, 1.0, 1.0)},
				{"primary": Color(0.92, 0.52, 0.96, 1.0), "secondary": Color(0.54, 0.22, 0.85, 1.0), "detail": Color(1.0, 0.9, 0.98, 1.0)}
			]
		_:
			return [
				{"primary": Color("87ff9f"), "secondary": Color("67d8ff"), "detail": Color("c7ffe4")},
				{"primary": Color(0.46, 1.0, 0.82, 1.0), "secondary": Color(0.1, 0.66, 1.0, 1.0), "detail": Color(0.86, 1.0, 0.94, 1.0)},
				{"primary": Color(0.52, 0.95, 1.0, 1.0), "secondary": Color(0.2, 0.84, 1.0, 1.0), "detail": Color(0.88, 1.0, 1.0, 1.0)},
				{"primary": Color(0.64, 1.0, 0.7, 1.0), "secondary": Color(0.25, 0.9, 0.96, 1.0), "detail": Color(0.92, 1.0, 0.95, 1.0)}
			]


func _boss_palettes_for_biome(biome_index: int) -> Array[Dictionary]:
	match biome_index:
		1:
			return [
				{"primary": Color(1.0, 0.52, 0.28, 1.0), "secondary": Color(0.95, 0.2, 0.18, 0.95), "core": Color(1.0, 0.95, 0.62, 0.95)},
				{"primary": Color(1.0, 0.66, 0.26, 1.0), "secondary": Color(1.0, 0.28, 0.12, 0.95), "core": Color(1.0, 0.92, 0.52, 0.95)},
				{"primary": Color(0.98, 0.42, 0.2, 1.0), "secondary": Color(0.85, 0.12, 0.08, 0.95), "core": Color(1.0, 0.82, 0.42, 0.95)},
				{"primary": Color(1.0, 0.58, 0.34, 1.0), "secondary": Color(0.92, 0.3, 0.14, 0.95), "core": Color(1.0, 0.96, 0.7, 0.95)}
			]
		2:
			return [
				{"primary": Color(0.58, 1.0, 0.28, 1.0), "secondary": Color(0.16, 0.86, 0.24, 0.95), "core": Color(0.94, 1.0, 0.62, 0.95)},
				{"primary": Color(0.7, 1.0, 0.22, 1.0), "secondary": Color(0.24, 0.92, 0.16, 0.95), "core": Color(0.98, 1.0, 0.68, 0.95)},
				{"primary": Color(0.36, 1.0, 0.46, 1.0), "secondary": Color(0.12, 0.78, 0.32, 0.95), "core": Color(0.9, 1.0, 0.82, 0.95)},
				{"primary": Color(0.84, 1.0, 0.3, 1.0), "secondary": Color(0.34, 0.9, 0.2, 0.95), "core": Color(1.0, 1.0, 0.75, 0.95)}
			]
		3:
			return [
				{"primary": Color(0.78, 0.52, 1.0, 1.0), "secondary": Color(0.42, 0.28, 0.96, 0.95), "core": Color(0.98, 0.9, 1.0, 0.95)},
				{"primary": Color(0.96, 0.48, 1.0, 1.0), "secondary": Color(0.5, 0.2, 0.88, 0.95), "core": Color(1.0, 0.88, 0.98, 0.95)},
				{"primary": Color(0.65, 0.44, 1.0, 1.0), "secondary": Color(0.24, 0.18, 0.78, 0.95), "core": Color(0.9, 0.86, 1.0, 0.95)},
				{"primary": Color(0.9, 0.52, 0.98, 1.0), "secondary": Color(0.56, 0.24, 0.86, 0.95), "core": Color(1.0, 0.9, 1.0, 0.95)}
			]
		_:
			return [
				{"primary": Color(0.73, 0.1, 0.94, 1.0), "secondary": Color(1.0, 0.16, 0.5, 0.95), "core": Color(1.0, 0.86, 0.22, 0.95)},
				{"primary": Color(0.33, 0.95, 1.0, 1.0), "secondary": Color(0.15, 0.55, 1.0, 0.95), "core": Color(0.95, 1.0, 0.5, 0.95)},
				{"primary": Color(1.0, 0.44, 0.28, 1.0), "secondary": Color(0.95, 0.18, 0.32, 0.95), "core": Color(1.0, 0.96, 0.52, 0.95)},
				{"primary": Color(0.66, 1.0, 0.32, 1.0), "secondary": Color(0.22, 0.9, 0.42, 0.95), "core": Color(0.92, 1.0, 0.68, 0.95)}
			]
