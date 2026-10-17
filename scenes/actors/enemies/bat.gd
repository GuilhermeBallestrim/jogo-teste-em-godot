extends Enemy
## Morcego: voa em linha reta a uma altura constante, com onda senoidal.
##
## Este é o teste de extensibilidade do [Enemy]: tudo aqui são sobrescritas
## e ajustes de parâmetro -- nenhuma lógica de FSM foi reescrita.
##
## O que muda em relação ao slime:
## - `flies = true`: sem gravidade, com arrasto vertical
## - `_apply_vertical()`: substitui a gravidade por sustentação + onda
## - não sobrescreve `_on_landed()`, porque não tem chão

## Altura que o bicho procura manter acima do chão.
@export var hover_height := 120.0
## Amplitude da onda vertical, em px. Zero = voo reta.
@export var wave_amplitude := 14.0
## Frequência da onda, em radianos por segundo.
@export var wave_speed := 2.4
## Altura máxima de escalada: o bicho sobe junto com o alvo até este teto.
@export var ceiling_height := 260.0

var _wave_phase := 0.0


func _ready() -> void:
	super._ready()

	# Sem isso o motor cola o bicho na plataforma mais próxima.
	floor_snap_length = 0.0
	flies = true

	body_size = Vector2(30.0, 22.0)
	body_color = Color(0.482, 0.372, 0.639)
	detect_range = 340.0
	forget_range = 520.0
	attack_range = 54.0
	patrol_speed = 130.0
	chase_speed = 235.0
	max_health = 2
	contact_damage = 1

	# Fase diferente por indivíduo, para dois bateris não ficarem em sincronia.
	_wave_phase = float(get_instance_id() % 100) * 0.37


func _apply_vertical(delta: float) -> void:
	# `super` já aplicou o arrasto e zerado a gravidade.
	super._apply_vertical(delta)

	_wave_phase += wave_speed * delta

	# Mantém a altura acima do chão mesmo se empurrado para baixo.
	if is_on_floor():
		velocity.y = -hover_height * 2.0
		return

	var wave := sin(_wave_phase) * wave_amplitude

	# Perseguindo, sobe junto com o alvo até o teto. Sem isso o bico fica
	# preso embaixo de plataformas altas.
	var desired := wave
	if state == State.CHASE and _target != null and is_instance_valid(_target):
		var target_height := clampf(
			hover_height - _target.global_position.y * 0.35,
			hover_height,
			ceiling_height
		)
		desired = lerpf(desired, target_height, 0.5)

	## Persegue a altura desejada com uma PD simples: mais suave que
## `velocity.y = alvo`, que daria solavanco a cada quadro.
	velocity.y += (desired - (velocity.y * 0.3)) * 3.0 * delta