class_name LevelBounds
extends Node2D
## Limites jogáveis da fase: onde a fase começa e onde ela acaba.
##
## Antes disso cada fase repetia a mesma informação em três lugares que podiam
## divergir -- a parede invisível (quando existia), o `camera_limits` do
## [LevelBase] e o `KillZone`. Quando um deles ficava para trás, o jogador
## saía andando para fora do mapa, ou a câmera mostrava o nada, ou o buraco
## mortífero ficava curto demais.
##
## Aqui os três saem da mesma declaração:
##
##     Bounds (Node2D, este script)
##       `-- 4 paredes invisiveis na camada WORLD
##
## E o [LevelBase] lê o retângulo daqui para montar os limites da câmera.

## Parede invisible: grossa o bastante para o corpo não atravessar num quadro
## nem em 4K, fina o bastante para não aparecer.
const WALL_THICKNESS := 96.0

@export_group("Limites")
## Extremo esquerdo do campo jogável, em X de mundo.
@export var left_x := -1200.0
@export var right_x := 1200.0
## Teto do campo jogável. Acima daqui não há nada — a câmera não sobe mais.
@export var top_y := -800.0
## Base do campo jogável. Abaixo daqui é o `KillZone`.
@export var bottom_y := 200.0


func _ready() -> void:
	_build_walls()


## O campo jogável como retângulo, do ponto mais alto à esquerda ao mais
## baixo à direita.
func rect() -> Rect2:
	return Rect2(
		Vector2(left_x, top_y),
		Vector2(right_x - left_x, bottom_y - top_y)
	)


func contains(point: Vector2) -> bool:
	return rect().has_point(point)


func _build_walls() -> void:
	for child in get_children():
		child.queue_free()

	var box := rect()
	_wall(
		"WallLeft",
		Vector2(left_x - WALL_THICKNESS * 0.5, box.position.y + box.size.y * 0.5),
		Vector2(WALL_THICKNESS, box.size.y)
	)
	_wall(
		"WallRight",
		Vector2(right_x + WALL_THICKNESS * 0.5, box.position.y + box.size.y * 0.5),
		Vector2(WALL_THICKNESS, box.size.y)
	)
	_wall(
		"WallTop",
		Vector2(box.position.x + box.size.x * 0.5, top_y - WALL_THICKNESS * 0.5),
		Vector2(box.size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS)
	)
	# Sem parede embaixo: quem cai tem de chegar no `KillZone`, que cobra a
	# vida e devolve ao checkpoint. Uma parede aqui transformaria toda queda
	# em morte instantânea e tiraria o checkpoint de função.


func _wall(node_name: StringName, center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = center

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	add_child(body)