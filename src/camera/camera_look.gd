class_name CameraLook
extends Camera2D
## Câmera que olha um pouco à frente do movimento.
##
## A câmera atual gruda no player. Isso é fácil de notar em jogo: o
## personagem chega ao ponto do salto antes dele aparecer no centro da tela,
## e o jogador perde o "pulei e não vi".
##
## Este componente lê a velocidade do corpo e desloca a câmera na direção do
## movimento, com suavização em dois lugares:
##
## - **antecipação**: cresce com a velocidade, até um teto
## - **recuo ao parar**: a câmera volta mais rápido do que foi, senão ela
##   parece flutuar depois de cada corrida
##
## Fica como `Camera2D` separado do `player.gd` porque antecipação é
## apresentação, não regra de jogo: o player não deve saber que existe.
##
## Os `limit_*` continuam valendo sem código extra: o Godot os aplica *depois*
## do `offset`, então a antecipação é cortada pelas bordas sozinha.

## Onde o corpo observado está. Vazio = pai.
@export var target_path: NodePath = ^".."
## Desligar a antecipação sem desinstalar o componente.
@export var lookahead_enabled := true
## Antecipação máxima, em px. Acima de ~90 o personagem sai da zona de
## conforto visual e o jogador se perde.
@export var look_ahead := 74.0
## Velocidade em que a antecipação chega ao teto. O valor padrão é a
## `PlayerTuning.SPEED`: andando na máxima já antecipa o bastante.
@export var speed_reference := 340.0
## Suavização ao acelerar (por segundo). Maior = mais rápido.
@export var follow_speed := 6.0
## Suavização ao voltar ao centro. Maior que [member follow_speed] de propósito.
@export var recenter_speed := 9.0
## Multiplicador durante o dash: a câmera estica para o lado, porque o corpo
## some dentro do rastro.
@export var dash_boost := 1.5
## Zoom durante o dash, como fração. Pequeno de propósito: quem treme é o
## corpo, não a visão.
@export_range(0.0, 0.4) var dash_zoom := 0.06

var _target: Node2D = null
var _look := 0.0
var _zoom_base := Vector2.ONE


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D
	_zoom_base = zoom
	if _target == null:
		# Componente montado errado: avisa uma vez e fica parado, em vez de
		# repetir o mesmo aviso todo quadro.
		push_warning("[CameraLook] alvo invalido: %s" % target_path)


func _process(delta: float) -> void:
	if not lookahead_enabled or _target == null:
		return

	var velocity := _target_velocity()
	var speed := absf(velocity.x)

	# Anticipação cresce com a velocidade e respeita a direção do movimento.
	var reach := look_ahead * clampf(speed / maxf(speed_reference, 1.0), 0.0, 1.0)
	if _is_dashing():
		reach *= dash_boost
	var wanted := reach * signf(velocity.x)

	# Voltar ao centro é mais rápido que sair: senão a câmera "descola" ao
	# parar e o jogador demora a reencontrar o personagem.
	# O passo acompanha o deslocamento que esta EM CURSO, nao a distancia
	# ate o alvo. Com o corpo parado o alvo e zero, e um passo calculado a
	# partir dele daria um passo de meio pixel -- a camera levaria segundos
	# para voltar ao centro depois de cada corrida, que e exatamente o
	# defeito que o recenter existe para corrigir.
	var moving_out := absf(wanted) > absf(_look)
	var rate := follow_speed if moving_out else recenter_speed
	_look = move_toward(_look, wanted, maxf(absf(wanted), absf(_look)) * rate * delta)

	# Só o eixo X antecipa. No eixo Y a câmera ficaria pulando junto com o
	# salto, e é o corpo que deve subir na tela, não a visão.
	offset.x = _look
	_apply_zoom(delta)


## Zoom de leve durante o dash, voltando depois. Em Godot `zoom` menor = mais
## perto, então o dash multiplica por (1 - dash_zoom).
func _apply_zoom(delta: float) -> void:
	var wanted := Vector2.ONE * (1.0 - dash_zoom) if _is_dashing() else Vector2.ONE
	# Suavização geométrica: `zoom` é escala, e interpolar linearmente deixa o
	# passo visível na troca.
	var step := clampf(delta * 7.0, 0.0, 1.0)
	zoom = _zoom_base.lerp(wanted / _zoom_base, step)


func _is_dashing() -> bool:
	return _target != null and _target.has_method(&"is_dashing") and _target.is_dashing()


func _target_velocity() -> Vector2:
	var body := _target as CharacterBody2D
	if body != null:
		return body.velocity
	return Vector2.ZERO


## Quanto a câmera está antecipando agora, em px. Sinal = direção. Usado por
## teste: antecipação é difícil de ver num instantâneo, e comparar o valor
## é o que prova que a lógica responde à velocidade.
func look_offset() -> float:
	return _look
