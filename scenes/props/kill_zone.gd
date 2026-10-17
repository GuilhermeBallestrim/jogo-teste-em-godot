extends Area2D
## Zona de dano: tira vida e devolve o jogador ao ultimo checkpoint ativado
## (ou ao SpawnPoint da cena, se nenhum foi tocado). Se a vida chegar a zero,
## o jogador morre em vez de respawnar.

@export var damage: int = 25
@export var respawn_delay := 0.25

@onready var _spawn_point: Marker2D = get_parent().get_node_or_null(^"SpawnPoint")

var _busy := false


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	if _busy:
		return
	_busy = true

	GameState.take_damage(damage)
	Sfx.play(&"hurt", -6.0)

	await get_tree().create_timer(respawn_delay).timeout
	if not is_instance_valid(body) or not is_instance_valid(self):
		_busy = false
		return

	if not GameState.is_alive():
		# Vida zerou: morre de verdade, nao respawnar.
		if body.has_method(&"_die"):
			body.call(&"_die")
		_busy = false
		return

	if body.has_method(&"teleport_to"):
		body.teleport_to(_respawn_position())
	else:
		body.global_position = _respawn_position()

	_busy = false


## Prioridade: checkpoint salvo no GameState > SpawnPoint da cena > propria posicao.
func _respawn_position() -> Vector2:
	var stored: Variant = GameState.get_flag(Checkpoint.RESPAWN_FLAG)
	if stored is Vector2:
		return stored
	if _spawn_point != null:
		return _spawn_point.global_position
	return global_position