extends Enemy
## Escorre: anda rapido e nao freia na beirada.
##
## O [Enemy] base patrulha entre dois pontos e vira antes de cair. O escorre
## ignora isso: anda ate a borda e cai, e a rede de seguranca
## (`_guard_offscreen`) o traz de volta. Existe para exercitar o caminho de
## recuperacao, que antes so era acionado por knockback forte.
##
## Nao verifica `has_ground_ahead`: a queda e o ponto. Sem esta diferenca ele
## seria um slime sem pulo.

@export var crawl_speed := 150.0

func _ready() -> void:
	body_color = Color(0.72, 0.5, 0.28)
	super._ready()
	patrol_speed = crawl_speed
	chase_speed = crawl_speed * 1.3
	# Patrulha larga: o escorre anda ate a borda, nao ate um ponto no meio.
	patrol_left = -200.0
	patrol_right = 200.0


func _patrol(delta: float) -> void:
	# Anda em frente sem virar na beirada. O `_guard_offscreen` do base e quem
	# impede que ele suma para sempre.
	if _facing == 0.0:
		_facing = 1.0
	velocity.x = move_toward(velocity.x, _facing * patrol_speed, 700.0 * delta)
	# Vira ao bater na parede.
	if is_on_wall():
		_facing = -_facing
	if _sees_target(detect_range):
		_set_state(State.CHASE)


func _on_landed() -> void:
	# Achata no pouso: e um bicho que cai muito, e a leitura tem de ser de
	# impacto, nao de caminhada.
	_sprite.scale = Vector2(1.35, 0.6)
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)