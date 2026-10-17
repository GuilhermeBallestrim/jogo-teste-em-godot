class_name Boss
extends Enemy
## Boss Redesenhado: Fases Claras, Telegraphing Visual, Fairness
##
## Design: 3 Fases Distintas, Sempre Hittable (exceto breves i-frames),
## Telegraphing Visual Claro, Fases Progressivas.
##
## Fase 1 (100% - 67% HP): Básico - Slam + Projéteis Simples
## Fase 2 (66% - 34% HP): Agressivo - Charge + Barrage Múltiplo
## Fase 3 (33% - 0% HP): Desesperado - Combo Slam + Barrage + Dash

const PROJECTILE_SCENE := "res://scenes/props/projectile.tscn"

## Configurações Balanceadas
@export var slam_radius := 160.0
@export var slam_damage := 2
@export var barrage_count_phase1 := 3
@export var barrage_count_phase2 := 5
@export var barrage_count_phase3 := 7
@export var charge_speed := 300.0
@export var melee_range := 80.0
@export var melee_damage := 3

## Interno
var _phase := 1
var _attack_timer := 0.0
var _next_attack := 0
var _combo_step := 0

## Estados Simplificados (herdados + VULNERABLE)
## IDLE, ATTACK, VULNERABLE, STAGGER, DEAD

func _ready() -> void:
	body_color = Color(0.55, 0.15, 0.55)
	super._ready()
	
	max_health = 35
	health = 35
	detect_range = 9999.0
	forget_range = 9999.0
	attack_range = 9999.0
	chase_speed = 0.0
	patrol_speed = 0.0
	leash_radius = 0.0
	contact_damage = 2
	
	Music.play(-12.0, &"boss")
	_set_state(State.IDLE)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if state == State.DEAD:
		return
	
	# Sempre virar para o jogador
	if _target != null:
		_facing = signf(_target.global_position.x - global_position.x)
		_sprite.scale.x = absf(_sprite.scale.x) * _facing
	
	# Atualizar visual baseado na fase/estado
	_update_visual()


func _update_visual() -> void:
	match state:
		State.IDLE:
			_sprite.color = body_color
			_sprite.modulate = Color.WHITE
		State.ATTACK:
			var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.15
			_sprite.color = body_color.lerp(Color(1.0, 0.2, 0.2), 0.6)
			_sprite.modulate = Color(pulse, pulse, pulse)
		State.VULNERABLE:
			_sprite.color = Color(0.2, 1.0, 0.4)
			_sprite.modulate = Color.WHITE
		State.STAGGER:
			_sprite.color = body_color.lerp(Color(0.4, 0.4, 0.4), 0.5)
		State.DEAD:
			pass


func _think(delta: float) -> void:
	if state == State.DEAD:
		return
	
	match state:
		State.IDLE:
			_stop(delta)
			_attack_timer += delta
			if _attack_timer >= _get_attack_interval():
				_start_attack()
				
		State.ATTACK:
			if _execute_current_attack(delta):
				_set_state(State.VULNERABLE)
				
		State.VULNERABLE:
			_stop(delta, 400.0)
			var vuln_time := 2.5 if _phase == 3 else 3.5
			_attack_timer += delta
			if _attack_timer >= vuln_time:
				_attack_timer = 0.0
				_set_state(State.IDLE)

		State.STAGGER:
			_stop(delta, 800.0)
			if _state_timer >= 1.2:
				_set_state(State.IDLE)


## ================================================================
## SISTEMA DE ATAQUES POR FASE
## ================================================================

func _get_phase() -> int:
	if health > max_health * 0.66:
		return 1
	elif health > max_health * 0.33:
		return 2
	return 3


func _get_attack_interval() -> float:
	match _phase:
		1: return 3.0
		2: return 2.2
		3: return 1.5
	return 3.0



func _start_attack() -> void:
	_phase = _get_phase()
	_attack_timer = 0.0
	_combo_step = 0
	
	var attacks := _get_available_attacks()
	if attacks.is_empty():
		_set_state(State.VULNERABLE)
		return
	
	_next_attack = randi() % attacks.size()
	_set_state(State.ATTACK)


func _get_available_attacks() -> Array[int]:
	match _phase:
		1: return [0, 1]
		2: return [0, 1, 2]
		3: return [0, 1, 2, 3]
	return []



func _execute_current_attack(delta: float) -> bool:
	match _next_attack:
		0: return _do_slam(delta)
		1: return _do_projectiles(delta)
		2: return _do_charge(delta)
		3: return _do_combo(delta)
	return true


## ================================================================
## ATAQUE 0: GROUND SLAM (Telegraph: pulo alto + pausa)
## ================================================================

var _slam_phase := 0
var _slam_timer := 0.0
var _slam_done := false

func _do_slam(delta: float) -> bool:
	if _slam_phase == 0:
		velocity.y = -650.0
		_slam_phase = 1
		_slam_timer = 0.0
		return false
		
	elif _slam_phase == 1:
		_slam_timer += delta
		if is_on_floor():
			_do_slam_impact()
			_slam_phase = 2
			_slam_timer = 0.0
		return false
		
	elif _slam_phase == 2:
		_slam_timer += delta
		return _slam_timer >= 0.5
		
	return true


