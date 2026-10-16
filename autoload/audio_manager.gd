class_name AudioManager
extends Node
## Musica e efeitos sonoros.
## Registrado como autoload com o nome `Audio`.
##
## Cria os buses "Music" e "SFX" em tempo de execucao, entao nao depende de um
## `default_bus_layout.tres` no repositorio. Separar por bus (e nao por player)
## e o que permite trocar o volume do usuario sem quebrar o crossfade.
##
## Use [member instance] em vez do global `Audio` quando o codigo precisa
## compilar fora do jogo (por exemplo nos testes headless).

const MASTER_BUS := &"Master"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const SFX_VOICES := 8
## dB equivalente a silencio. -INF quebra interpolacao de Tween.
const SILENCE := -80.0

## Autoload vivo. `null` fora do jogo (ex.: rodando so os testes headless).
static var instance: AudioManager = null

var _music_players: Array[AudioStreamPlayer] = []
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _fade_tween: Tween

## Desligar aqui muta a trilha (os efeitos continuam).
var music_enabled: bool = true:
	set(value):
		music_enabled = value
		if not is_node_ready():
			return
		if value:
			if current_music() != null:
				play_music(current_music(), 0.3)
		else:
			stop_music(0.3)

## Desligar aqui muta os efeitos (a trilha continua).
var sfx_enabled: bool = true:
	set(value):
		sfx_enabled = value
		if value or not is_node_ready():
			return
		for player in _sfx_pool:
			player.stop()


func _init() -> void:
	instance = self


func _ready() -> void:
	# Continua tocando enquanto o jogo esta pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

	_music_players = [_make_player(MUSIC_BUS), _make_player(MUSIC_BUS)]
	for _i in SFX_VOICES:
		_sfx_pool.append(_make_player(SFX_BUS))


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, MASTER_BUS)


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


# ---------------------------------------------------------------- musica


## Toca uma musica com crossfade. Passar `null` equivale a [method stop_music].
func play_music(stream: AudioStream, fade_time: float = 1.0) -> void:
	if not music_enabled:
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

	if fade_time <= 0.0:
		outgoing.stop()
		return

	_fade_tween = create_tween()
	_fade_tween.tween_property(incoming, "volume_db", 0.0, fade_time)
	if outgoing.playing:
		_fade_tween.tween_property(outgoing, "volume_db", SILENCE, fade_time)
		_fade_tween.chain().tween_callback(outgoing.stop)
	else:
		outgoing.stop()


func stop_music(fade_time: float = 1.0) -> void:
	_kill_fade()
	if fade_time <= 0.0:
		_stop_all_music()
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


# ------------------------------------------------------------------- sfx


## Toca um efeito no proximo voice livre do pool (round-robin).
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sfx_enabled or stream == null:
		return
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


# ---------------------------------------------------------------- volume


## @param linear 0.0 = mudo, 1.0 = volume cheio.
func set_music_volume(linear: float) -> void:
	_set_bus_volume(MUSIC_BUS, linear)


func set_sfx_volume(linear: float) -> void:
	_set_bus_volume(SFX_BUS, linear)


func set_master_volume(linear: float) -> void:
	_set_bus_volume(MASTER_BUS, linear)


func get_bus_volume(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


func _set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var clamped := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(clamped) if clamped > 0.001 else SILENCE)
	AudioServer.set_bus_mute(index, clamped <= 0.001)


func _stop_all_music() -> void:
	for player in _music_players:
		player.stop()


func stop_all_sfx() -> void:
	for player in _sfx_pool:
		player.stop()


## Encerra tudo e descarta os AudioStreamWAV sintetizados. Sem isso o Godot
## acusa "ObjectDB instances leaked at exit" ao fechar o jogo.
func _exit_tree() -> void:
	_kill_fade()
	_stop_all_music()
	stop_all_sfx()
	Sfx.clear_cache()
	Music.clear_cache()
	if instance == self:
		instance = null


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null