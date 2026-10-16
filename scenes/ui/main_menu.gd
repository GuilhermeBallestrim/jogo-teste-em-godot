class_name MainMenu
extends Control
## Menu principal -- ponto de entrada do jogo (cena principal do projeto).

const LEVEL_SCENE := "res://scenes/levels/level_01.tscn"
const OPTIONS_SCENE := "res://scenes/ui/options_panel.tscn"

@onready var _play: Button = %PlayButton
@onready var _continue: Button = %ContinueButton
@onready var _options: Button = %OptionsButton
@onready var _quit: Button = %QuitButton
@onready var _version: Label = %VersionLabel
@onready var _save_hint: Label = %SaveHintLabel

var _options_panel: OptionsPanel = null


func _ready() -> void:
	_play.pressed.connect(_on_play)
	_continue.pressed.connect(_on_continue)
	_options.pressed.connect(_on_options)
	_quit.pressed.connect(_on_quit)

	_quit.visible = not OS.has_feature("web")
	_refresh_save_state()
	_version.text = "Godot %s" % Engine.get_version_info()["string"]

	_play.grab_focus()
	Music.play()


func _refresh_save_state() -> void:
	var has_save := Save.has_save()
	_continue.disabled = not has_save
	_save_hint.visible = has_save
	_save_hint.text = "Progresso salvo encontrado" if has_save else ""


func _on_play() -> void:
	Sfx.play(&"select")
	GameState.reset()
	SceneRouter.goto(LEVEL_SCENE, &"level_01")


func _on_continue() -> void:
	Sfx.play(&"select")
	if not Save.load_game():
		_refresh_save_state()
		return
	# Retoma a cena que estava em jogo; cai na fase 1 se o save for antigo.
	SceneRouter.goto(Save.last_scene_path(), &"level_01")


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


func _on_quit() -> void:
	Sfx.play(&"back")
	SceneRouter.quit_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _options_panel != null and event.is_action_pressed(&"pause"):
		_options_panel.close()
		get_viewport().set_input_as_handled()