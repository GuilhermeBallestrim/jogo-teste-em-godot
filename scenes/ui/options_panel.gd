class_name OptionsPanel
extends CanvasLayer
## Painel de opcoes. Abre por cima de qualquer tela (menu ou jogo pausado).
##
## Tres abas: audio/video, acessibilidade e controles. A de controles e a
## unica com estado proprio (`_capturing`): ela precisa "engolir" o proximo
## evento de teclado para virar binding, e isso nao pode vazar para o jogo
## que esta pausado atras do painel.

signal closed

## Rotulo amigavel de cada acao. O InputMap guarda `move_left`, que ninguem
## entende numa tela de opcoes.
const ACTION_LABELS := {
	&"move_left": "Esquerda",
	&"move_right": "Direita",
	&"move_up": "Cima",
	&"move_down": "Baixo",
	&"jump": "Pular",
	&"dash": "Dash",
	&"interact": "Usar item",
	&"attack": "Atacar",
	&"pause": "Pausar",
	&"restart": "Reiniciar",
}

@onready var _music: HSlider = %MusicSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _fullscreen: CheckButton = %FullscreenCheck
@onready var _close: Button = %CloseButton

@onready var _ui_scale: HSlider = %UiScaleSlider
@onready var _ui_scale_value: Label = %UiScaleValue
@onready var _shake: HSlider = %ShakeSlider
@onready var _shake_value: Label = %ShakeValue
@onready var _contrast: CheckButton = %ContrastCheck

@onready var _tabs: TabContainer = %Tabs
@onready var _bindings_box: VBoxContainer = %BindingsBox
@onready var _capture_hint: Label = %CaptureHint
@onready var _reset_bindings: Button = %ResetBindingsButton

## Acao esperando a proxima tecla, ou vazio.
var _capturing: StringName = &""
var _binding_buttons: Dictionary = {}


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

	_build_accessibility()
	_build_bindings()

	_tabs.custom_minimum_size = Vector2(0, 320)
	_close.pressed.connect(close)
	_close.grab_focus()


func close() -> void:
	Sfx.play(&"back")
	Settings.save_settings()
	closed.emit()


func _on_reset_bindings_pressed() -> void:
	Sfx.play(&"back", -4.0)
	_capturing = &""
	_capture_hint.text = ""
	Settings.reset_bindings()
	Settings.save_settings()
	for action: StringName in Settings.REMAPPABLE:
		_refresh_binding(action)


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


# ---------------------------------------------------------- acessibilidade


func _build_accessibility() -> void:
	_ui_scale.min_value = Settings.UI_SCALE_MIN
	_ui_scale.max_value = Settings.UI_SCALE_MAX
	_ui_scale.step = 0.05
	_ui_scale.value = Settings.ui_scale

	_shake.min_value = 0.0
	_shake.max_value = 1.0
	_shake.step = 0.25
	_shake.value = Settings.shake_scale

	_contrast.button_pressed = Settings.high_contrast

	_refresh_scale_labels()
	_ui_scale.value_changed.connect(func(_v: float) -> void:
		Settings.set_ui_scale(_ui_scale.value)
		_refresh_scale_labels()
		Presentation.apply_ui_scale(get_tree().root, Settings.ui_scale)
	)
	_shake.value_changed.connect(func(_v: float) -> void:
		Settings.set_shake_scale(_shake.value)
		_refresh_scale_labels()
	)
	_contrast.toggled.connect(func(on: bool) -> void:
		Settings.set_high_contrast(on)
		Presentation.set_contrast(get_tree().current_scene, on)
	)


func _refresh_scale_labels() -> void:
	_ui_scale_value.text = "%d%%" % int(Settings.ui_scale * 100.0)
	_shake_value.text = "nenhum" if Settings.shake_scale <= 0.0 else "%d%%" % int(
		Settings.shake_scale * 100.0
	)


# --------------------------------------------------------------- controles


func _build_bindings() -> void:
	for child in _bindings_box.get_children():
		child.queue_free()
	_binding_buttons.clear()

	for action: StringName in Settings.REMAPPABLE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(150, 0)
		name_label.text = ACTION_LABELS.get(action, String(action))
		row.add_child(name_label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 34)
		button.pressed.connect(_on_binding_pressed.bind(action))
		row.add_child(button)

		var hint := Label.new()
		hint.custom_minimum_size = Vector2(190, 0)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(hint)

		_bindings_box.add_child(row)
		_binding_buttons[action] = {"button": button, "hint": hint}
		_refresh_binding(action)


func _refresh_binding(action: StringName) -> void:
	var entry: Dictionary = _binding_buttons.get(action, {})
	if entry.is_empty():
		return
	(entry["button"] as Button).text = Settings.binding_text(action)
	(entry["hint"] as Label).text = "padrao: %s" % Settings.default_binding_text(action)


func _on_binding_pressed(action: StringName) -> void:
	_capturing = action
	Sfx.play(&"select")
	(entry_hint(action)).text = "pressione uma tecla..."
	(entry_button(action)).text = "..."
	_capture_hint.text = "Pressione a tecla de '%s' (ou Esc para cancelar)." % (
		ACTION_LABELS.get(action, String(action))
	)


func _input(event: InputEvent) -> void:
	if _capturing == &"":
		return
	var action := _capturing

	# Esc cancela. Precisa vir antes da traducao de InputEventKey, senao o
	# jogador cancelaria com a tecla que estava tentando atribuir.
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			_capturing = &""
			_capture_hint.text = ""
			_refresh_binding(action)
			get_viewport().set_input_as_handled()
			return
		_bind(action, key)
	elif event is InputEventMouseButton and event.pressed:
		_bind(action, event as InputEventMouseButton)

	get_viewport().set_input_as_handled()


func _bind(action: StringName, event: InputEvent) -> void:
	var other := Settings.conflict_with(event)
	if other != &"" and other != action:
		Sfx.play(&"back", -4.0)
		(entry_hint(action)).text = "essa tecla ja e '%s'" % ACTION_LABELS.get(
			other, String(other)
		)
		(entry_button(action)).text = Settings.binding_text(action)
		return

	Settings.set_binding(action, event)
	Sfx.play(&"select")
	_capturing = &""
	_capture_hint.text = ""
	_refresh_binding(action)
	Settings.save_settings()


func entry_button(action: StringName) -> Button:
	return (_binding_buttons.get(action, {}) as Dictionary).get("button", null)


func entry_hint(action: StringName) -> Label:
	return (_binding_buttons.get(action, {}) as Dictionary).get("hint", null)

