class_name Player
extends CharacterBody2D
## Prototipo do jogador: movimento 8-direcional, pulo com coyote time e jump
## buffer, dash com cooldown e combate por hitbox/hurtbox.
##
## Toda a entrada vem do Input Map (nunca teclas cruas), entao o mesmo script
## funciona no teclado, no gamepad e depois num menu de remapeamento.

signal died
signal damaged(amount: int, source: Node)
signal landed(impact_speed: float)

## Os numeros vivem em [PlayerTuning] para que os testes possam usa-los sem
## compilar este script. Aqui sao apenas apelidos, para o corpo do codigo
## continuar legivel como `SPEED` e nao `PlayerTuning.SPEED`.
const SPEED := PlayerTuning.SPEED
const GROUND_ACCELERATION := PlayerTuning.GROUND_ACCELERATION
const AIR_ACCELERATION := PlayerTuning.AIR_ACCELERATION
const GROUND_FRICTION := PlayerTuning.GROUND_FRICTION
const AIR_FRICTION := PlayerTuning.AIR_FRICTION
const JUMP_VELOCITY := PlayerTuning.JUMP_VELOCITY
const JUMP_CUT := PlayerTuning.JUMP_CUT
const COYOTE_TIME := PlayerTuning.COYOTE_TIME
const JUMP_BUFFER := PlayerTuning.JUMP_BUFFER
const APEX_GRAVITY_SCALE := PlayerTuning.APEX_GRAVITY_SCALE
const APEX_VELOCITY_THRESHOLD := PlayerTuning.APEX_VELOCITY_THRESHOLD
const HARD_LANDING_SPEED := PlayerTuning.HARD_LANDING_SPEED
const JUMP_CLEARANCE := PlayerTuning.JUMP_CLEARANCE
const DASH_SPEED := PlayerTuning.DASH_SPEED
const DASH_TIME := PlayerTuning.DASH_TIME
const DASH_COOLDOWN := PlayerTuning.DASH_COOLDOWN
const DASH_END_SPEED_RATIO := PlayerTuning.DASH_END_SPEED_RATIO
const ATTACK_COOLDOWN := PlayerTuning.ATTACK_COOLDOWN
const ATTACK_ACTIVE_TIME := PlayerTuning.ATTACK_ACTIVE_TIME
const ATTACK_DAMAGE := PlayerTuning.ATTACK_DAMAGE
const ATTACK_REACH := PlayerTuning.ATTACK_REACH
const HEAVY_CHARGE_TIME := 0.28
const HEAVY_DAMAGE := 3
const HEAVY_ACTIVE_TIME := 0.22
const AIR_ATTACK_DAMAGE := 2
const AIR_ATTACK_ACTIVE_TIME := 0.16
const PARRY_WINDOW := 0.18
const IFRAME_TIME := PlayerTuning.IFRAME_TIME
const HURT_KNOCKBACK := PlayerTuning.HURT_KNOCKBACK
const DEFAULT_GRAVITY := PlayerTuning.DEFAULT_GRAVITY

## Cor do numero de dano que o player leva. Vermelho: o numero e sobre o
## jogador, e vermelho e a cor que o jogador ja associa a "perdi vida".
const HURT_NUMBER_COLOR := Color(1.0, 0.44, 0.44)

@export var gravity_scale := 1.0

## Abaixo disso o corpo esta andando, nao correndo, e poeira de corrida
## ficaria esquisita. Mesma faixa que o bone usa para distinguir passos.
const DUST_SPEED := 120.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _dash_direction := Vector2.RIGHT

var _parry_timer := 0.0
var _heavy_charging := false
var _heavy_charge := 0.0

var _attack_timer := 0.0
var _attack_cooldown := 0.0
var _invuln_timer := 0.0
var _was_on_floor := true
var _dead := false

@onready var _rig: PlayerRig = $Rig
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _hitbox: Hitbox = $Hitbox
@onready var _spark: CPUParticles2D = $Hitbox/Spark
@onready var _camera_shake: Node2D = $Camera2D/CameraShake
@onready var _dust: CPUParticles2D = $Dust
@onready var _splash: CPUParticles2D = $Splash
@onready var _trail: CPUParticles2D = $Trail


func _ready() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ENEMY
	_hitbox.damage = ATTACK_DAMAGE
	_hitbox.hit.connect(_on_attack_connected)

	# Presets aqui, e nao no .tscn: mudanca de aparencia e uma linha em
	# src/fx/particle_preset.gd em vez de vinte linhas em um .tscn que ninguem abre.
	ParticlePreset.dust(_dust)
	ParticlePreset.splash(_splash)
	ParticlePreset.trail(_trail)


