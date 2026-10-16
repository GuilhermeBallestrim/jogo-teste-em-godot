class_name PauseMenu
extends CanvasLayer
## Menu de pausa. Aberto pela fase enquanto `get_tree().paused` esta true.

signal resume_requested
signal restart_requested
signal options_requested
signal menu_requested
## Emitido depois que o progresso foi gravado com sucesso.
signal save_completed(ok: bool)

const OPTIONS_SCENE := "res://scenes/ui/options_panel.tscn"
## Mesmo slot que o menu principal le no botao "Continuar".
const SLOT := &"main"

@onready var _resume: Button = %ResumeButton
@onready var _restart: Button = %RestartButton
@onready var _options: Button = %OptionsButton
@onready var _save: Button = %SaveButton
@onready var _menu: Button = %MenuButton

var _options_panel: OptionsPanel = null


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_restart.text = "Reiniciar (%s)" % _key_hint(&"restart")

	_resume.pressed.connect(func() -> void: _emit_and_play(resume_requested))
	_restart.pressed.connect(func() -> void: _emit_and_play(restart_requested))
	_options.pressed.connect(_on_options)
	_save.pressed.connect(_on_save)
	_menu.pressed.connect(func() -> void: _emit_and_play(menu_requested))

	_resume.grab_focus()


func _on_save() -> void:
	Sfx.play(&"select")
	save_completed.emit(Save.save_game(SLOT))


func _emit_and_play(target: Signal) -> void:
	Sfx.play(&"select")
	target.emit()


func _on_options() -> void:
	Sfx.play(&"select")
	if _options_panel != null:
		return
	_options_panel = load(OPTIONS_SCENE).instantiate()
	add_child(_options_panel)
	_options_panel.closed.connect(_on_options_closed)


func _on_options_closed() -> void:
	if is_instance_valid(_options_panel):
		_options_panel.queue_free()
	_options_panel = null
	_options.grab_focus()


func _key_hint(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if _options_panel != null:
			_options_panel.close()
		else:
			_emit_and_play(resume_requested)
		get_viewport().set_input_as_handled()