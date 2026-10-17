extends Enemy
## Escudo: bloqueia golpes frontais.
##
## Um golpe pela frente nao tira vida e devolve um flash. So toma dano
## por tras ou por cima -- o jogador precisa contornar ou pular.

func _ready() -> void:
	body_color = Color(0.4, 0.55, 0.75)
	super._ready()
	# Corpo mais largo e baixo: leitura de "parede".
	body_size = Vector2(36, 28)
	if _shape.shape is RectangleShape2D:
		(_shape.shape as RectangleShape2D).size = body_size


func apply_damage(amount: int, source: Node, direction: Vector2, knockback: float) -> void:
	if state == State.DEAD:
		return
	# Frente bloqueada: o golpe nao entra.
	var from_front := direction.x * _facing > 0.0 if _facing != 0.0 else true
	if from_front and absf(direction.y) < 0.5:
		_flash()
		Sfx.play(&"back", -4.0)
		Hitstop.trigger(1)
		return
	super.apply_damage(amount, source, direction, knockback)