## Gravidade efetiva deste corpo.
##
## `get_gravity()` devolve (0,0) a menos que Project Settings > Physics > 2D >
## "Custom Gravity" esteja ligado. Sem isso o corpo flutua, `is_on_floor()`
## nunca fica confiavel, o coyote time nao preenche e o pulo nunca dispara.
func _gravity() -> float:
	# Sempre positiva. `get_gravity().y` pode vir NEGATIVO (com "Custom
	# Gravity" ligado o eixo Y aponta para baixo e a gravidade vem como
	# -980). Somar esse valor em `velocity.y += _gravity()` fazia a gravidade
	# DESACELERAR a subida: -1010 + -980 = -30, e o pulo virava um pulinho.
	var from_engine := absf(get_gravity().y)
	if from_engine > 0.0:
		return from_engine
	return absf(float(ProjectSettings.get_setting("physics/2d/default_gravity", DEFAULT_GRAVITY)))


## Chamado pela [Hurtbox] quando a hitbox ativa encosta em um alvo valido.
func _on_attack_connected(_hurtbox: Area2D) -> void:
	_spark.position = global_position
	_spark.restart()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_update_heavy_charge(delta)

	if _dead:
		velocity.y += _step_gravity(delta) * gravity_scale
		move_and_slide()
		return

	var input_dir := Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down"
	)

	if _dash_timer > 0.0:
		_process_dash(delta)
	else:
		if Input.is_action_just_pressed(&"dash") and _dash_cooldown <= 0.0:
			_start_dash(input_dir)
		else:
			_process_ground_air(delta, input_dir)
			_process_jump()
			velocity.y += _step_gravity(delta) * gravity_scale

	move_and_slide()
	_update_facing(input_dir)
	_check_landing()
	_update_particles()


func _process(delta: float) -> void:
	_update_rig(delta)
	if _invuln_timer <= 0.0:
		return
	_invuln_timer -= delta
	# Piscada para indicar invulnerabilidade.
	_rig.modulate.a = 0.3 if int(_invuln_timer * 22.0) % 2 == 0 else 1.0
	if _invuln_timer <= 0.0:
		_hurtbox.invulnerable = false
		_rig.modulate = Color.WHITE


## Traduz o estado do corpo na pose do bone.
##
## Quem decide a ordem de prioridade e o [PlayerRig], nao aqui: o player
## descreve *o que esta acontecendo*, e o rig escolhe a figura. Assim a
## anatomia (qual pose ganha sobre qual) fica em um arquivo só.
func _update_rig(delta: float) -> void:
	_rig.play(_rig.resolve(
		_dead,
		_invuln_timer > IFRAME_TIME * 0.55,
		is_dashing(),
		_attack_timer > 0.0,
		is_on_floor(),
		velocity.y,
		velocity.x
	))
	_rig.tick(delta)


# ------------------------------------------------------------------ dash


func _start_dash(input_dir: Vector2) -> void:
	_dash_direction = input_dir if input_dir != Vector2.ZERO else Vector2(signf(_rig.facing), 0.0)
	_dash_timer = DASH_TIME
	velocity = _dash_direction * DASH_SPEED
	Sfx.play(&"dash", -6.0)


func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	# Durante o dash a velocidade fica travada: sem gravidade e sem atrito.
	velocity = _dash_direction * DASH_SPEED
	if _dash_timer <= 0.0:
		_dash_cooldown = DASH_COOLDOWN
		# Pequena arrancada ao final para o dash nao "travar" no chao.
		velocity = _dash_direction * SPEED * DASH_END_SPEED_RATIO


func is_dashing() -> bool:
	return _dash_timer > 0.0


# ------------------------------------------------------------- movimento


