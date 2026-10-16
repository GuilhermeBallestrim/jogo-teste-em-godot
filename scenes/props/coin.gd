class_name Coin
extends Area2D
## Coletavel. Ao ser pego, credita moedas e pontos no [GameState].

signal collected(value: int)

@export var value: int = 1

var _phase := 0.0

@onready var _coin: Polygon2D = $Coin


func _ready() -> void:
	collision_layer = Layers.INTERACTABLE
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)
	# Fase aleatoria para que varias moedas nao fiquem perfectly sincronizadas.
	_phase = float(get_instance_id() % 100) * 0.037


func _process(delta: float) -> void:
	_phase += delta
	_coin.rotation = sin(_phase * 1.5) * 0.5
	_coin.position.y = sin(_phase * 2.6) * 4.0


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	GameState.add_coins(value)
	GameState.add_score(100 * value)
	Sfx.play(&"coin", -5.0)
	collected.emit(value)
	queue_free()