class_name HUD
extends CanvasLayer
## HUD do prototipo. Escuta os sinais do `GameState`, entao nao conhece a
## origem dos dados -- so reage as mudancas.

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _item_strip: HBoxContainer = %ItemStrip

var _coin_goal: int = 0
## item id -> icone desenhado na tira.
var _item_icons := {}


func _ready() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.score_changed.connect(_on_score_changed)
	GameState.item_changed.connect(_on_item_changed)

	_refresh_health(GameState.health, GameState.max_health)
	_on_coins_changed(GameState.coins)
	_on_score_changed(GameState.score)
	_refresh_items()


## Se `goal` for maior que zero, o HUD mostra "Moedas 3/10".
func set_coin_goal(goal: int) -> void:
	_coin_goal = maxi(0, goal)
	_on_coins_changed(GameState.coins)


func _on_health_changed(current: int, maximum: int) -> void:
	_refresh_health(current, maximum)


func _refresh_health(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "Vida %d/%d" % [current, maximum]


func _on_coins_changed(amount: int) -> void:
	if _coin_goal > 0:
		_coins_label.text = "Moedas %d/%d" % [amount, _coin_goal]
	else:
		_coins_label.text = "Moedas %d" % amount


func _on_score_changed(amount: int) -> void:
	_score_label.text = "Pontos %d" % amount


func _on_item_changed(id: StringName, _count: int) -> void:
	_refresh_item(id)


## Tira de inventário. Um ícone por item possuído, com a contagem em cima.
##
## O ícone é um `Polygon2D` desenhado aqui em vez de uma textura: o projeto
## não tem arte, e a forma já comunica o item (frasco, bolsa, pena). Quando
## vier `ItemDefinition.icon`, é trocar a linha de criação.
func _refresh_items() -> void:
	for child in _item_strip.get_children():
		child.queue_free()
	_item_icons.clear()

	for id: StringName in ItemLibrary.all_ids():
		if GameState.item_count(id) <= 0:
			continue
		_item_strip.add_child(_make_item_slot(id))

	# A tira so ocupa espaco quando ha algo para mostrar.
	_item_strip.visible = not _item_strip.get_children().is_empty()


func _refresh_item(id: StringName) -> void:
	if GameState.item_count(id) <= 0:
		var icon: Node = _item_icons.get(id)
		if icon != null and is_instance_valid(icon):
			icon.queue_free()
			_item_icons.erase(id)
		_item_strip.visible = not _item_strip.get_children().is_empty()
		return
	if _item_icons.has(id):
		var label := (_item_icons[id] as Control).get_node_or_null(^"Count") as Label
		if label != null:
			label.text = "x%d" % GameState.item_count(id)
		return
	_item_strip.add_child(_make_item_slot(id))
	_item_strip.visible = true


func _make_item_slot(id: StringName) -> Control:
	var item := ItemLibrary.definition(id)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(38, 38)

	var icon := Polygon2D.new()
	icon.polygon = PackedVector2Array([
		Vector2(0, -14), Vector2(10, -7), Vector2(10, 7),
		Vector2(0, 14), Vector2(-10, 7), Vector2(-10, -7),
	])
	icon.color = item.tint if item != null else Color.WHITE
	slot.add_child(icon)

	var label := Label.new()
	label.name = "Count"
	label.text = "x%d" % GameState.item_count(id)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(-14, 20)
	slot.add_child(label)

	# Dica com nome e efeito: o jogador precisa saber o que `E` faz antes de
	# apertar, e há lugar para duas palavras.
	var hint := Label.new()
	hint.text = item.display_name if item != null else String(id)
	if item != null and item.has_use():
		hint.text += "  (%s)" % item.effect_hint()
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hint.add_theme_constant_override("outline_size", 4)
	hint.position = Vector2(44, 10)
	slot.add_child(hint)

	_item_icons[id] = slot
	return slot