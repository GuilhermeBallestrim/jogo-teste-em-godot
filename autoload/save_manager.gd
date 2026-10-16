extends Node
## Persistencia do progresso em `user://saves/<slot>.json`.
## Registrado como autoload com o nome `Save`.

signal save_written(slot: StringName)
signal save_loaded(slot: StringName)
signal save_erased(slot: StringName)
signal save_failed(slot: StringName, reason: String)

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1
const DEFAULT_SLOT := &"main"

## Preenchido por [method load_game] com o path da cena salvo.
var _last_scene_path: String = ""


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func save_game(slot: StringName = DEFAULT_SLOT) -> bool:
	var path := _path_for(slot)
	var current := get_tree().current_scene
	var payload := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		# Guardamos o path e o id para o menu saber o que retomar.
		"scene_path": current.scene_file_path if current != null else "",
		"scene_id": String(SceneRouter.current_scene_id),
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


func load_game(slot: StringName = DEFAULT_SLOT) -> bool:
	var path := _path_for(slot)
	if not FileAccess.file_exists(path):
		save_failed.emit(slot, "Nenhum save encontrado em '%s'." % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var reason := "Nao foi possivel abrir '%s' para leitura (erro %d)." % [path, FileAccess.get_open_error()]
		push_error("Save: " + reason)
		save_failed.emit(slot, reason)
		return false

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		save_failed.emit(slot, "Save corrompido: JSON invalido.")
		return false

	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		save_failed.emit(slot, "Versao de save incompativel (esperada %d)." % SAVE_VERSION)
		return false

	GameState.from_dict(data.get("game_state", {}))

	# Se a cena salva nao existir mais (fase removida, save antigo), limpa o
	# caminho para o menu cair no padrao em vez de tentar abrir arquivo morto.
	var scene_path := String(data.get("scene_path", ""))
	_last_scene_path = scene_path if ResourceLoader.exists(scene_path) else ""

	save_loaded.emit(slot)
	return true


func has_save(slot: StringName = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(_path_for(slot))


func erase_save(slot: StringName = DEFAULT_SLOT) -> bool:
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