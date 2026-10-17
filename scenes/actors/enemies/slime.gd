extends Enemy
## Slime: mesmo FSM do [Enemy], mas se locomovem pulando em vez de andar.
##
## As unicas diferencas sao o override de [method _apply_vertical] (pula em
## vez de andar) e o amortecimento visual do pouso.

## Impulso do salto. Sem gravidade reduzida no apice (o slime nao tem
## APEX_GRAVITY_SCALE), -300 contra 980 da ~46 px -- quase a propria altura do
## corpo. Suficiente para parecer saltitante sem virar pulo do jogador.
@export var hop_power := -300.0
## Intervalo entre saltinhos. Maior que o do jogador para o ritmo nao
## confunda com o pulo do player.
@export var hop_cooldown := 0.85

var _hop_timer := 0.0


func _apply_vertical(delta: float) -> void:
	super._apply_vertical(delta)

	_hop_timer = maxf(_hop_timer - delta, 0.0)
	# So pula quando tem para onde ir (andando ou perseguindo)...
	if not (is_on_floor() and _hop_timer <= 0.0 and absf(velocity.x) > 10.0):
		return
	# ...e quando ha chao do outro lado. Sem esta linha o slime pula da
	# beirada e cai no KillZone -- era o bug mais visivel da fase 1.
	if not has_ground_ahead(signf(velocity.x)):
		# Preso na beirada: espera um pouco e tenta o outro lado, para nao
		# ficar parado para sempre de um lado so.
		_hop_timer = 0.25
		velocity.x = -signf(velocity.x) * patrol_speed
		return

	velocity.y = hop_power
	_hop_timer = hop_cooldown


func _on_landed() -> void:
	_sprite.scale = Vector2(1.25, 0.72)
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)