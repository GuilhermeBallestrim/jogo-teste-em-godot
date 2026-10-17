extends Enemy
## Arqueiro: para, mira, e dispara um [Projectile].
##
## Diferenca para o slime: `_fire()` cria um projetil em vez de ligar a
## propria hitbox. Todo o resto -- FSM, deteccao, linha de visao, i-frames --
## vem da classe base intocada.
##
## O estado [constant Enemy.State.AIM] existe justamente para isto: sem a
## telegrafia o tiro sairia no mesmo quadro da decisao e o jogador nao teria
## como reagir.

const PROJECTILE_SCENE := "res://scenes/props/projectile.tscn"

@export var projectile_speed := 460.0
@export var projectile_damage := 1
## Tolerancia vertical da mira: o arqueiro só acerta se o alvo estiver
## quase na mesma altura. Evita que ele dispare de longe e para baixo.
@export var aim_tolerance := 90.0
## Alcance maximo do tiro. Acima disso ele apenas persegui.
@export var shoot_range := 340.0

var _muzzle := Vector2.ZERO


func _ready() -> void:
	super._ready()

	# Anda pelo chao, mas nao salta: e um atirador, nao um batedor.
	floor_snap_length = 8.0
	flies = false

	body_size = Vector2(28.0, 34.0)
	body_color = Color(0.396, 0.545, 0.639)
	detect_range = 380.0
	forget_range = 560.0
	attack_range = 320.0
	patrol_speed = 70.0
	chase_speed = 120.0
	max_health = 3
	contact_damage = 0

	_muzzle = Vector2(16.0, -2.0)


func _chase(delta: float) -> void:
	# A distancia de ataque e o alcance do tiro, nao o contato.
	if absf(_target.global_position.x - global_position.x) <= attack_range and _attack_cooldown <= 0.0:
		_set_state(State.AIM)
		return
	super._chase(delta)


func _fire() -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var origin := global_position + Vector2(_muzzle.x * _facing, _muzzle.y)
	var to_target := _target.global_position + Vector2(0, -14) - origin

	# Fora da faixa de altura o tiro erra de proposito: mira precisa ter
	# limites, senao o jogador e punido por estar numa plataforma alta.
	if absf(to_target.y) > aim_tolerance:
		return

	var shot := (load(PROJECTILE_SCENE) as PackedScene).instantiate()
	get_parent().add_child(shot)
	shot.global_position = origin
	shot.speed = projectile_speed
	shot.damage = projectile_damage
	shot.aim(to_target)

	Sfx.play(&"swing", -8.0)
	# Recuo visual: o arqueiro empurra o corpo para tras ao atirar.
	velocity.x = -_facing * 90.0