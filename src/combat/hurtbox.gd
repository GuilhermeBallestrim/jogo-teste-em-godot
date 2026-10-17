class_name Hurtbox
extends Area2D
## Area que *recebe* dano.
##
## Encaminha o golpe para o no dono via `apply_damage(amount, source,
## direction, knockback)`. Se o dono nao implementar esse metodo, o dano e
## simplesmente ignorado.

@export var invulnerable: bool = false:
	set(value):
		invulnerable = value
		if is_inside_tree():
			set_deferred(&"monitoring", not value)


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.HITBOX
	monitorable = false
	# Indicador visual: a hurtbox e invisivel por padrao.
	var visual := ColorRect.new()
	visual.color = Color(0.3, 0.6, 1.0, 0.2)
	visual.size = Vector2(32, 32)
	visual.position = Vector2(-16, -16)
	add_child(visual)
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if invulnerable:
		return

	var hitbox := area as Hitbox
	if hitbox == null or not hitbox.active:
		return

	var direction := global_position.direction_to(hitbox.global_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var victim := get_parent()
	hitbox.notify_hit(self)
	if victim.has_method(&"apply_damage"):
		victim.apply_damage(hitbox.damage, hitbox.get_parent(), direction, hitbox.knockback)