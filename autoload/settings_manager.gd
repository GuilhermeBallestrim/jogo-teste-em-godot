extends Node
## Preferencias do jogador, salvas em `user://settings.cfg`.
## Registrado como autoload com o nome `Settings`.

signal applied

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"
const VIDEO_SECTION := "video"

var music_volume: float = 0.7
var sfx_volume: float = 0.9
var fullscreen: bool = false


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	music_volume = _clamp01(float(config.get_value(SECTION, "music", music_volume)))
	sfx_volume = _clamp01(float(config.get_value(SECTION, "sfx", sfx_volume)))
	fullscreen = bool(config.get_value(VIDEO_SECTION, "fullscreen", fullscreen))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "music", music_volume)
	config.set_value(SECTION, "sfx", sfx_volume)
	config.set_value(VIDEO_SECTION, "fullscreen", fullscreen)
	config.save(SETTINGS_PATH)


## Aplica as preferencias ao AudioServer e ao DisplayServer.
func apply() -> void:
	Audio.set_music_volume(music_volume)
	Audio.set_sfx_volume(sfx_volume)
	_set_fullscreen(fullscreen)
	applied.emit()


func set_music_volume(value: float) -> void:
	music_volume = _clamp01(value)
	Audio.set_music_volume(music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = _clamp01(value)
	Audio.set_sfx_volume(sfx_volume)


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_set_fullscreen(enabled)


## Sentido: true = janela cheia. Em plataformas sem troca de modo, nao faz nada.
func _set_fullscreen(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var target := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() == target:
		return
	DisplayServer.window_set_mode(target)


func _clamp01(value: float) -> float:
	return clampf(value, 0.0, 1.0)