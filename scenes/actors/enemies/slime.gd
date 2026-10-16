extends Enemy
## Slime: mesmo FSM do [Enemy], mas se locomovem pulando em vez de andar.
##
## As unicas diferencas sao o override de [method _apply_vertical] (pula em
## vez de andar) e o amortecimento visual do pouso.

@export var hop_power := -620.0
@export var hop_cooldown := 0.85

var _hop_timer := 0.0


func _apply_vertical(delta: float) -> void:
	super._apply_vertical(delta)

	_hop_timer = maxf(_hop_timer - delta, 0.0)
	# So pula quando tem para onde ir (andando ou perseguindo).
	if is_on_floor() and _hop_timer <= 0.0 and absf(velocity.x) > 10.0:
		velocity.y = hop_power
		_hop_timer = hop_cooldown


func _on_landed() -> void:
	_sprite.scale = Vector2(1.25, 0.72)
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)