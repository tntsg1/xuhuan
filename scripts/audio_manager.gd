extends Node

var sfx_enabled: bool = true
var music_enabled: bool = true
var _players: Array[AudioStreamPlayer] = []


func play_sfx(path: String, pitch_variation := 0.08, volume_db := -8.0) -> void:
	if not sfx_enabled:
		return

	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Missing SFX: %s" % path)
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.finished.connect(_on_player_finished.bind(player))
	add_child(player)
	player.play()
	_players.append(player)


func play_music(_path: String) -> void:
	if not music_enabled:
		return


func _on_player_finished(player: AudioStreamPlayer) -> void:
	_players.erase(player)
	player.queue_free()