func _process_ground_air(delta: float, input_dir: Vector2) -> void:
	var on_floor := is_on_floor()
	var accel := GROUND_ACCELERATION if on_floor else AIR_ACCELERATION
	var friction := GROUND_FRICTION if on_floor else AIR_FRICTION

	if input_dir != Vector2.ZERO:
		velocity.x = move_toward(velocity.x, input_dir.x * SPEED, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _process_jump() -> void:
	# is_on_floor() primeiro: o pulo só vale com o corpo apoiado, e o coyote
	# precisa estar reposto antes da comparação com o buffer.
	if is_on_floor():
		_coyote_timer = COYOTE_TIME

	# O buffer NÃO é preenchido aqui: quem enche é `_unhandled_input`, que
	# recebe o evento sempre. Poll por `is_action_just_pressed` dentro de
	# `_physics_process` pode perder o toque se o passo de física rodar antes
	# de o InputMap consumir o evento do teclado.
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		# Afasta o pé da superfície antes do impulso, com folga. Sem isto uma
		# penetração de fração de pixel faz o `move_and_slide` ler o impulso
		# como movimento para dentro do chão.
		var floor_normal := get_floor_normal()
		if floor_normal != Vector2.ZERO:
			global_position += floor_normal * JUMP_CLEARANCE

		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		Sfx.play(&"jump", -5.0)


## Entrada vinda do evento, não do polling: nunca perde um toque.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump"):
		_jump_buffer_timer = JUMP_BUFFER
	elif event.is_action_released(&"attack"):
		_release_attack()
	elif event.is_action_released(&"jump") and velocity.y < 0.0:
		# Soltar o botao mais cedo corta o pulo (altura variável).
		velocity.y *= JUMP_CUT
	elif event.is_action_pressed(&"attack"):
		_start_heavy_charge()
	elif event.is_action_pressed(&"interact"):
		try_use_item()
	elif event.is_action_pressed(&"parry"):
		_try_parry()


## Consome o primeiro item com efeito. `interact` estava no Input Map sem
## ninguem consumindo -- era a acao sobrando do prototipo, e usar item e
## exatamente o que ela sempre esteve ali para fazer.
## Publico para o teste: e o mesmo caminho que a tecla `interact` chama.
func try_use_item() -> void:
	if _dead:
		return
	var id := GameState.first_usable_id()
	if id == &"":
		Sfx.play(&"back", -8.0)
		return
	if GameState.use_item(id, self):
		return  # o som sai de `on_item_used`
	# Vida cheia: `use_item` recusa e devolve false sem gastar. O som de "não
	# dá" importa mais que o de "deu": sem ele o jogador acha que usou.
	Sfx.play(&"back", -6.0)


## Cura direta, para quem quiser um pickup que não passa pelo inventário.
func heal(amount: int) -> void:
	if _dead or amount <= 0:
		return
	GameState.heal(amount)
	Sfx.play(&"coin", -2.0, 1.3)


## Gancho que o [ItemDefinition] chama depois de aplicar o efeito. Existe para
## o som: o item sabe o que faz, e o Player sabe como soar.
func on_item_used(_item: Resource) -> void:
	Sfx.play(&"coin", -2.0, 1.3)


## Aceleração da gravidade **por segundo**, aplicada ao passo atual.
##
## O `* delta` é obrigatório: sem ele a gravidade entrava como +980 inteiro a
## cada frame em vez de +980/60, e um pulo de -1010 virava -30 — o impulso era
## quase todo cancelado no mesmo frame. É por isso que o pulo "não saía".
func _step_gravity(delta: float) -> float:
	var g := _gravity()
	if velocity.y < 0.0 and absf(velocity.y) < APEX_VELOCITY_THRESHOLD:
		g *= APEX_GRAVITY_SCALE
	return g * delta


func _check_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var impact: float = absf(velocity.y)
		landed.emit(impact)
		if impact >= HARD_LANDING_SPEED:
			_camera_shake.shake_for(0.35)
			Sfx.play(&"land", -4.0)
		# Respingo em qualquer pouso, forte ou fraco: o jogador precisa
		# ver onde tocou o chao mesmo quando nao sentiu tremor.
		_splash.restart()
	_was_on_floor = on_floor


## Poeira, respingo e rastro, ligados ao estado do corpo.
##
## Ficam juntos e nao nas tres funcois que os disparam porque os tres leem o
## mesmo par de condicoes: "esta no chao" e "esta rapido". Espalhado pelo
## arquivo, viraria mais um lugar para esquecer de ligar particula.
func _update_particles() -> void:
	var dashing := is_dashing()
	# Poeira so no chao: no ar ela nao tem nem chao para levantar.
	_dust.emitting = not dashing and is_on_floor() and absf(velocity.x) > DUST_SPEED

	_trail.emitting = dashing
	if dashing:
		# O rastro sai para tras, e o dash pode ser para qualquer um dos quatro
		# lados. Preset fixo so funcionaria em um deles.
		_trail.direction = -_dash_direction


func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)

	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_hitbox.deactivate()

	_parry_timer = maxf(_parry_timer - delta, 0.0)

func _update_facing(input_dir: Vector2) -> void:
	if input_dir.x != 0.0:
		_rig.facing = signf(input_dir.x)
	elif absf(velocity.x) > 1.0:
		_rig.facing = signf(velocity.x)
	# A hitbox fica sempre a frente do corpo.
	_hitbox.position.x = ATTACK_REACH * signf(_rig.facing)


# --------------------------------------------------------------- combate


