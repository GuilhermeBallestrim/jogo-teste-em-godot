class_name Projectile
extends Area2D
## Projétil reaproveitando o sistema de combate existente.
##
## É uma [Hitbox] voando: ao encostar numa [Hurtbox] causa dano e se
## destrói. Não nasce com lógica de dano própria -- o estrago vem do mesmo
## caminho do golpe corpo a corpo, então i-frames, imunidade e knockback
## funcionam igual sem uma linha duplicada.
##
## A detecção roda no sentido inverso (é a [Hurtbox] que monitora a camada
## [constant Layers.HITBOX]), então este corpo **não** escuta `area_entered`
## para saber que acertou: ele escuta o sinal [signal Hitbox.hit].

const SPEED := 420.0
## Tempo máximo de vida antes de se auto-destruir, para não vazar um objeto
## que passou por cima da tela.
const LIFETIME := 3.0

@export var damage := 1
@export var knockback := 260.0
@export var speed := SPEED

## Direção normalizada do voo. Definida por [method aim] no instante do tiro.
var direction := Vector2.RIGHT

@onready var _hitbox: Hitbox = $Hitbox


func _ready() -> void:
	add_to_group(&"projectiles")

	_hitbox.damage = damage
	_hitbox.knockback = knockback
	# O projétil monitora corpos sólidos (paredes, chão) para não atravessar.
	monitoring = true
	monitorable = false
	collision_mask = Layers.WORLD

	# Acertou um alvo: a [Hurtbox] já aplicou o dano, aqui só somo.
	_hitbox.hit.connect(_dispose)
	body_entered.connect(_on_body_entered)

	_hitbox.activate()
	rotation = direction.angle()

	var tween := create_tween()
	tween.tween_interval(LIFETIME)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	# Area2D não tem movimento próprio: empurro a posição à mão.
	global_position += direction * speed * delta


## Ajusta a mira. Chamado pelo inimigo no instante do tiro, depois de o nó
## estar na árvore -- senão `rotation` seria sobrescrito pelo `_ready`.
func aim(towards: Vector2) -> void:
	direction = towards.normalized()
	rotation = direction.angle()


func _on_body_entered(_body: Node2D) -> void:
	# Bateu em parede ou plataforma: some.
	_dispose()


func _dispose(_hurtbox: Area2D = null) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	Sfx.play(&"swing", -14.0)
	queue_free()