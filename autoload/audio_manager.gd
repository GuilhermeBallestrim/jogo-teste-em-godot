extends Node
## Musica e efeitos sonoros.
## Registrado como autoload com o nome `Audio`.
##
## Requer o gerador padrao de buses do Godot (Master) -- que existe por padrao.

const MASTER_BUS := &"Master"
const SFX_VOICES := 8
const SILENCE := -INF

var _music_players: Array[AudioStreamPlayer] = []
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _fade_tween: Tween

var _music_enabled: bool = true
var _sfx_enabled: bool = true


func _ready() -> void:
	# Continua tocando enquanto o jogo esta pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_players = [_make_player(MASTER_BUS), _make_player(MASTER_BUS)]

	for _i in SFX_VOICES:
		_sfx_pool.append(_make_player(MASTER_BUS))


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


# ---------------------------------------------------------------- musica


## Toca uma musica com crossfade. Passar `null` equivale a `stop_music()`.
func play_music(stream: AudioStream, fade_time: float = 1.0) -> void:
	if not _music_enabled:
		return
	if stream == null:
		stop_music(fade_time)
		return
	if _music_players[0].playing and _music_players[0].stream == stream:
		return

	var incoming := _music_players[0]
	var outgoing := _music_players[1]
	if incoming.playing:
		incoming = _music_players[1]
		outgoing = _music_players[0]

	_kill_fade()

	incoming.stream = stream
	incoming.volume_db = SILENCE if fade_time > 0.0 else 0.0
	incoming.play()

	_fade_tween = create_tween()
	_fade_tween.tween_property(incoming, "volume_db", 0.0, fade_time)
	if outgoing.playing and fade_time > 0.0:
		_fade_tween.tween_property(outgoing, "volume_db", SILENCE, fade_time)
		_fade_tween.chain().tween_callback(outgoing.stop)
	else:
		outgoing.stop()


func stop_music(fade_time: float = 1.0) -> void:
	_kill_fade()
	if fade_time <= 0.0:
		for player in _music_players:
			player.stop()
		return

	_fade_tween = create_tween()
	for player in _music_players:
		_fade_tween.tween_property(player, "volume_db", SILENCE, fade_time)
	_fade_tween.chain().tween_callback(_stop_all_music)


func current_music() -> AudioStream:
	for player in _music_players:
		if player.playing:
			return player.stream
	return null


func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	if enabled and current_music() != null:
		play_music(current_music(), 0.3)
	elif not enabled:
		stop_music(0.3)


# ------------------------------------------------------------------- sfx


## Toca um efeito no proximo voice livre do pool (round-robin).
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _sfx_enabled or stream == null:
		return
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled
	if not enabled:
		for player in _sfx_pool:
			player.stop()


# ---------------------------------------------------------------- volume


func set_master_volume(linear: float) -> void:
	_set_bus_volume(MASTER_BUS, linear)


func set_music_volume(linear: float) -> void:
	for player in _music_players:
		player.volume_db = linear_to_db(clampf(linear, 0.0, 1.0)) if linear > 0.0 else SILENCE


func set_sfx_volume(linear: float) -> void:
	for player in _sfx_pool:
		player.volume_db = linear_to_db(clampf(linear, 0.0, 1.0)) if linear > 0.0 else SILENCE


func _set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0, 1.0)) if linear > 0.0 else SILENCE)


func _stop_all_music() -> void:
	for player in _music_players:
		player.stop()


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null