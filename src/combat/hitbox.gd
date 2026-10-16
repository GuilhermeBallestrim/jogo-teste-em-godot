class_name Hitbox
extends Area2D
## Area que *causa* dano.
##
## O deteccao roda no sentido inverso: a Hurtbox e que monitora a camada
## [constant Layers.HITBOX] e chama `apply_damage()` no seu dono. Assim o
## alvo -- e nao o atacante -- decide i-frames, equipe e imortalidade.

signal hit(hurtbox: Area2D)

@export var damage: int = 10
@export var knockback: float = 340.0
## Quando falso a hitbox nao e colidavel (mas continua visivel).
@export var active: bool = false:
	set(value):
		active = value
		if is_inside_tree():
			set_deferred(&"monitorable", value)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = active


## Liga a hitbox. Quem desliga e o dono (via [method deactivate]).
func activate() -> void:
	active = true


func deactivate() -> void:
	active = false


## Chamado pela Hurtbox quando este golpe efetivamente conecta.
func notify_hit(hurtbox: Area2D) -> void:
	hit.emit(hurtbox)