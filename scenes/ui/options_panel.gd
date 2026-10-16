class_name OptionsPanel
extends CanvasLayer
## Painel de opcoes. Abre por cima de qualquer tela (menu ou jogo pausado).

signal closed

@onready var _music: HSlider = %MusicSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _fullscreen: CheckButton = %FullscreenCheck
@onready var _close: Button = %CloseButton


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music.min_value = 0.0
	_music.max_value = 1.0
	_music.step = 0.05
	_sfx.min_value = 0.0
	_sfx.max_value = 1.0
	_sfx.step = 0.05

	_music.value = Settings.music_volume
	_sfx.value = Settings.sfx_volume
	_fullscreen.button_pressed = Settings.fullscreen

	_music.value_changed.connect(_on_music_changed)
	_sfx.value_changed.connect(_on_sfx_changed)
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_close.pressed.connect(close)

	_close.grab_focus()


func close() -> void:
	Sfx.play(&"back")
	Settings.save_settings()
	closed.emit()


func _on_music_changed(value: float) -> void:
	Settings.set_music_volume(value)
	# Preview: toca um acorde curto na propria musica para o usuario ouvir.
	if value > 0.05:
		Music.play()


func _on_sfx_changed(value: float) -> void:
	Settings.set_sfx_volume(value)
	if value > 0.05:
		Sfx.play(&"coin", -4.0, 1.0)


func _on_fullscreen_toggled(pressed: bool) -> void:
	Sfx.play(&"select")
	Settings.set_fullscreen(pressed)
	Settings.save_settings()