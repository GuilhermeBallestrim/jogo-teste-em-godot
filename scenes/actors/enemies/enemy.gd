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

enum State { IDLE, PATROL, CHASE, AIM, ATTACK, STAGGER, VULNERABLE, DEAD }

signal state_changed(from: State, to: State)
signal died(enemy: Enemy)

## Nome do estado atual. Existe para log, UI e teste: comparar nomes sobrevive
## a reinserir um estado no enum, enquanto um indice literal mede a coisa
## errada em silencio.
func state_name() -> String:
	return String(State.keys()[state])

const GRAVITY_SCALE := 1.0
## Arrasto vertical dos inimigos que voam, em px/s^2. Evita velocidade
## vertical infinita quando o knockback empurra o corpo para cima.
const AIR_DRAG := 260.0
const STOP_ACCELERATION := 1100.0
const CHASE_ACCELERATION := 1400.0

const PATROL_PAUSE := 0.6
const PATROL_TOLERANCE := 8.0

## Quanto o corpo olha para a frente, em px, antes de perguntar "tem chao
## aqui?". Chega de perto da borda para o inimigo frear em vez de sair
## colando no vazio.
const LEDGE_PROBE := 12.0
## Quao longe o raycast procura chao abaixo do probe.
const LEDGE_DEPTH := 28.0
## Rede de seguranca padrao: quantos px o inimigo pode cair antes de voltar
## para casa. Nunca deveria disparar -- e a guarda de borda que impede a
## queda. Existe para o caso do knockback e de plataforma que some no meio
## da fase.
const DEFAULT_FALL_LIMIT := 280.0
const HITBOX_ACTIVE_TIME := 0.16
const ATTACK_TIME := 0.22

## Cor do numero de dano que o inimigo leva.
##
## Era dourado, e a captura mostrou por que isso nao funciona: o jogo inteiro
## e dourado -- moeda, faixa de plataforma, moeda grande. O numero sumia no
## cenario, que e o oposto do que um numero de dano tem que fazer. Verde nao
## existe em lugar nenhum da paleta atual (bone azul, scarf vermelho, slime
## rosa, cenario azul-marinho), entao o numero aparece sobre qualquer fundo.
const HIT_NUMBER_COLOR := Color(0.55, 1.0, 0.5)
const ATTACK_RECOVER := 0.45

const ATTACK_COOLDOWN := 0.7
const STAGGER_TIME := 0.24

## Tempo parado mirando antes de atirar. Sem essa telegrafia o tiro chega
## no mesmo frame em que o inimigo decide atirar, e o jogador não tem como
## reagir -- parece injusto, não difícil.
const AIM_TIME := 0.45

@export_group("Deteccao")
@export var detect_range := 300.0
@export var forget_range := 440.0
@export var attack_range := 56.0

@export_group("Movimento")
@export var patrol_speed := 90.0
@export var chase_speed := 215.0
@export var attack_lunge := 180.0
## Deslocamento horizontal da patrulha em relacao ao ponto onde o inimigo
## foi colocado na cena. **Nao e coordenada de mundo**: escrever
## `patrol_right = 150` numa fase que comeca em x = -1000 significa "para a
## direita ate -850", nao "va para x = 150". Era assim mesmo no codigo, e
## era o motivo de todo slime sair andando para o fim do mapa.
@export var patrol_left := -120.0:
	set(value):
		patrol_left = value
		_patrol_bounds_dirty = true
@export var patrol_right := 120.0:
	set(value):
		patrol_right = value
		_patrol_bounds_dirty = true

## Quanto o inimigo e autorizado a se afastar da casa. 0 = sem limite.
## Serve para o arqueiro na torre: ele não deve descer seis plataformas
## atrás do jogador.
@export var leash_radius := 0.0
## Quantos px o inimigo pode cair antes de ser devolvido a casa. A guarda de
## borda já impede a queda de propósito; isto cobre o resto (knockback,
## plataforma removida). 0 desliga.
@export var fall_limit := 0.0

@export_group("Combate")
@export var max_health := 3
@export var contact_damage := 1
@export var knockback_resistance := 0.0

@export_group("Aparencia")
@export var body_size := Vector2(36.0, 28.0)
@export var body_color := Color(0.85, 0.35, 0.45)

var state: State = State.IDLE
var health: int = 3
var _invuln_timer := 0.0

