extends Node
## Persistencia do progresso em `user://saves/<slot>.json`.
## Registrado como autoload com o nome `Save`.

signal save_written(slot: StringName)
signal save_loaded(slot: StringName)
signal save_erased(slot: StringName)
signal save_failed(slot: StringName, reason: String)

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 2
const DEFAULT_SLOT := &"main"

## Slot ativo. O jogo inteiro (save, load, peek) usa este slot por padrao.
## O menu troca o slot ativo quando o jogador escolhe outro.
var active_slot: StringName = DEFAULT_SLOT

func set_active_slot(slot: StringName) -> void:
	if slot == &"":
		slot = DEFAULT_SLOT
	active_slot = slot

## Preenchido por [method load_game] com o path da cena salvo.
var _last_scene_path: String = ""
## Id da fase carregada, resolvido pelo [LevelRegistry].
var _last_level_id: StringName = &""
## True quando a fase salva nao existe mais e caimos na padrao.
var _last_scene_missing := false


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func save_game(slot: StringName = active_slot) -> bool:
	var path := _path_for(slot)
	var current := get_tree().current_scene
	var scene_path := current.scene_file_path if current != null else ""
	var level_id := LevelRegistry.id_for_path(scene_path)

	# Sem id resolvido (cena nao registrada), usamos o que o SceneRouter sabe
	# -- e se nem isso existir, caimos no path para o save nao ficar orfao.
	if level_id == &"":
		level_id = SceneRouter.current_scene_id

	var payload := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		# `scene_id` e estavel (sovera renomear o arquivo); `scene_path` e a
		# rede de seguranca para saves antigos.
		"scene_id": String(level_id),
		"scene_path": scene_path,
		"game_state": GameState.to_dict(),
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var reason := "Nao foi possivel abrir '%s' para escrita (erro %d)." % [path, FileAccess.get_open_error()]
		push_error("Save: " + reason)
		save_failed.emit(slot, reason)
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	save_written.emit(slot)
	return true


func load_game(slot: StringName = active_slot) -> bool:
	var path := _path_for(slot)
	if not FileAccess.file_exists(path):
		save_failed.emit(slot, "Nenhum save encontrado em '%s'." % path)
		return false

	var data := _read_payload(path)
	if data.is_empty():
		save_failed.emit(slot, "Save corrompido ou vazio em '%s'." % path)
		return false
	var version := int(data.get("version", 0))
	# Versao 1 (pre-registro) so tinha `scene_path` e ainda e valido: o id
	# e deduzido pelo caminho. Acima da atual, o formato mudou demais.
	if version < 1 or version > SAVE_VERSION:
		save_failed.emit(slot, "Versao de save incompativel (%d, esperava ate %d)." % [version, SAVE_VERSION])
		return false

	GameState.from_dict(data.get("game_state", {}))

	# Resolve a cena por id (estavel) e cai para o path (save antigo) e depois
	# para a fase padrao. Nunca devolver um caminho morto: o SceneRouter
	# tentaria abrir e falharia.
	_last_scene_path = ""
	_last_level_id = &""
	_last_scene_missing = false

	var saved_id := StringName(String(data.get("scene_id", "")))
	var by_id := LevelRegistry.path_for(saved_id) if saved_id != &"" else ""

	if by_id != "" and ResourceLoader.exists(by_id):
		_last_scene_path = by_id
		_last_level_id = saved_id
	else:
		# Save de antes do registro (so tinha path), ou fase desconhecida.
		var by_path := String(data.get("scene_path", ""))
		if by_path != "" and ResourceLoader.exists(by_path):
			_last_scene_path = by_path
			_last_level_id = LevelRegistry.id_for_path(by_path)
		elif saved_id != &"" or by_path != "":
			# A cena do save nao existe mais.
			_last_scene_missing = true
			_last_scene_path = LevelRegistry.default_path()
			_last_level_id = LevelRegistry.default_id()

	save_loaded.emit(slot)
	return true


func has_save(slot: StringName = active_slot) -> bool:
	return FileAccess.file_exists(_path_for(slot))


## Le o JSON de um slot sem aplicar nada. Vazio quando nao ha arquivo, o
## arquivo esta corrompido ou o JSON nao parseia.
##
## Usa [method JSON.parse] em vez de [method JSON.parse_string] de proposito:
## `parse_string` imprime "Parse JSON failed" no console sempre que falha, e
## um save corrompido e um caso que o jogador pode encontrar -- nao queremos
## poluir o log com isso a cada leitura.
func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("Save: '%s' nao e JSON valido (%s)." % [path, json.get_error_message()])
		return {}

	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


## Id da fase gravada, **sem** aplicar o save.
##
## O menu precisa saber onde o jogador parou só para escrever um "(continuar)"
## no botão certo, e não vale a pena carregar o `GameState` inteiro para isso.
## Leitura crua do arquivo de propósito: quem conhece o formato é o `Save`,
## não a UI.
func peek_level_id(slot: StringName = active_slot) -> StringName:
	var data := _read_payload(_path_for(slot))
	if data.is_empty():
		return &""

	var id := StringName(String(data.get("scene_id", "")))
	if id != &"" and LevelRegistry.has(id):
		return id
	# Save antigo: sem id, mas com caminho ainda vivo.
	return LevelRegistry.id_for_path(String(data.get("scene_path", "")))


func erase_save(slot: StringName = active_slot) -> bool:
	if not has_save(slot):
		return false
	if DirAccess.remove_absolute(_path_for(slot)) != OK:
		push_error("Save: falha ao remover '%s'." % _path_for(slot))
		return false
	save_erased.emit(slot)
	return true


## Caminho da cena do ultimo save carregado. Vazio se ainda nao houve leitura.
func last_scene_path() -> String:
	return _last_scene_path


## Id da fase do ultimo save, resolvido pelo [LevelRegistry].
func last_level_id() -> StringName:
	return _last_level_id


## True quando o save apontava para uma cena que nao existe mais e o menu
## caiu na fase padrao. A UI usa isso para avisar em vez de fingir que
## retomou o progresso.
func last_scene_missing() -> bool:
	return _last_scene_missing


func list_slots() -> PackedStringArray:
	var slots := PackedStringArray()
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return slots
	for file_name in DirAccess.get_files_at(SAVE_DIR):
		if file_name.ends_with(".json"):
			slots.append(file_name.trim_suffix(".json"))
	slots.sort()
	return slots


func _path_for(slot: StringName) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]
