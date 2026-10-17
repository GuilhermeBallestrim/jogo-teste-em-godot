class_name Enemy
extends CharacterBody2D
## Inimigo com maquina de estados.
##
##     IDLE -> PATROL -> CHASE -> ATTACK -> STAGGER -> CHASE
##                          ^                       |
##                          +-----------------------+
##
## A deteccao exige distancia **e** linha de visao (raycast), entao um inimigo
## parado atras de uma parede nao "enxerga" o jogador.
##
## Subclasses sobrescrevem [method _apply_vertical] para mudar a locomocao
## (ver `slime.gd`, que pula em vez de andar).

enum State { IDLE, PATROL, CHASE, ATTACK, STAGGER, DEAD }

signal state_changed(from: State, to: State)
signal died(enemy: Enemy)

const GRAVITY_SCALE := 1.0
const STOP_ACCELERATION := 1100.0
const CHASE_ACCELERATION := 1400.0

const PATROL_PAUSE := 0.6
const PATROL_TOLERANCE := 8.0

const HITBOX_ACTIVE_TIME := 0.16
const ATTACK_TIME := 0.22
const ATTACK_RECOVER := 0.45
const ATTACK_COOLDOWN := 0.7
const STAGGER_TIME := 0.24

@export_group("Deteccao")
@export var detect_range := 300.0
@export var forget_range := 440.0
@export var attack_range := 56.0

@export_group("Movimento")
@export var patrol_speed := 90.0
@export var chase_speed := 215.0
@export var attack_lunge := 180.0
@export var patrol_left := -120.0
@export var patrol_right := 120.0

@export_group("Combate")
@export var max_health := 3
@export var contact_damage := 1
@export var knockback_resistance := 0.0

@export_group("Aparencia")
@export var body_size := Vector2(36.0, 28.0)
@export var body_color := Color(0.85, 0.35, 0.45)

var state: State = State.IDLE
var health: int = 3

var _target: Node2D = null
var _state_timer := 0.0
var _attack_cooldown := 0.0
var _hitbox_timer := 0.0
var _facing := 1.0
var _patrol_target_x := 0.0

@onready var _sprite: Polygon2D = $Sprite
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _hitbox: Hitbox = $Hitbox
@onready var _health_bar: ColorRect = get_node_or_null(^"HealthBar")

var _was_on_floor := true


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.PLAYER

	health = max_health
	_patrol_target_x = patrol_right
	_hitbox.damage = contact_damage
	_apply_appearance()


func _apply_appearance() -> void:
	var half := body_size * 0.5
	_sprite.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	_sprite.color = body_color
	var rect := RectangleShape2D.new()
	rect.size = body_size
	_shape.shape = rect


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		_apply_vertical(delta)
		move_and_slide()
		return

	_state_timer += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_tick_hitbox(delta)

	if _target == null or not is_instance_valid(_target):
		_find_target()

	_think(delta)
	_apply_vertical(delta)
	move_and_slide()
	_track_landing()

	if absf(velocity.x) > 5.0:
		_facing = signf(velocity.x)
		_sprite.scale.x = _facing
		_hitbox.position.x = absf(_hitbox.position.x) * _facing


func _track_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_on_landed()
	_was_on_floor = on_floor


## Ponto de extensao: chamado no instante em que o corpo encosta no chao.
func _on_landed() -> void:
	pass


## Gravidade. Subclasses sobrescrevem para ter uma locomocao diferente.
##
## `get_gravity()` devolve (0,0) sem "Custom Gravity" ligado em Project
## Settings > Physics > 2D, entao lemos o valor do projeto como fallback.
func _apply_vertical(delta: float) -> void:
	# `get_gravity().y` pode vir negativo; a gravidade tem de ser positiva,
	# senao `velocity.y += g` desacelera a subida em vez de puxar para baixo.
	#
	# O `* delta` é obrigatório: sem ele a gravidade entrava inteira a cada
	# frame, e o hop do slime era praticamente engolido no mesmo passo.
	var g := absf(get_gravity().y)
	if g == 0.0:
		g = absf(float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)))
	velocity.y += g * GRAVITY_SCALE * delta