var _target: Node2D = null
var _state_timer := 0.0
var _attack_cooldown := 0.0
var _hitbox_timer := 0.0
var _facing := 1.0
var _patrol_target_x := 0.0
## Onde o inimigo nasceu. Ancora da patrulha, do limite e da rede de
## seguranca. Ver [member patrol_left].
var _home := Vector2.ZERO
var _patrol_bounds_dirty := true

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
	# Ancorado no instante da entrada: `_ready` roda quando o inimigo ja
	# esta na posicao que a cena definiu, entao este e o ponto de partida.
	_home = global_position
	if not flies and fall_limit <= 0.0:
		fall_limit = DEFAULT_FALL_LIMIT
	_hitbox.damage = contact_damage
	_apply_appearance()
	# Sombra projetada: um poligono mais escuro, deslocado.
	GradientPoly.shadow(self, _sprite.polygon, Vector2(4, 6), Color(0, 0, 0, 0.35))
	_patrol_target_x = patrol_right_x()


## Extremo esquerdo da patrulha, em coordenada de mundo.
func patrol_left_x() -> float:
	return _home.x + patrol_left


## Extremo direito da patrulha, em coordenada de mundo.
func patrol_right_x() -> float:
	return _home.x + patrol_right


## Onde este inimigo foi colocado na cena. Ancora da patrulha, do limite e da
## rede de seguranca.
func home_position() -> Vector2:
	return _home


func home_x() -> float:
	return _home.x


func _refresh_patrol_target() -> void:
	# O Inspector pode mudar os offsets em runtime; o alvo precisa acompanhar.
	if _patrol_bounds_dirty:
		_patrol_target_x = patrol_right_x()
		_patrol_bounds_dirty = false


func _apply_appearance() -> void:
	var half := body_size * 0.5
	_sprite.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	_sprite.color = body_color
	GradientPoly.vertical(_sprite, body_color.lightened(0.2), body_color.darkened(0.35))
	var rect := RectangleShape2D.new()
	rect.size = body_size
	_shape.shape = rect


func _process(delta: float) -> void:
	# Respiracao: o corpo pulsa levemente quando parado. Sem isso o inimigo
	# parece uma estatua, e a captura de tela nao consegue distinguir "vivo"
	# de "morto".
	if state == State.IDLE or state == State.PATROL:
		var breath := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.04
		_sprite.scale = Vector2(breath, 1.0 / breath)
	else:
		if _sprite.scale != Vector2.ONE:
			_sprite.scale = _sprite.scale.lerp(Vector2.ONE, delta * 8.0)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		_apply_vertical(delta)
		move_and_slide()
		return

	_state_timer += delta
	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		if _invuln_timer <= 0.0:
			_hurtbox.invulnerable = false
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_tick_hitbox(delta)

	if _target == null or not is_instance_valid(_target):
		_find_target()

	_think(delta)
	_refresh_patrol_target()
	_guard_ledge(delta)
	_apply_vertical(delta)
	move_and_slide()
	_track_landing()
	_guard_offscreen()

	if absf(velocity.x) > 5.0:
		_facing = signf(velocity.x)
		_sprite.scale.x = _facing
		_hitbox.position.x = absf(_hitbox.position.x) * _facing


## Ninguem cai no vazio por querer.
##
## Um inimigo andando chega na borda da plataforma e continua andando: sem
## isto, todo slime acabava no KillZone e o arquiro descia da torre. O
## comportamento certo na beirada e parar -- e o jogador ver o inimigo
## esperando, que e a leitura de "ele nao vai me pegar daqui".
##
## A parada e dura, e nao uma frenagem: a beirada e o pior lugar para
## hesitar, e um inimigo deslizando pela borda parece bug.
func _guard_ledge(_delta: float) -> void:
	if flies or not is_on_floor():
		return
	if absf(velocity.x) < 1.0:
		return
	if has_ground_ahead(signf(velocity.x)):
		return
	velocity.x = 0.0


## Ha chao na direcao `direction`, logo abaixo da borda do corpo?
##
## Publico porque quem se locomove pulando precisa da mesma resposta: o
## slime so salta se ha para onde cair.
func has_ground_ahead(direction: float) -> bool:
	var probe := body_size.x * 0.5 + LEDGE_PROBE
	var from := global_position + Vector2(direction * probe, body_size.y * 0.4)
	var query := PhysicsRayQueryParameters2D.create(
		from, from + Vector2(0.0, LEDGE_DEPTH), Layers.WORLD
	)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty() == false


## Ultima linha de defesa. Se o inimigo mesmo assim cair -- knockback forte,
## plataforma que o designer removeu, bug em outra parte -- ele volta para
## casa em vez de morrer em silencio e sumir do jogo.
func _guard_offscreen() -> void:
	if flies or fall_limit <= 0.0:
		return
	if global_position.y <= _home.y + fall_limit:
		return
	global_position = _home
	velocity = Vector2.ZERO
	_set_state(State.IDLE)


