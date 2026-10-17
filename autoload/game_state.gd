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


## O primeiro item com efeito, na ordem do catálogo. É o que a tecla de uso
## consome: o jogador não precisa de um menu de inventário para uma fase com
## um item só, e o menu ainda não existe.
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


func to_dict() -> Dictionary:
	return {
		"max_health": max_health,
		"health": health,
		"coins": coins,
		"score": score,
		"flags": _flags.duplicate(true),
		"items": _items.duplicate(),
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

	_notify_all()


func _notify_all() -> void:
	health_changed.emit(health, max_health)
	coins_changed.emit(coins)
	score_changed.emit(score)
	for id: Variant in _items:
		item_changed.emit(StringName(id), int(_items[id]))