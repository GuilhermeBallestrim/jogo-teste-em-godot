extends Node
## Estado global da sessao de jogo.
## Registrado como autoload com o nome `GameState`.

signal health_changed(current: int, maximum: int)
signal coins_changed(amount: int)
signal score_changed(amount: int)
signal flag_changed(key: StringName, value: Variant)
## Emitido sempre que a contagem de um item muda. `count` e o total depois da
## mudanca, para a HUD poder atualizar sem consultar o dicionario.
signal item_changed(id: StringName, count: int)

var max_health: int = 100
var health: int = 100
var coins: int = 0
var score: int = 0

var _flags: Dictionary = {}
## item id -> quantidade. Um dicionario e nao um array porque "ter 3 pocas" e
## uma pergunta que se responde em O(1) e que o save precisa restaurar sem
## deduplicar.
var _items: Dictionary = {}
## Habilidades desbloqueadas (ids).
var _abilities: Array[StringName] = []
## Niveis completados.
var _completed_levels: Array[StringName] = []


func _ready() -> void:
	reset()


## Zera todo o estado (chamado no inicio de uma partida nova).
func reset() -> void:
	health = max_health
	coins = 0
	score = 0
	_flags.clear()
	_items.clear()


	_notify_all()


## Limpa o progresso (habilidades, niveis completados). Usado em "novo jogo".
func reset_progress() -> void:
	_abilities.clear()
	_completed_levels.clear()


## Carrega o progresso do Save ativo, sem tocar no estado de sessao.
func load_progress() -> void:
	var slot := Save.active_slot
	if not Save.has_save(slot):
		return
	var data := Save._read_payload(Save._path_for(slot))
	if data.is_empty():
		return
	var saved_abilities: Variant = data.get("abilities", [])
	if saved_abilities is Array:
		_abilities = []
		for a in saved_abilities:
			var aid := StringName(String(a))
			if AbilityLibrary.has(aid) and not _abilities.has(aid):
				_abilities.append(aid)
	var saved_levels: Variant = data.get("completed_levels", [])
	if saved_levels is Array:
		_completed_levels = []
		for lv in saved_levels:
			var lid := StringName(String(lv))
			if not _completed_levels.has(lid):
				_completed_levels.append(lid)



func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)


func heal(amount: int) -> void:
	if amount <= 0:
		return
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


## Guarda uma flag booleana/valor arbitrario usada para comportamento de script.
func set_flag(key: StringName, value: Variant) -> void:
	_flags[StringName(key)] = value
	flag_changed.emit(StringName(key), value)


func get_flag(key: StringName, default_value: Variant = false) -> Variant:
	return _flags.get(StringName(key), default_value)


# ------------------------------------------------------------- inventario


## Coleta. Devolve quantas unidades foram realmente aceitas: um id desconhecido
## ou uma quantidade invalida devolvem 0, e quem chamou tem como reagir sem
## precisar checar antes.
func add_item(id: StringName, amount: int = 1) -> int:
	if not ItemLibrary.has(id) or amount <= 0:
		return 0
	var total: int = mini(99, item_count(id) + amount)
	_items[id] = total
	item_changed.emit(id, total)
	return amount


func remove_item(id: StringName, amount: int = 1) -> int:
	var have := item_count(id)
	if have <= 0 or amount <= 0:
		return 0
	var left: int = maxi(0, have - amount)
	if left == 0:
		_items.erase(id)
	else:
		_items[id] = left
	item_changed.emit(id, left)
	return mini(have, amount)


func item_count(id: StringName) -> int:
	return int(_items.get(id, 0))


func has_item(id: StringName, amount: int = 1) -> bool:
	return item_count(id) >= amount


## O primeiro item com efeito, na ordem do catalogo. E o que a tecla de uso
## consome: o jogador nao precisa de um menu de inventario para uma fase com
## um item so, e o menu ainda nao existe.
func first_usable_id() -> StringName:
	for id: StringName in ItemLibrary.all_ids():
		if item_count(id) > 0:
			var item := ItemLibrary.definition(id)
			if item != null and item.has_use():
				return id
	return &""


