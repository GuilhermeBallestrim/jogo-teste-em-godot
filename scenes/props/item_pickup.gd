class_name ItemPickup
extends Area2D
## Item no chão. Ao ser tocado pelo jogador, entra no inventário do
## [GameState] e some.
##
## Diferente do [Coin]: a moeda é pontuação de fase (a fase conta com elas),
## o item é possession que atravessa as fases e vai para o save. Por isso este
## não credita `coins` — quem faz isso é o item, no seu `value`.

signal picked_up(item: ItemPickup)

@export var item_id: StringName = &"potion"
## Quantas unidades cabem num único no do chão.
@export var amount := 1
## Some depois de alguns segundos. 0 = fica para sempre.
@export var lifetime := 0.0

var _phase := 0.0
var _gone := false

@onready var _icon: Polygon2D = $Icon
@onready var _glow: Polygon2D = $Glow


func _ready() -> void:
	add_to_group(&"pickups")
	collision_layer = Layers.INTERACTABLE
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)

	var item := ItemLibrary.definition(item_id)
	if item == null:
		# Item inexistente em cena: e conteudo quebrado, e o jogador nao pode
		# ficar com um no invisivel que nao faz nada.
		push_error("[%s] item desconhecido: %s" % [name, item_id])
		queue_free()
		return

	_icon.color = item.tint
	_glow.color = Color(item.tint, 0.14)
	# Fase por instancia: varios no mesmo ponto nao pulsariam juntos.
	_phase = float(get_instance_id() % 100) * 0.31

	if lifetime > 0.0:
		var tween := create_tween()
		tween.tween_interval(lifetime)
		tween.tween_callback(_despawn)


func _process(delta: float) -> void:
	if _gone:
		return
	_phase += delta
	_icon.position.y = sin(_phase * 2.4) * 3.5
	_glow.scale = Vector2.ONE * (1.0 + sin(_phase * 2.4) * 0.12)


func _on_body_entered(body: Node2D) -> void:
	if _gone or not body.is_in_group(&"player"):
		return
	var taken := GameState.add_item(item_id, amount)
	if taken <= 0:
		return
	Sfx.play(&"coin", -4.0)
	GameState.add_score(25 * taken)
	picked_up.emit(self)
	_despawn()


func _despawn() -> void:
	if _gone:
		return
	_gone = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_icon, "scale", Vector2(1.8, 1.8), 0.16)
	tween.tween_property(_glow, "scale", Vector2(2.2, 2.2), 0.16)
	tween.chain().tween_callback(queue_free)