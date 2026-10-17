class_name ItemLibrary
extends RefCounted
## Catálogo de itens, escrito em código.
##
## Nascem aqui e não em `.tres` por uma escolha do projeto: zero assets no
## repositório, e um item são doze linhas de dado. Quando vier arte de verdade,
## cada entrada ganha `icon` e o resto do jogo não muda — ele sempre pede o
## item pelo `id`.
##
##     ItemLibrary.definition(&"potion").display_name  -> "Pocao"

static var _items: Dictionary = {}
static var _ready := false


static func _build() -> void:
	if _ready:
		return
	_ready = true

	_add(&"potion", func(d: ItemDefinition) -> void:
		d.display_name = "Pocao"
		d.tint = Color(0.929, 0.325, 0.361)
		d.value = 50
		d.effect = ItemDefinition.Effect.HEAL
		d.heal_amount = 30
	)

	_add(&"coin_pouch", func(d: ItemDefinition) -> void:
		d.display_name = "Bolsa de moedas"
		d.tint = Color(0.976, 0.831, 0.376)
		d.value = 100
		d.effect = ItemDefinition.Effect.POINTS
	)

	_add(&"feather", func(d: ItemDefinition) -> void:
		d.display_name = "Pena"
		d.tint = Color(0.784, 0.867, 0.941)
		d.value = 0
	)
	_add(&"bomb", func(d: ItemDefinition) -> void:
		d.display_name = "Bomba"
		d.tint = Color(1.0, 0.6, 0.2)
		d.value = 0
		d.effect = ItemDefinition.Effect.BOMB
	)

	_add(&"shield", func(d: ItemDefinition) -> void:
		d.display_name = "Escudo"
		d.tint = Color(0.4, 0.8, 1.0)
		d.value = 0
		d.effect = ItemDefinition.Effect.SHIELD
	)

	_add(&"magnet", func(d: ItemDefinition) -> void:
		d.display_name = "Ima"
		d.tint = Color(0.9, 0.4, 0.9)
		d.value = 0
		d.effect = ItemDefinition.Effect.MAGNET
	)


static func _add(id: StringName, fill: Callable) -> void:
	var item := ItemDefinition.new()
	fill.call(item)
	# O `id` é preenchido depois do resto: `new()` nasce com tudo zerado.
	item.id = id
	if not item.is_valid():
		if not quiet_invalid:
			push_error("ItemLibrary: item invalido -> %s" % id)
		return
	_items[id] = item


## Mesma ideia do [Settings.quiet_rejections]: um item invalido e um erro de
## conteudo que merece aviso, mas o runner de testes instancia o item duas
## vezes e nao pode transformar isso em ruido.
static var quiet_invalid := false


## Item pelo id, ou `null`. Devolve `null` em vez de inventar um item: um id
## desconhecido é bug de conteúdo, e encher o save com lixo esconde isso.
static func definition(id: StringName) -> ItemDefinition:
	_build()
	return _items.get(id)


static func has(id: StringName) -> bool:
	_build()
	return _items.has(id)


## Todos os ids, em ordem de criação. Serve para a HUD e para os testes.
static func all_ids() -> Array[StringName]:
	_build()
	var out: Array[StringName] = []
	for id: StringName in _items:
		out.append(id)
	return out


## Só para teste.
static func clear() -> void:
	_items.clear()
	_ready = false