func _update_heavy_charge(delta: float) -> void:
	if not _heavy_charging:
		return
	_heavy_charge += delta
	if _heavy_charge >= HEAVY_CHARGE_TIME:
		_heavy_charging = false
		_fire_heavy()
		_heavy_charge = 0.0


func _fire_heavy() -> void:
	if _dead or _attack_cooldown > 0.0:
		return
	_attack_cooldown = ATTACK_COOLDOWN * 1.4
	_attack_timer = HEAVY_ACTIVE_TIME
	_hitbox.damage = HEAVY_DAMAGE
	_hitbox.position.y = 0.0
	_hitbox.activate()
	Sfx.play(&"swing", -4.0)


func _try_parry() -> void:
	if _dead:
		return
	_parry_timer = PARRY_WINDOW
	Sfx.play(&"select", -6.0)


func _start_heavy_charge() -> void:
	if _dead or _attack_cooldown > 0.0 or not is_on_floor():
		if not is_on_floor():
			_try_attack()
		return
	_heavy_charging = true
	_heavy_charge = 0.0


func _release_attack() -> void:
	if not _heavy_charging:
		return
	_heavy_charging = false
	if _heavy_charge >= HEAVY_CHARGE_TIME:
		_fire_heavy()
	else:
		_try_attack()
	_heavy_charge = 0.0


func _try_attack() -> void:
	if _dead or _attack_cooldown > 0.0:
		return
	_attack_cooldown = ATTACK_COOLDOWN
	if not is_on_floor():
		_attack_timer = AIR_ATTACK_ACTIVE_TIME
		_hitbox.damage = AIR_ATTACK_DAMAGE
		_hitbox.position.y = 18.0
	else:
		_attack_timer = ATTACK_ACTIVE_TIME
		_hitbox.damage = ATTACK_DAMAGE
		_hitbox.position.y = 0.0
	_hitbox.activate()
	Sfx.play(&"swing", -8.0)



## Chamado pela [Hurtbox] quando uma hitbox ativa encosta neste corpo.
func apply_damage(amount: int, source: Node, direction: Vector2, knockback: float) -> void:
	if _dead or _invuln_timer > 0.0:
		return

	# Parry: dentro da janela, o golpe nao tira vida e devolve o stagger
	# para quem atacou. E o mesmo caminho de dano, so que o dano vira zero
	# e o atacante perde.
	if _parry_timer > 0.0:
		_parry_timer = 0.0
		Hitstop.trigger(3)
		_camera_shake.shake_for(0.6)
		FloatingNumber.spawn(get_tree().current_scene, global_position, 0, Color(0.6, 1.0, 0.9))
		if source != null and source.has_method("apply_damage"):
			source.call("apply_damage", 0, self, -Vector2.ONE, 0.0)
		return


	_invuln_timer = IFRAME_TIME
	_hurtbox.invulnerable = true
	velocity += direction.normalized() * maxf(knockback, HURT_KNOCKBACK)

	# O tremor escala com o estrago. Constante, ele mente sobre a diferenca
	# entre levar 1 e levar 25 -- que e a diferenca entre tropecar e ser
	# arremessado.
	var ratio := clampf(float(amount) / float(maxi(1, GameState.max_health)), 0.0, 1.0)
	_camera_shake.shake_for(lerpf(0.45, 1.0, ratio))

	# Hitstop mais longo quando o golpe foi grande: o congelamento e metade da
	# leitura de peso, e um dano de 25 deveria pesar diferente de 1.
	var frames := int(round(lerpf(1.0, 4.0, ratio)))
	Hitstop.trigger(frames)

	FloatingNumber.spawn(get_tree().current_scene, global_position, amount, HURT_NUMBER_COLOR)

	Sfx.play(&"hurt")

	GameState.take_damage(amount)
	damaged.emit(amount, source)

	if GameState.health <= 0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	_hurtbox.invulnerable = true
	_hitbox.deactivate()
	_rig.modulate = Color(0.55, 0.55, 0.62, 0.8)
	velocity = Vector2(velocity.x * 0.3, JUMP_VELOCITY * 0.55)
	Sfx.play(&"death")
	died.emit()


func is_dead() -> bool:
	return _dead


func is_invulnerable() -> bool:
	return _invuln_timer > 0.0


## Reposiciona e restaura o jogador (usado por checkpoints e respawn).
func teleport_to(position: Vector2) -> void:
	global_position = position
	velocity = Vector2.ZERO
	_dash_timer = 0.0
	_dash_cooldown = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_invuln_timer = 0.0
	_attack_timer = 0.0
	_attack_cooldown = 0.0
