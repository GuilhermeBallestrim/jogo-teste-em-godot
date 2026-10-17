class_name MainMenu
extends Control
## Menu principal -- ponto de entrada do jogo (cena principal do projeto).

const OPTIONS_SCENE := "res://scenes/ui/options_panel.tscn"

## Rotulos das fases, na ordem em que aparecem no menu. O indice bate com
## a ordem de registro do [LevelRegistry].
const LEVEL_LABELS := {
	&"level_01": "1 - Corredores",
	&"level_02": "2 - Torres",
	&"level_04": "4 - Boss",
}

@onready var _play: Button = %PlayButton
@onready var _continue: Button = %ContinueButton
@onready var _options: Button = %OptionsButton
@onready var _quit: Button = %QuitButton
@onready var _version: Label = %VersionLabel
@onready var _save_hint: Label = %SaveHintLabel
@onready var _level_list: VBoxContainer = %LevelList

var _options_panel: OptionsPanel = null
var _level_buttons: Array[Button] = []
var _slot_list: VBoxContainer = null
var _slot_buttons: Array[Button] = []


func _ready() -> void:
	_play.pressed.connect(_on_play)
	_continue.pressed.connect(_on_continue)
	_options.pressed.connect(_on_options)
	_quit.pressed.connect(_on_quit)

	_quit.visible = not OS.has_feature("web")
	_refresh_save_state()
	_build_slot_list()
	_build_level_list()
	_version.text = "Godot %s" % Engine.get_version_info()["string"]

	_play.grab_focus()
	Music.play()


## Lista de slots de save. O jogador escolhe em qual slot jogar; o ativo
## fica marcado. "Novo slot" cria um com nome sequencial.
func _build_slot_list() -> void:
	if _slot_list == null:
		_slot_list = VBoxContainer.new()
		_slot_list.name = "SlotList"
		_level_list.get_parent().add_child(_slot_list)
		_level_list.get_parent().move_child(_slot_list, _level_list.get_index())

	for child in _slot_list.get_children():
		child.queue_free()
	_slot_buttons.clear()

	var slots := Save.list_slots()
	if slots.is_empty():
		slots = PackedStringArray(["main"])

	for slot_name in slots:
		var slot := StringName(slot_name)
		var is_active := slot == Save.active_slot
		var label := slot_name
		if is_active:
			label += "  (ativo)"
		if Save.has_save(slot):
			var id := Save.peek_level_id(slot)
			if id != &"":
				label += "  - %s" % id

		var row := HBoxContainer.new()
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(200, 0)
		button.pressed.connect(_on_slot_pressed.bind(slot))
		row.add_child(button)
		_slot_buttons.append(button)

		var erase := Button.new()
		erase.text = "x"
		erase.custom_minimum_size = Vector2(32, 0)
		erase.pressed.connect(_on_slot_erase.bind(slot))
		row.add_child(erase)

		_slot_list.add_child(row)

	var new_button := Button.new()
	new_button.text = "+ Novo slot"
	new_button.custom_minimum_size = Vector2(260, 0)
	new_button.pressed.connect(_on_new_slot)
	_slot_list.add_child(new_button)


func _on_slot_pressed(slot: StringName) -> void:
	Sfx.play(&"select")
	Save.set_active_slot(slot)
	_refresh_save_state()
	_build_level_list()
	_build_slot_list()


func _on_slot_erase(slot: StringName) -> void:
	Sfx.play(&"back")
	Save.erase_save(slot)
	if slot == Save.active_slot:
		Save.set_active_slot(&"main")
	_build_slot_list()
	_refresh_save_state()
	_build_level_list()


func _on_new_slot() -> void:
	Sfx.play(&"select")
	var n := Save.list_slots().size() + 1
	var name := "slot_%d" % n
	Save.set_active_slot(StringName(name))
	_build_slot_list()
	_refresh_save_state()
	_build_level_list()


## Monta um botao por fase registrada. Vem do [LevelRegistry] em vez de
## lista fixa aqui: adicionar uma fase e uma linha no SceneRouter.
##
## Nao ha trava de progresso ainda -- um slot por fase com "desbloqueada" so
## faz sentido quando existir save por slot (Fase 2.1). O que ja tem e o
## marcador de onde o jogador parou, que vem do save real.
func _build_level_list() -> void:
	for child in _level_list.get_children():
		child.queue_free()
	_level_buttons.clear()

	# `peek_level_id` devolve vazio quando o save aponta para uma fase que
	# sumiu -- e nesse caso nao ha "(continuar)" para marcar.
	var last_played := Save.peek_level_id()
	var resumed := Save.has_save() and last_played != &""

	for id: StringName in LevelRegistry.all_ids():
		if id == &"main_menu":
			continue
		var path := LevelRegistry.path_for(id)
		if path == "" or not ResourceLoader.exists(path):
			continue

		var label: String = LEVEL_LABELS.get(id, String(id))
		var unlocked := GameState.is_level_unlocked(id)
		if not unlocked:
			label = "%s  (bloqueada)" % label
		if resumed and id == last_played:
			label += "  (continuar)"

		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(260, 0)
		button.pressed.connect(_on_level_pressed.bind(id, path))
		button.disabled = not GameState.is_level_unlocked(id)
		_level_list.add_child(button)
		_level_buttons.append(button)

	# Com uma fase so nao ha o que escolher.
	_level_list.visible = _level_buttons.size() > 1


func _on_level_pressed(id: StringName, path: String) -> void:
	Sfx.play(&"select")
	GameState.reset()
	SceneRouter.goto(path, id)


func _refresh_save_state() -> void:
	var has_save := Save.has_save()
	_continue.disabled = not has_save
	_save_hint.visible = has_save
	_save_hint.add_theme_color_override("font_color", Color(0.50588, 0.72549, 0.94902))
	_save_hint.text = "Progresso salvo encontrado" if has_save else ""


func _on_play() -> void:
	Sfx.play(&"select")
	GameState.reset()
	# "Jogar" sempre vai para a primeira fase -- e o botao de inicio, nao um
	# atalho para a ultima jogada. Para escolher, use a lista abaixo.
	var first := LevelRegistry.default_id()
	SceneRouter.goto(LevelRegistry.path_for(first), first)


func _on_continue() -> void:
	Sfx.play(&"select")
	if not Save.load_game():
		_refresh_save_state()
		return

	# A cena do save pode ter sumido (fase removida, save antigo). O Save ja
	# cai na fase padrao nesse caso, mas avisamos em vez de fingir que
	# retomou o progresso.
	if Save.last_scene_missing():
		_save_hint.text = "Progresso salvo de uma fase que não existe mais"
		_save_hint.add_theme_color_override("font_color", Color(0.949, 0.361, 0.361))
		_save_hint.visible = true

	# Retoma a cena que estava em jogo.
	SceneRouter.goto(Save.last_scene_path(), Save.last_level_id())


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