func _do_slam_impact() -> void:
	ParticlePreset.spawn_burst(get_tree().current_scene, global_position, Color(1.0, 0.3, 0.3), 50)
	Hitstop.trigger(5)
	_camera_shake(0.8)
	
	for node in get_tree().get_nodes_in_group("player"):
		var body := node as Node2D
		if body == null: continue
		if global_position.distance_to(body.global_position) <= 180.0:
			var dir := (body.global_position - global_position).normalized()
			if body.has_method("apply_damage"):
				body.call("apply_damage", 3, self, dir, 400.0)
	
	_slam_done = true


## ================================================================
## ATAQUE 1: PROJÉTEIS EM LEQUE (Telegraph: levantar "braço" + brilho)
## ================================================================

var _proj_step := 0
var _proj_timer := 0.0
var _proj_count := 0

func _do_projectiles(delta: float) -> bool:
	if _proj_step == 0:
		_proj_timer = 0.0
		_proj_step = 1
		_proj_count = _get_proj_count()
		return false
		
	elif _proj_step == 1:
		_proj_timer += delta
		if _proj_timer >= 0.8:
			_fire_projectile(_proj_count)
			_proj_count -= 1
			_proj_timer = 0.0
			if _proj_count <= 0:
				_proj_step = 2
		return false
		
	elif _proj_step == 2:
		return true
		
	return false


func _get_proj_count() -> int:
	match _phase:
		1: return 3
		2: return 5
		3: return 7
	return 3



func _fire_projectile(_index: int) -> void:
	var packed := load(PROJECTILE_SCENE) as PackedScene
	if packed == null or _target == null: return
	
	var proj_dir := (_target.global_position - global_position).normalized()
	var spread := 0.6
	var angle_offset := (float(_proj_count) / 2.0 - float(_index)) * spread
	var dir := Vector2(cos(angle_offset), sin(angle_offset)).normalized()
	
	var layer := get_tree().current_scene
	if layer == null: layer = self
	
	var proj := packed.instantiate() as Node2D
	if proj == null: return
	
	layer.add_child(proj)
	proj.global_position = global_position
	if proj.has_method("launch"):
		proj.call("launch", dir, 450.0)


## ================================================================
## ATAQUE 2: CHARGE (Telegraph: agachar + brilho + som)
## ================================================================

var _charge_phase := 0
var _charge_timer := 0.0

func _do_charge(delta: float) -> bool:
	if _charge_phase == 0:
		_charge_phase = 1
		_charge_timer = 0.0
		_camera_shake(0.3)
		return false
		
	elif _charge_phase == 1:
		_charge_timer += delta
		if _charge_timer >= 1.0:
			_charge_phase = 2
			velocity.x = _facing * charge_speed
			_charge_timer = 0.0
			_camera_shake(0.6)
			return false
			
	elif _charge_phase == 2:
		_charge_timer += delta
		if _charge_timer >= 0.6 or is_on_wall():
			velocity.x = 0.0
			return true
		return false
		
	return false


## ================================================================
## ATAQUE 3: COMBO SLAM + CHARGE (Fase 3 only)
## ================================================================

func _do_combo(delta: float) -> bool:
	match _combo_step:
		0:
			if _do_slam(delta):
				_combo_step = 1
			return false
		1:
			if _state_timer >= 0.3:
				_combo_step = 2
			return false
		2:
			return _do_charge(delta)
	return false


## ================================================================
## UTILITÁRIOS
## ================================================================

func _camera_shake(intensity: float) -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var body := node as Node2D
		if body == null: continue
		var cam := body.get_node_or_null("Camera2D/CameraShake")
		if cam != null and cam.has_method("shake_for"):
			cam.call("shake_for", intensity)


func _camera_shake_for_boss() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var body := node as Node2D
		if body == null: continue
		var cam := body.get_node_or_null("Camera2D/CameraShake")
		if cam != null and cam.has_method("shake_for"):
			cam.call("shake_for", 1.2)


func _flash() -> void:
	_sprite.modulate = Color(1.5, 1.5, 1.5)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)


func apply_damage(amount: int, source: Node, direction: Vector2, knockback: float) -> void:
	if state == State.DEAD:
		return
	super.apply_damage(amount, source, direction, knockback)
	_flash()
	Hitstop.trigger(2)


func _die(source: Node) -> void:
	state = State.DEAD
	_hurtbox.invulnerable = true
	_hitbox.deactivate()
	collision_layer = 0
	velocity = Vector2.ZERO
	GameState.add_score(800)
	Sfx.play("enemy_die", -4.0)
	ParticlePreset.spawn_burst(get_tree().current_scene, global_position, body_color, 80)
	died.emit(self)
	
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(0.7, 0.7, 0.7, 0.0), 1.5)
	tween.parallel().tween_property(_sprite, "scale", Vector2(1.8, 0.3), 1.5)
	tween.tween_callback(queue_free)
