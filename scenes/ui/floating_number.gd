class_name FloatingNumber
extends Node2D
## Número de dano que sobe e some.
##
## É o feedback mais direto que existe: o jogador vê o número do golpe que
## acertou, e a cor diz de quem foi. Sem ele, um acerto de 1 dano numa briga
## com três inimigos é indistinguível de um acerto no ar.
##
## Nasce em coordenadas de mundo e não dentro da HUD: um número preso no
## canto da tela não diz *onde* o golpe pegou.

@export var amount: int = 1
@export var tint := Color(1.0, 0.94, 0.62)
## Para onde o número sobe. Vertical, porque a câmera antecipada faz a
## horizontal ser lida como "o número andou junto".
@export var rise := 46.0
@export var duration := 0.7
## Numeração aleatória dentro de um intervalo, para acerto variável.
@export var random_range_amount := 0

@onready var _label: Label = $Label


## Só a aparência. A animação fica em [method place], e a separação não é
## capricho: o alvo do tween depende da posição, e a posição só está correta
## depois que quem chamou atribuiu. Montar os dois em `_ready` media o alvo a
## partir de (0,0), e o número subia a partir do canto da tela em vez do ponto
## do golpe — que é justamente o que ele precisa dizer.
func _ready() -> void:
	z_index = 40
	var text := str(amount)
	if random_range_amount > 0:
		text = "%d-%d" % [amount, amount + random_range_amount]

	_label.text = text
	_label.add_theme_color_override(&"font_color", tint)
	# Contorno grosso: o número precisa sobreviver ao cenário escuro atrás dele.
	_label.add_theme_color_override(&"font_outline_color", Color(0.04, 0.05, 0.08, 0.95))
	_label.add_theme_constant_override(&"outline_size", 8)
	# 30 px, nao 22. O bone tem 56 px de altura e o numero tem de ser legivel
	# na mesma escala: a 22 ele era um detalinho. A captura da onda 1 mediu
	# 7 px de um "1" na tela -- pouco ate para um numero de um digito so.
	_label.add_theme_font_size_override(&"font_size", 30)
	_label.pivot_offset = _label.size * 0.5


## Posiciona e anima. [method spawn] chama logo depois de `add_child`, e só
## então `global_position` existe.
func place(world_position: Vector2) -> void:
	global_position = world_position

	# Um número que sai sempre igual lê como interface. O desvio horizontal e
	# a escala de entrada fazem o acerto parecer um evento.
	var drift := randf_range(-14.0, 14.0)
	_label.scale = Vector2(0.6, 0.6)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", position + Vector2(drift, -rise), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a", 0.0, duration * 0.55).set_delay(duration * 0.45)
	tween.chain().tween_callback(queue_free)


## Cria o número em `world_position` e o pendura na cena.
##
## ## Por que um método de fábrica, e não `preload(...).instantiate()` no chamador
##
## `global_position` só existe depois que o nó entrou na árvore. Se o chamador
## montar o número e posicionar em seguida, a posição depende de quando o
## `add_child` rodou — e a classe inteira de bugs de "o número apareceu no
## lugar errado" vem daí. Aqui os dois passos são atômicos.
##
## ## Por que o pai é a cena corrente, e não o corpo que levou o dano
##
## Um inimigo morre no mesmo quadro em que leva o golpe final. Se o número
## ficasse filho dele, o `queue_free` da cena de morte (0.45 s depois) levaria
## o número junto e o jogador nunca veria o dano que Matou o inimigo.
##
## Devolve `null` quando não há onde pendurar — um teste que monta um corpo
## fora da árvore corrente não deve derrubar a suíte por causa de um número
## que é decorativo.
static func spawn(parent: Node, world_position: Vector2, amount: int, tint: Color) -> FloatingNumber:
	if parent == null or not parent.is_inside_tree():
		return null
	var layer: Node = parent.get_tree().current_scene
	if layer == null:
		layer = parent
	var scene := load("res://scenes/ui/floating_number.tscn") as PackedScene
	if scene == null:
		push_error("FloatingNumber: cena nao carregou")
		return null
	var node := scene.instantiate() as FloatingNumber
	if node == null:
		return null
	node.amount = amount
	node.tint = tint
	layer.add_child(node)
	node.place(world_position)
	return node
