class_name LevelRegistry
extends RefCounted
## Registro central das fases.
##
## Resolve o problema de salvar com mais de uma fase: o `Save` guarda um
## `scene_id` estável (que sobrevive a renomear o arquivo) e o menu precisa
## traduzir esse id de volta para uma cena. Concentrar o mapa aqui evita
## que o `Save` e o menu saibam das fases.
##
##     LevelRegistry.register(&"level_01", "res://scenes/levels/level_01.tscn")
##     LevelRegistry.path_for(&"level_01")  -> "res://scenes/levels/level_01.tscn"
##
## A primeira fase registrada e a que o menu usa quando nao ha save.

const DEFAULT_ID := &"level_01"

static var _by_id: Dictionary = {}
static var _order: Array[StringName] = []
static var _default_id: StringName = DEFAULT_ID


static func register(id: StringName, scene_path: String) -> void:
	if _by_id.has(id):
		# Ja registrado: mantem a ordem original, so atualiza o caminho.
		_by_id[id] = scene_path
		return
	_by_id[id] = scene_path
	_order.append(id)
	if _default_id == DEFAULT_ID and id != DEFAULT_ID:
		# A primeira fase a se declarar vira a padrao, a menos que ja exista.
		_default_id = id


static func path_for(id: StringName) -> String:
	return String(_by_id.get(id, ""))


static func id_for_path(scene_path: String) -> StringName:
	for id: StringName in _order:
		if _by_id[id] == scene_path:
			return id
	return &""


static func has(id: StringName) -> bool:
	return _by_id.has(id)


static func default_id() -> StringName:
	return _default_id


## Caminho de fallback quando o save aponta para uma cena que sumiu.
static func default_path() -> String:
	return path_for(_default_id)


static func all_ids() -> Array[StringName]:
	return _order.duplicate()


static func all_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _order:
		out.append(String(_by_id[id]))
	return out


## Só para teste: limpa o registro.
static func clear() -> void:
	_by_id.clear()
	_order.clear()
	_default_id = DEFAULT_ID