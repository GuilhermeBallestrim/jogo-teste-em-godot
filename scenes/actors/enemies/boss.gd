class_name Boss
extends Enemy
## Boss: inimigo final com padroes de ataque.
##
## Reusa o FSM do [Enemy] mas sobrescreve `_think` para ter estados proprios:
## IDLE (espera), SLAM (onda de choque), BARRAGE (rajada de projeteis),
## CHARGE (carga), VULNERABLE (janela de dano), STAGGER (recuperacao).
##
## O boss nao patrulha: fica no centro da arena e ataca. O jogador so causa
## dano durante VULNERABLE.

const PROJECTILE_SCENE := "res://scenes/props/projectile.tscn"

@export var slam_radius := 180.0
@export var slam_damage := 2
@export var barrage_count := 5
@export var charge_speed := 420.0

var _pattern := 0
var _vulnerable_timer := 0.0
var _slam_done := false

func _ready() -> void:
	body_color = Color(0.55, 0.2, 0.55)
	super._ready()
	Music.play(-10.0, &"boss")
	max_health = 20
	health = max_health
	detect_range = 9999.0
	forget_range = 9999.0
	attack_range = 9999.0
	chase_speed = 0.0
	patrol_speed = 0.0
	leash_radius = 0.0
	# O boss nao patrulha: fica no posto.
	_set_state(State.IDLE)


func _think(delta: float) -> void:
	match state:
		State.IDLE:
			_stop(delta)
			if _state_timer >= 1.2:
				_start_next_pattern()
		State.ATTACK:
			# SLAM: onda de choque radial.
			_stop(delta, 1400.0)
			if _state_timer >= 0.1 and not _slam_done:
				_slam_done = true
				_do_slam()
			if _state_timer >= 0.6:
				_set_state(State.VULNERABLE)
				_vulnerable_timer = 2.0
		State.AIM:
			# BARRAGE: rajada de projeteis.
			_stop(delta, 900.0)
			if _state_timer >= 0.8:
				_do_barrage()
				_set_state(State.VULNERABLE)
				_vulnerable_timer = 2.0
		State.CHASE:
			# CHARGE: carga em direcao ao jogador.
			if _target != null:
				var to_target := _target.global_position.x - global_position.x
				_facing = signf(to_target) if to_target != 0.0 else _facing
				velocity.x = move_toward(velocity.x, _facing * charge_speed, 1200.0 * delta)
			if _state_timer >= 0.7:
				velocity = Vector2.ZERO
				_set_state(State.VULNERABLE)
				_vulnerable_timer = 1.5
		State.VULNERABLE:
			_stop(delta, 600.0)
			_vulnerable_timer -= delta
			if _vulnerable_timer <= 0.0:
				_set_state(State.STAGGER)
		State.STAGGER:
			_stop(delta, 800.0)
			if _state_timer >= 0.6:
				_set_state(State.IDLE)

func _start_next_pattern() -> void:
	_pattern = (_pattern + 1) % 3
	_slam_done = false
	match _pattern:
		0:
			_set_state(State.ATTACK)
		1:
			_set_state(State.AIM)
		2:
			_set_state(State.CHASE)


func _do_slam() -> void:
	# Onda de choque radial: dano ao jogador se estiver no raio.
	var players := get_tree().get_nodes_in_group(&"player")
	for node in players:
		var body := node as Node2D
		if body == null:
			continue
		if global_position.distance_to(body.global_position) <= slam_radius:
			var direction := (body.global_position - global_position).normalized()
			if body.has_method(&"apply_damage"):
				body.call(&"apply_damage", slam_damage, self, direction, 300.0)
	# Particulas de impacto.
	ParticlePreset.spawn_burst(get_tree().current_scene, global_position, body_color, 40)
	Hitstop.trigger(4)
	_camera_shake_for_boss()


func _do_barrage() -> void:
	var packed := load(PROJECTILE_SCENE) as PackedScene
	if packed == null:
		return
	if _target == null:
		return
	for i in barrage_count:
		var proj := packed.instantiate() as Node2D
		if proj == null:
			continue
		var angle := (float(i) / float(barrage_count - 1) - 0.5) * 1.2
		var dir := Vector2(cos(angle), sin(angle)).normalized()
		if _target.global_position.x < global_position.x:
			dir.x = -absf(dir.x)
		var layer := get_tree().current_scene
		if layer == null:
			layer = self
		layer.add_child(proj)
		proj.global_position = global_position
		if proj.has_method(&"launch"):
			proj.call(&"launch", dir, 400.0)


func _camera_shake_for_boss() -> void:
	# O boss tem sua propria camera shake (mais forte).
	for node in get_tree().get_nodes_in_group(&"player"):
		var body := node as Node2D
		if body == null:
			continue
		var cam := body.get_node_or_null(^"Camera2D/CameraShake")
		if cam != null and cam.has_method(&"shake_for"):
			cam.call(&"shake_for", 1.0)


func apply_damage(amount: int, source: Node, direction: Vector2, knockback: float) -> void:
	if state == State.DEAD:
		return
	# So toma dano durante VULNERABLE.
	if state != State.VULNERABLE:
		# Flash de "nao afeta".
		_flash()
		return
	super.apply_damage(amount, source, direction, knockback)
	# Knockback reduzido: o boss nao deve ser empurrado para fora da arena.
	velocity *= 0.3


func _die(source: Node) -> void:
	state = State.DEAD
	_hurtbox.invulnerable = true
	_hitbox.deactivate()
	collision_layer = 0
	velocity = Vector2.ZERO
	GameState.add_score(500)
	Sfx.play(&"enemy_die", -4.0)
	ParticlePreset.spawn_burst(get_tree().current_scene, global_position, body_color, 60)
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(0.7, 0.7, 0.7, 0.0), 1.0)
	tween.parallel().tween_property(_sprite, "scale", Vector2(1.5, 0.5), 1.0)
	tween.tween_callback(queue_free)