func _track_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_on_landed()
	_was_on_floor = on_floor


## Ponto de extensao: chamado no instante em que o corpo encosta no chao.
## Quem nao tem chao (voador) nao sobrescreve.
func _on_landed() -> void:
	pass


## Ponto de extensao: o corpo voa e ignora a gravidade?
##
## Padrao falso (todo inimigo cai). O voador liga isso e sobrescreve apenas
## [method _apply_vertical] -- ver `bat.gd`. Existe como propriedade para
## que a base saiba nao puxar o corpo para baixo.
@export var flies := false:
	set(value):
		flies = value
		if value:
			# Sem isso o motor gruda o voador na plataforma mais proxima.
			floor_snap_length = 0.0


## Gravidade. Subclasses sobrescrevem para ter uma locomocao diferente.
##
## `get_gravity()` devolve (0,0) sem "Custom Gravity" ligado no Project
## Settings > Physics > 2D, entao lemos o valor do projeto como fallback.
func _apply_vertical(delta: float) -> void:
	if flies:
		# Sem gravidade, mas com arrasto: evita velocidade vertical infinita
		# quando o knockback empurra o corpo para cima.
		velocity.y = move_toward(velocity.y, 0.0, AIR_DRAG * delta)
		return

	# `get_gravity().y` pode vir negativo; a gravidade tem de ser positiva,
	# senao `velocity.y += g` desacelera a subida em vez de puxar para baixo.
	#
	# O `* delta` e obrigatorio: sem ele a gravidade entrava inteira a cada
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
		State.AIM:
			_stop(delta, 900.0)
			# Janela de leitura para o jogador: o inimigo fica parado,
			# encarando. Ao fim dela, dispara e entra em ATTACK, que é a
			# recuperacao curta antes de voltar a perseguir.
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
				_set_state(State.CHASE if _sees_target(forget_range) else State.PATROL)


func _stop(delta: float, acceleration: float = STOP_ACCELERATION) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)


func _patrol(delta: float) -> void:
	velocity.x = move_toward(
		velocity.x, signf(_patrol_target_x - global_position.x) * patrol_speed, 700.0 * delta
	)
	if absf(global_position.x - _patrol_target_x) < PATROL_TOLERANCE:
		_patrol_target_x = patrol_left_x() if _patrol_target_x == patrol_right_x() else patrol_right_x()
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
		_set_state(State.AIM)
	elif leash_radius > 0.0 and global_position.distance_to(_home) > leash_radius:
		# Esticou a corda demais: volta para casa em vez de atravessar a
		# fase inteira atrás de um jogador que fugiu.
		_set_state(State.PATROL)


## Dispara um [Projectile]. Subclasses que atiram sobrescrevem isto; o
## padrão erra o tiro para não ter projétil em todo inimigo.
## Dispara o ataque. Padrao: golpe corpo a corpo, ligando a hitbox.
## Quem atira a distancia sobrescreve e cria um [Projectile].
func _fire() -> void:
	_hitbox.activate()
	_hitbox_timer = HITBOX_ACTIVE_TIME
	velocity.x = _facing * attack_lunge


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
	elif next == State.AIM:
		# Telegrafia: congela e prepara a mira. O tiro sai em `_fire`.
		_hitbox.deactivate()
		velocity.x = 0.0
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
	_invuln_timer = STAGGER_TIME
	_hurtbox.invulnerable = true

	# Hitstop e numero de dano valem para os dois lados da briga: o golpe que
	# o player leva e o golpe que ele da precisam pesar igual, senao o jogo
	## premia o jogador por bater em algo.
	var frames := int(round(lerpf(1.0, 3.0, clampf(float(amount) / 3.0, 0.0, 1.0))))
	Hitstop.trigger(frames)
	FloatingNumber.spawn(get_tree().current_scene, global_position, amount, HIT_NUMBER_COLOR)
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

	# O estouro nasce solto na cena, e nao como filho do inimigo: a explosao
	# tem que continuar depois que queue_free leva o corpo embora.
	ParticlePreset.spawn_burst(get_tree().current_scene, global_position, _sprite.color)

	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(0.7, 0.7, 0.7, 0.0), 0.45)
	tween.parallel().tween_property(_sprite, "scale", Vector2(1.3, 0.7), 0.45)
	tween.tween_callback(queue_free)
