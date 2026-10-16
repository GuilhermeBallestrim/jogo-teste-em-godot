class_name Checkpoint
extends Area2D
## Bandeira de respawn. Ao ser tocada, grava no [GameState] o ponto para onde
## o jogador volta quando cai na [KillZone].

signal activated(checkpoint: Checkpoint)

const RESPAWN_FLAG := &"respawn"

## Deslocamento do ponto de respawn em relacao ao centro da bandeira.
@export var respawn_offset := Vector2(0, -46)

var is_active := false

@onready var _pole: Polygon2D = $Pole
@onready var _flag: Polygon2D = $Pole/Flag
@onready var _beam: Polygon2D = $Beam


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)
	_set_active(false)


func respawn_position() -> Vector2:
	return global_position + respawn_offset


func _on_body_entered(body: Node2D) -> void:
	if is_active or not body.is_in_group(&"player"):
		return
	GameState.set_flag(RESPAWN_FLAG, respawn_position())
	_set_active(true)
	Sfx.play(&"checkpoint", -4.0)
	activated.emit(self)


func _set_active(value: bool) -> void:
	is_active = value
	var tint := Color(0.376, 0.878, 0.612) if value else Color(0.42, 0.46, 0.55)
	_flag.color = tint
	_beam.color = Color(tint.r, tint.g, tint.b, 0.22 if value else 0.08)
	_beam.visible = value

	if value:
		_flag.scale = Vector2(0.2, 1.0)
		var tween := create_tween()
		tween.tween_property(_flag, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)