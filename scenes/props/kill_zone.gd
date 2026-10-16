extends Area2D
## Zona de dano instantaneo: tira vida e devolve o jogador ao SpawnPoint.
## Exportada como `damage` para permitir zonas "de aviso" com dano baixo.

@export var damage: int = 25
@export var respawn_delay := 0.25

@onready var _spawn_point: Marker2D = get_parent().get_node_or_null(^"SpawnPoint")


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return

	GameState.take_damage(damage)

	await get_tree().create_timer(respawn_delay).timeout
	if not is_instance_valid(body) or not is_instance_valid(self):
		return

	var destination := _spawn_point.global_position if _spawn_point != null else global_position
	if body.has_method(&"teleport_to"):
		body.teleport_to(destination)
	else:
		body.global_position = destination