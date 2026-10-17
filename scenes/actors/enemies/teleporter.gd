extends Enemy
## Teleportador: desaparece e reaparece perto do jogador.
##
## Nao patrulha: fica parado, e a cada intervalo se teletransporta para
## uma posicao proxima do jogador (mas nao em cima dele).

@export var teleport_interval := 2.5
@export var teleport_range := 120.0

var _teleport_timer := 0.0

func _ready() -> void:
	body_color = Color(0.6, 0.35, 0.75)
	super._ready()
	detect_range = 400.0
	forget_range = 600.0


func _think(delta: float) -> void:
	_teleport_timer = maxf(_teleport_timer - delta, 0.0)
	match state:
		State.IDLE:
			_stop(delta)
			if _sees_target(detect_range):
				_set_state(State.CHASE)
			elif _teleport_timer <= 0.0:
				_do_teleport()
				_teleport_timer = teleport_interval
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
			if _teleport_timer <= 0.0 and _sees_target(detect_range):
				_do_teleport()
				_teleport_timer = teleport_interval
		State.AIM:
			_stop(delta, 900.0)
			if _state_timer >= AIM_TIME:
				_fire()
				_set_state(State.ATTACK)
		State.ATTACK:
			_stop(delta, 1400.0)
			if _state_timer >= ATTACK_TIME:
				_attack_cooldown = ATTACK_COOLDOWN
				_set_state(State.STAGGER)
		State.STAGGER:
			_stop(delta, 800.0)
			if _state_timer >= STAGGER_TIME:
				_set_state(State.CHASE if _sees_target(forget_range) else State.IDLE)
		State.VULNERABLE:
			pass
		State.DEAD:
			pass


func _do_teleport() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var offset := Vector2(randf_range(-teleport_range, teleport_range), 0)
	var new_pos := _target.global_position + offset
	# Mantem dentro da arena (evita teleportar para fora do mundo).
	new_pos.x = clampf(new_pos.x, _home.x - 400, _home.x + 400)
	global_position = new_pos
	velocity = Vector2.ZERO
	ParticlePreset.spawn_burst(get_tree().current_scene, global_position, body_color, 12)
	Sfx.play(&"select", -6.0)