## Usa um item. Devolve `false` (e nao gasta nada) quando nao ha, quando o
## item nao tem efeito, ou quando o efeito seria no-op -- full de vida com
## pocao nao deve custar a pocao ao jogador.
func use_item(id: StringName, player: Node = null) -> bool:
	var item := ItemLibrary.definition(id)
	if item == null or not item.has_use() or not has_item(id):
		return false
	if item.effect == ItemDefinition.Effect.HEAL and health >= max_health:
		return false

	remove_item(id, 1)
	item.apply(self, player)
	return true


func is_alive() -> bool:
	return health > 0


# ------------------------------------------------------------- habilidades


## Desbloqueia uma habilidade. Devolve false se ja tinha ou se nao existe.
func unlock_ability(id: StringName) -> bool:
	if not AbilityLibrary.has(id) or has_ability(id):
		return false
	_abilities.append(id)
	return true


func has_ability(id: StringName) -> bool:
	return _abilities.has(id)


func all_abilities() -> Array[StringName]:
	return _abilities.duplicate()


func complete_level(id: StringName) -> void:
	if not _completed_levels.has(id):
		_completed_levels.append(id)


func is_level_completed(id: StringName) -> bool:
	return _completed_levels.has(id)


func is_level_unlocked(id: StringName) -> bool:
	if id == &"level_01":
		return true
	var prev := _previous_level(id)
	if prev == &"":
		return true
	return is_level_completed(prev)


func _previous_level(id: StringName) -> StringName:
	var s := String(id)
	if not s.begins_with("level_"):
		return &""
	var num_str := s.substr(6)
	if not num_str.is_valid_int():
		return &""
	var n := int(num_str)
	if n <= 1:
		return &""
	return StringName("level_%02d" % (n - 1))


# ------------------------------------------------------------- save


func to_dict() -> Dictionary:
	return {
		"max_health": max_health,
		"health": health,
		"coins": coins,
		"score": score,
		"flags": _flags.duplicate(true),
		"items": _items.duplicate(),
		"abilities": _abilities.duplicate(),
		"completed_levels": _completed_levels.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	max_health = maxi(1, int(data.get("max_health", 100)))
	health = clampi(int(data.get("health", max_health)), 0, max_health)
	coins = maxi(0, int(data.get("coins", 0)))
	score = maxi(0, int(data.get("score", 0)))
	_flags = (data.get("flags", {}) as Dictionary).duplicate(true)

	# Item desconhecido e salvo e bug de conteudo (versao antiga do jogo, item
	# removido). Descartar e certo; adivinhar seria pior.
	_items = {}
	var saved: Variant = data.get("items", {})
	if saved is Dictionary:
		for key: Variant in saved:
			var id := StringName(String(key))
			if not ItemLibrary.has(id):
				continue
			_items[id] = clampi(int(saved[key]), 0, 99)

	# Habilidades: so aceita as que existem no catalogo.
	_abilities = []
	var saved_abilities: Variant = data.get("abilities", [])
	if saved_abilities is Array:
		for a in saved_abilities:
			var aid := StringName(String(a))
			if AbilityLibrary.has(aid) and not _abilities.has(aid):
				_abilities.append(aid)

	# Niveis completados.
	_completed_levels = []
	var saved_levels: Variant = data.get("completed_levels", [])
	if saved_levels is Array:
		for lv in saved_levels:
			var lid := StringName(String(lv))
			if not _completed_levels.has(lid):
				_completed_levels.append(lid)

	_notify_all()


func _notify_all() -> void:
	health_changed.emit(health, max_health)
	coins_changed.emit(coins)
	score_changed.emit(score)
	for id: Variant in _items:
		item_changed.emit(StringName(id), int(_items[id]))