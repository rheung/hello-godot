extends Node2D

const UFO_SCENE := preload("res://scenes/ufo.tscn")
const PLAYER_BULLET_SCENE := preload("res://scenes/player_bullet.tscn")
const ENEMY_BEAM_SCENE := preload("res://scenes/enemy_beam.tscn")

const UFO_COUNT := 4

@onready var player: Area2D = $Player
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var enemy_projectiles: Node2D = $EnemyProjectiles
@onready var score_label: Label = $HUD/ScoreLabel
@onready var status_label: Label = $HUD/StatusLabel

var _rng := RandomNumberGenerator.new()
var _score := 0
var _game_over := false


func _ready() -> void:
	_rng.randomize()
	player.shoot_requested.connect(_on_player_shoot_requested)
	player.hit.connect(_on_player_hit)
	for i in UFO_COUNT:
		_spawn_ufo()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not _game_over:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().reload_current_scene()


func _spawn_ufo() -> void:
	var ufo := UFO_SCENE.instantiate()
	var view_size := get_viewport_rect().size
	ufo.screen_width = view_size.x
	ufo.top_band_height = minf(view_size.y * 0.45, 280.0)
	ufo.global_position = Vector2(
		_rng.randf_range(80.0, maxf(80.0, view_size.x - 80.0)),
		_rng.randf_range(60.0, maxf(60.0, ufo.top_band_height - 40.0))
	)
	ufo.shoot_requested.connect(_on_ufo_shoot_requested)
	ufo.destroyed.connect(_on_ufo_destroyed)
	enemies.add_child(ufo)


func _on_player_shoot_requested(spawn_position: Vector2) -> void:
	if _game_over:
		return
	var bullet := PLAYER_BULLET_SCENE.instantiate()
	bullet.global_position = spawn_position
	bullet.hit_ufo.connect(_on_player_bullet_hit_ufo)
	projectiles.add_child(bullet)


func _on_ufo_shoot_requested(spawn_position: Vector2) -> void:
	if _game_over:
		return
	var beam := ENEMY_BEAM_SCENE.instantiate()
	beam.global_position = spawn_position
	beam.hit_player.connect(_on_enemy_beam_hit_player)
	enemy_projectiles.add_child(beam)


func _on_player_bullet_hit_ufo(ufo: Area2D) -> void:
	if not is_instance_valid(ufo):
		return
	if ufo.has_method("take_hit"):
		ufo.take_hit()


func _on_ufo_destroyed(_world_position: Vector2) -> void:
	_score += 10
	_update_hud()
	var respawn_timer := get_tree().create_timer(0.9)
	respawn_timer.timeout.connect(func() -> void:
		if not _game_over:
			_spawn_ufo()
	)


func _on_enemy_beam_hit_player() -> void:
	_on_player_hit()


func _on_player_hit() -> void:
	if _game_over:
		return
	_game_over = true
	status_label.text = "Game Over! Left click to restart."
	for ufo in enemies.get_children():
		if ufo.has_method("stop_actions"):
			ufo.stop_actions()


func _update_hud() -> void:
	score_label.text = "Score: %d" % _score
	if not _game_over:
		status_label.text = "Move mouse to steer. Right click to shoot."
