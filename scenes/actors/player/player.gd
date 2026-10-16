extends CharacterBody2D
## Prototipo do jogador: movimento 8-direcional, pulo com coyote time e
## jump buffer, e dash com cooldown.
##
## Toda a entrada vem do Input Map (nunca teclas cruas), entao o mesmo script
## funciona no teclado, no gamepad e depois num menu de remapeamento.

const SPEED := 340.0
const GROUND_ACCELERATION := 2800.0
const AIR_ACCELERATION := 1600.0
const GROUND_FRICTION := 3200.0
const AIR_FRICTION := 900.0

const JUMP_VELOCITY := -820.0
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12

const DASH_SPEED := 980.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.55
const DASH_END_SPEED_RATIO := 0.7

@export var gravity_scale := 1.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _dash_direction := Vector2.RIGHT

@onready var _sprite: Polygon2D = $Sprite
@onready var _camera: Camera2D = $Camera2D


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

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
			velocity.y += get_gravity().y * gravity_scale

	move_and_slide()
	_update_facing(input_dir)


func is_dashing() -> bool:
	return _dash_timer > 0.0


# ------------------------------------------------------------------ dash


func _start_dash(input_dir: Vector2) -> void:
	_dash_direction = input_dir if input_dir != Vector2.ZERO else Vector2(_sprite.scale.x, 0.0).normalized()
	_dash_timer = DASH_TIME
	velocity = _dash_direction * DASH_SPEED


func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	# Durante o dash a velocidade fica travada: sem gravidade e sem atrito.
	velocity = _dash_direction * DASH_SPEED
	if _dash_timer <= 0.0:
		_dash_cooldown = DASH_COOLDOWN
		# Pequena arrancada ao final para o dash nao "travar" no chao.
		velocity = _dash_direction * SPEED * DASH_END_SPEED_RATIO


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
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = JUMP_BUFFER
	if is_on_floor():
		_coyote_timer = COYOTE_TIME

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	# Soltar o botao mais cedo corta o pulo (pulo de altura variavel).
	if Input.is_action_just_released(&"jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT


func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)


func _update_facing(input_dir: Vector2) -> void:
	if input_dir.x != 0.0:
		_sprite.scale.x = signf(input_dir.x)
	elif absf(velocity.x) > 1.0:
		_sprite.scale.x = signf(velocity.x)


## Teleporta o jogador, zerando o estado de movimento.
func teleport_to(position: Vector2) -> void:
	global_position = position
	velocity = Vector2.ZERO
	_dash_timer = 0.0
	_dash_cooldown = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0