extends Node

const MIX_RATE := 44100.0
const BUFFER_LENGTH := 0.4

var _fire_player: AudioStreamPlayer
var _enemy_fire_player: AudioStreamPlayer
var _enemy_destroyed_player: AudioStreamPlayer
var _player_hit_player: AudioStreamPlayer
var _game_over_player: AudioStreamPlayer
var _power_up_player: AudioStreamPlayer
var _boss_noise_player: AudioStreamPlayer
var _boss_spawn_player: AudioStreamPlayer
var _boss_bomb_player: AudioStreamPlayer
var _boss_theme_player: AudioStreamPlayer


func _ready() -> void:
	_fire_player = _create_generator_player("FireSfx")
	_enemy_fire_player = _create_generator_player("EnemyFireSfx")
	_enemy_destroyed_player = _create_generator_player("EnemyDestroyedSfx")
	_player_hit_player = _create_generator_player("PlayerHitSfx")
	_game_over_player = _create_generator_player("GameOverSfx")
	_power_up_player = _create_generator_player("PowerUpSfx")
	_boss_noise_player = _create_generator_player("BossNoiseSfx")
	_boss_spawn_player = _create_generator_player("BossSpawnSfx")
	_boss_bomb_player = _create_generator_player("BossBombSfx")
	_boss_theme_player = _create_generator_player("BossThemeSfx")


func play_fire() -> void:
	_play_tone(_fire_player, 980.0, 560.0, 0.06, 0.24, "square")


func play_enemy_fire() -> void:
	_play_tone(_enemy_fire_player, 360.0, 240.0, 0.09, 0.2, "sine")


func play_enemy_destroyed() -> void:
	_play_tone(_enemy_destroyed_player, 420.0, 120.0, 0.18, 0.28, "noise")


func play_player_hit() -> void:
	_play_tone(_player_hit_player, 220.0, 90.0, 0.26, 0.34, "saw")


func play_game_over() -> void:
	_play_tone(_game_over_player, 180.0, 60.0, 0.44, 0.28, "sine")


func play_power_up() -> void:
	_play_tone(_power_up_player, 520.0, 980.0, 0.13, 0.24, "square")


func play_boss_noise() -> void:
	_play_tone(_boss_noise_player, 120.0, 100.0, 0.22, 0.3, "saw")


func play_boss_spawn() -> void:
	_play_tone(_boss_spawn_player, 85.0, 180.0, 0.45, 0.32, "saw")


func play_boss_bomb() -> void:
	_play_tone(_boss_bomb_player, 240.0, 130.0, 0.16, 0.24, "noise")


func play_boss_theme() -> void:
	_play_melody(
		_boss_theme_player,
		PackedFloat32Array([196.0, 246.94, 293.66, 392.0, 329.63, 440.0, 392.0, 523.25]),
		0.11,
		0.22,
		"square"
	)


func _create_generator_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = "Master"

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = BUFFER_LENGTH
	player.stream = stream

	add_child(player)
	return player


func _play_tone(player: AudioStreamPlayer, freq_start: float, freq_end: float, duration: float, amplitude: float, waveform: String) -> void:
	if duration <= 0.0:
		return

	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count := int(maxf(1.0, duration * MIX_RATE))
	var frames := PackedVector2Array()
	frames.resize(sample_count)

	var attack := maxi(1, int(sample_count * 0.06))
	var release := maxi(1, int(sample_count * 0.22))
	var phase := 0.0
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.randomize()

	for i in sample_count:
		var t := float(i) / float(sample_count)
		var frequency := lerpf(freq_start, freq_end, t)
		phase = fmod(phase + TAU * frequency / MIX_RATE, TAU)

		var envelope := 1.0
		if i < attack:
			envelope = float(i) / float(attack)
		elif i > sample_count - release:
			envelope = maxf(0.0, float(sample_count - i) / float(release))

		var raw_sample := _sample_waveform(waveform, phase, noise_rng)
		var sample_value := raw_sample * amplitude * envelope
		frames[i] = Vector2(sample_value, sample_value)

	playback.clear_buffer()
	playback.push_buffer(frames)


func _sample_waveform(waveform: String, phase: float, rng: RandomNumberGenerator) -> float:
	match waveform:
		"square":
			return 1.0 if phase < PI else -1.0
		"saw":
			return (phase / PI) - 1.0
		"noise":
			return rng.randf_range(-1.0, 1.0)
		_:
			return sin(phase)


func _play_melody(player: AudioStreamPlayer, notes: PackedFloat32Array, note_duration: float, amplitude: float, waveform: String) -> void:
	if notes.is_empty() or note_duration <= 0.0:
		return

	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var total_samples := int(maxf(1.0, float(notes.size()) * note_duration * MIX_RATE))
	var frames := PackedVector2Array()
	frames.resize(total_samples)
	var write_index := 0
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.randomize()

	for note in notes:
		var note_samples := int(maxf(1.0, note_duration * MIX_RATE))
		var attack := maxi(1, int(note_samples * 0.08))
		var release := maxi(1, int(note_samples * 0.24))
		var phase := 0.0

		for i in note_samples:
			if write_index >= total_samples:
				break
			phase = fmod(phase + TAU * note / MIX_RATE, TAU)

			var envelope := 1.0
			if i < attack:
				envelope = float(i) / float(attack)
			elif i > note_samples - release:
				envelope = maxf(0.0, float(note_samples - i) / float(release))

			var raw_sample := _sample_waveform(waveform, phase, noise_rng)
			var sample_value := raw_sample * amplitude * envelope
			frames[write_index] = Vector2(sample_value, sample_value)
			write_index += 1

	playback.clear_buffer()
	playback.push_buffer(frames)
