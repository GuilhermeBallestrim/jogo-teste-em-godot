extends Enemy
## Explosivo: ao morrer, danifica tudo num raio.
##
## O dano nao vem de `Hitbox`: e um dano direto em `apply_damage` no instante
## da morte. Existe para exercitar o caminho de dano que nao passa por hitbox,
## e para dar um motivo para o jogador nao matar o inimigo colado nele.

@export var explosion_radius := 110.0
@export var explosion_damage := 15

func _ready() -> void:
	body_color = Color(0.85, 0.22, 0.18)
	super._ready()


func _die(source: Node) -> void:
	# Dano radial antes de sumir. O jogador colado leva o golpe; quem esta
	# longe nao. O dano e direto em `apply_damage`, porque o Area2D de
	# explosao nao existe como cena: montar uma cena para um efeito que dura
	# 0.1 s seria mais codigo do que o efeito.
	for node in get_tree().get_nodes_in_group(&"player"):
		var body := node as Node2D
		if body == null:
			continue
		if global_position.distance_to(body.global_position) > explosion_radius:
			continue
		var direction := (body.global_position - global_position).normalized()
		if body.has_method(&"apply_damage"):
			body.call(&"apply_damage", explosion_damage, self, direction, 260.0)
	super._die(source)