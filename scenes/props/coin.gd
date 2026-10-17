class_name Coin
extends Area2D
## Coletável. Ao ser pego, credita moedas e pontos no [GameState].
##
## [member value] é o que permite balanceamento sem esticar o número de
## objetos na fase: uma moeda cara vale 2 (ou 5) para o objetivo, e o
## [LevelBase] soma os valores em vez de contar nos. O visual acompanha a
## cor para que o jogador saiba o que pegou sem precisar ler o número.

signal collected(value: int)

## Quanto o objetivo da fase ganha com esta moeda. Também multiplica a
## pontuação.
@export var value: int = 1
## Cor do corpo e do brilho. Amarelo e o padrao (valor 1).
@export var tint := Color(0.976, 0.776, 0.251)

var _phase := 0.0

@onready var _coin: Polygon2D = $Coin
@onready var _glow: Polygon2D = $Glow


func _ready() -> void:
	add_to_group(&"coins")
	collision_layer = Layers.INTERACTABLE
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)
	# Fase aleatória para que várias moedas não fiquem perfeitamente
	# sincronizadas -- todas nasceriam no mesmo ângulo.
	_phase = float(get_instance_id() % 100) * 0.037

	_coin.color = tint
	_glow.color = Color(tint, 0.13)


func _process(delta: float) -> void:
	_phase += delta
	_coin.rotation = sin(_phase * 1.5) * 0.5
	_coin.position.y = sin(_phase * 2.6) * 4.0


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	GameState.add_coins(value)
	GameState.add_score(100 * value)
	# Moeda cara soa mais alto: dá para o ouvido dizer que pegou algo melhor.
	Sfx.play(&"coin", -5.0 + minf(float(value - 1) * 3.0, 6.0))
	ParticlePreset.spawn_coin_burst(get_tree().current_scene, global_position)
	collected.emit(value)
	queue_free()