func _tick_hitbox(delta: float) -> void:
	if _hitbox_timer <= 0.0:
		return
	_hitbox_timer -= delta
	if _hitbox_timer <= 0.0:
		_hitbox.deactivate()


# ------------------------------------------------------------------ FSM


func _think(delta: float) -> void:
	match state:
		State.IDLE:
			_stop(delta)
			if _state_timer >= PATROL_PAUSE:
				_set_state(State.PATROL)
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_stop(delta, 1400.0)
			if _state_timer >= ATTACK_TIME:
				_attack_cooldown = ATTACK_COOLDOWN
				_set_state(State.STAGGER)
		State.STAGGER:
			_stop(delta, 800.0)
			if _state_timer >= STAGGER_TIME:
				_set_state(State.CHASE if _sees_target(forget_range) else State.PATROL)


func _stop(delta: float, acceleration: float = STOP_ACCELERATION) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)


func _patrol(delta: float) -> void:
	velocity.x = move_toward(
		velocity.x, signf(_patrol_target_x - global_position.x) * patrol_speed, 700.0 * delta
	)
	if absf(global_position.x - _patrol_target_x) < PATROL_TOLERANCE:
		_patrol_target_x = patrol_left if _patrol_target_x == patrol_right else patrol_right
		_set_state(State.IDLE)
	elif _sees_target(detect_range):
		_set_state(State.CHASE)


func _chase(delta: float) -> void:
	if not _sees_target(forget_range):
		_set_state(State.PATROL)
		return

	var to_target := _target.global_position.x - global_position.x
	_facing = signf(to_target) if to_target != 0.0 else _facing
	velocity.x = move_toward(velocity.x, _facing * chase_speed, CHASE_ACCELERATION * delta)

	if absf(to_target) <= attack_range and _attack_cooldown <= 0.0:
		_set_state(State.ATTACK)


func _set_state(next: State) -> void:
	if next == state:
		return
	var previous := state
	state = next
	_state_timer = 0.0

	if next == State.ATTACK:
		_hitbox.activate()
		_hitbox_timer = HITBOX_ACTIVE_TIME
		velocity.x = _facing * attack_lunge
	elif next == State.CHASE and previous == State.PATROL:
		# Ao entrar em perseguicao, já aimamos na direcao certa.
		if _target != null:
			_facing = signf(_target.global_position.x - global_position.x)

	state_changed.emit(previous, next)


# -------------------------------------------------------------- deteccao


func _find_target() -> void:
	for node in get_tree().get_nodes_in_group(&"player"):
		_target = node as Node2D
		return


func _sees_target(max_range: float) -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if global_position.distance_to(_target.global_position) > max_range:
		return false

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, _target.global_position)
	query.collision_mask = Layers.WORLD
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


# --------------------------------------------------------------- combate


## Chamado pela [Hurtbox]. `source` e quem deu o golpe.
func apply_damage(amount: int, source: Node, direction: Vector2, knockback: float) -> void:
	if state == State.DEAD:
		return

	health -= amount
	Sfx.play(&"enemy_hit", -7.0)
	_flash()
	_update_health_bar()

	var push: float = knockback * (1.0 - clampf(knockback_resistance, 0.0, 1.0))
	velocity += direction.normalized() * push

	if health <= 0:
		_die(source)
	else:
		_set_state(State.STAGGER)


func _update_health_bar() -> void:
	if _health_bar == null:
		return
	_health_bar.visible = health < max_health
	_health_bar.scale.x = clampf(float(health) / float(max_health), 0.0, 1.0)
	_health_bar.position.x = -(absf(_health_bar.size.x) * 0.5) * (1.0 - _health_bar.scale.x)


func _flash() -> void:
	_sprite.modulate = Color(1.6, 1.6, 1.6)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.18)


func _die(source: Node) -> void:
	state = State.DEAD
	_hurtbox.invulnerable = true
	_hitbox.deactivate()
	collision_layer = 0
	velocity = Vector2(velocity.x * 0.4, -240.0)

	GameState.add_score(50)
	Sfx.play(&"enemy_die", -6.0)
	died.emit(self)

	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(0.7, 0.7, 0.7, 0.0), 0.45)
	tween.parallel().tween_property(_sprite, "scale", Vector2(1.3, 0.7), 0.45)
	tween.tween_callback(queue_free)