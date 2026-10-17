extends Enemy
## Guarda: nao patrulha. Fica no posto e so persegue se o jogador entrar no
## raio de deteccao.
##
## O [Enemy] base persegue assim que ve o jogador. O guarda e o oposto: anda
## ate a borda do posto e volta, e so sai do lugar quando o jogador entra no
## raio. Quando o jogador sai do raio, volta para o posto em vez de perseguir
## ate o outro lado do mapa.

@export var guard_radius := 0.0

func _ready() -> void:
	body_color = Color(0.55, 0.62, 0.78)
	super._ready()
	# Detecta de longe, ataca de perto: e um guarda, nao um perseguidor.
	detect_range = 360.0
	forget_range = 520.0


func _patrol(delta: float) -> void:
	# Nao anda: guarda o posto. So age se o jogador entrar no raio.
	velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
	if _sees_target(detect_range):
		_set_state(State.CHASE)


func _chase(delta: float) -> void:
	if not _sees_target(forget_range):
		# O jogador saiu do raio: volta para o posto em vez de seguir.
		_set_state(State.PATROL)
		return
	var to_target := _target.global_position.x - global_position.x
	_facing = signf(to_target) if to_target != 0.0 else _facing
	velocity.x = move_toward(velocity.x, _facing * chase_speed, CHASE_ACCELERATION * delta)
	if absf(to_target) <= attack_range and _attack_cooldown <= 0.0:
		_set_state(State.AIM)