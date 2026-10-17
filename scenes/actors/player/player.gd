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

const SPEED := 340.0
const GROUND_ACCELERATION := 2800.0
const AIR_ACCELERATION := 1600.0
const GROUND_FRICTION := 3200.0
const AIR_FRICTION := 900.0

const JUMP_VELOCITY := -1010.0
## Multiplicador aplicado quando o botao e solto no meio do pulo.
## 1.0 = altura fixa; menor = o pulo encurta e o controle fica mais fino.
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
## Multiplicador da gravidade no topo do arco. Abaixo de 1 o jogador "flutua"
## no apice, o que da tempo de ajustar a direcao no ar.
const APEX_GRAVITY_SCALE := 0.62
const APEX_VELOCITY_THRESHOLD := 220.0
const HARD_LANDING_SPEED := 700.0

const DASH_SPEED := 980.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.55
const DASH_END_SPEED_RATIO := 0.7

const ATTACK_COOLDOWN := 0.32
const ATTACK_ACTIVE_TIME := 0.14
const ATTACK_DAMAGE := 1
const ATTACK_REACH := 28.0

const IFRAME_TIME := 1.0
const HURT_KNOCKBACK := 420.0

@export var gravity_scale := 1.0

## Gravidade aplicada quando `get_gravity()` devolve zero.
##
## `get_gravity()` so funciona se a opcao "Custom Gravity" estiver marcada em
## Project Settings > Physics > 2D. Como nao queremos depender de uma caixa de
## selecao, lemos o valor ourselves. Sem isto o corpo nao tem gravidade, nunca
## fica `is_on_floor()` de forma confiavel e o coyote time nunca preenche --
## o que trava o pulo e faz o personagem flutuar.
const DEFAULT_GRAVITY := 980.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _dash_direction := Vector2.RIGHT

var _attack_timer := 0.0
var _attack_cooldown := 0.0
var _invuln_timer := 0.0
var _was_on_floor := true
var _dead := false

@onready var _sprite: Polygon2D = $Sprite
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _hitbox: Hitbox = $Hitbox
@onready var _spark: CPUParticles2D = $Hitbox/Spark
@onready var _camera_shake: Node2D = $Camera2D/CameraShake


func _ready() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ENEMY
	_hitbox.damage = ATTACK_DAMAGE
	_hitbox.hit.connect(_on_attack_connected)


## Gravidade efetiva deste corpo.
##
## `get_gravity()` devolve (0,0) a menos que Project Settings > Physics > 2D >
## "Custom Gravity" esteja ligado. Sem isso o corpo flutua, `is_on_floor()`
## nunca fica confiavel, o coyote time nao preenche e o pulo nunca dispara.
func _gravity() -> float:
	var from_engine := get_gravity().y
	if from_engine != 0.0:
		return from_engine
	return float(ProjectSettings.get_setting("physics/2d/default_gravity", DEFAULT_GRAVITY))


## Chamado pela [Hurtbox] quando a hitbox ativa encosta em um alvo valido.
func _on_attack_connected(_hurtbox: Area2D) -> void:
	_spark.position = global_position
	_spark.restart()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if _dead:
		velocity.y += _step_gravity() * gravity_scale
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
			velocity.y += _step_gravity() * gravity_scale

	move_and_slide()
	_update_facing(input_dir)
	_check_landing()


func _process(delta: float) -> void:
	if _invuln_timer <= 0.0:
		return
	_invuln_timer -= delta
	# Piscada para indicar invulnerabilidade.
	_sprite.modulate.a = 0.3 if int(_invuln_timer * 22.0) % 2 == 0 else 1.0
	if _invuln_timer <= 0.0:
		_hurtbox.invulnerable = false
		_sprite.modulate = Color.WHITE


# ------------------------------------------------------------------ dash


func _start_dash(input_dir: Vector2) -> void:
	_dash_direction = input_dir if input_dir != Vector2.ZERO else Vector2(signf(_sprite.scale.x), 0.0)
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

	# O buffer NÃO é preenchido aqui. Isso acontecia com
	# `Input.is_action_just_pressed(&"jump")`, que vale por um único frame: se o
	# passo de física rodar antes de o InputMap consumir o evento do teclado, a
	# leitura passa batido e o pulo simplesmente nunca acontece. Agora quem
	# enche o buffer é `_unhandled_input`, que recebe o evento sempre.
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		Sfx.play(&"jump", -5.0)


## Entrada vinda do evento, não do polling: nunca perde um toque.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump"):
		_jump_buffer_timer = JUMP_BUFFER
	elif event.is_action_released(&"jump") and velocity.y < 0.0:
		# Soltar o botao mais cedo corta o pulo (altura variável).
		velocity.y *= JUMP_CUT
	elif event.is_action_pressed(&"attack"):
		_try_attack()


## Gravidade do passo, com flutuação no topo do arco do pulo.
##
## Prender no apice dá tempo de corrigir a direção no ar, que é o que faz um
## pulo parecer "controlável" em vez de um arco rígido. Só vale na subida.
func _step_gravity() -> float:
	var g := _gravity()
	if velocity.y < 0.0 and absf(velocity.y) < APEX_VELOCITY_THRESHOLD:
		return g * APEX_GRAVITY_SCALE
	return g


func _check_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var impact: float = absf(velocity.y)
		landed.emit(impact)
		if impact >= HARD_LANDING_SPEED:
			_camera_shake.shake_for(0.35)
			Sfx.play(&"land", -4.0)
	_was_on_floor = on_floor


func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)

	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_hitbox.deactivate()


func _update_facing(input_dir: Vector2) -> void:
	if input_dir.x != 0.0:
		_sprite.scale.x = signf(input_dir.x)
	elif absf(velocity.x) > 1.0:
		_sprite.scale.x = signf(velocity.x)
	# A hitbox fica sempre a frente do corpo.
	_hitbox.position.x = ATTACK_REACH * signf(_sprite.scale.x)


# --------------------------------------------------------------- combate


func _try_attack() -> void:
	if _dead or _attack_cooldown > 0.0:
		return
	_attack_cooldown = ATTACK_COOLDOWN
	_attack_timer = ATTACK_ACTIVE_TIME
	_hitbox.activate()
	Sfx.play(&"swing", -8.0)


## Chamado pela [Hurtbox] quando uma hitbox ativa encosta neste corpo.
func apply_damage(amount: int, source: Node, direction: Vector2, knockback: float) -> void:
	if _dead or _invuln_timer > 0.0:
		return

	_invuln_timer = IFRAME_TIME
	_hurtbox.invulnerable = true
	velocity += direction.normalized() * maxf(knockback, HURT_KNOCKBACK)
	_camera_shake.shake_for(0.8)
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
	_sprite.modulate = Color(0.55, 0.55, 0.62, 0.8)
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
