class_name Platform
extends StaticBody2D
## Plataforma solida dimensionada por codigo.
##
## Sem isso, cada plataforma da fase exigiria um par de sub-resources
## (Polygon2D + RectangleShape2D) repetido no `.tscn`. Aqui a fase so declara
## `size` e o node monta o visual e a colisao em [method _ready].

@export var size := Vector2(200, 40)
@export var body_color := Color(0.196, 0.239, 0.294)
@export var top_color := Color(0.329, 0.423, 0.541)
@export var draw_top_edge := true

@onready var _visual: Polygon2D = $Visual
@onready var _edge: Polygon2D = $TopEdge
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	_apply()


func _apply() -> void:
	var half := size * 0.5
	_visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	_visual.color = body_color
	GradientPoly.vertical(_visual, top_color.lightened(0.15), body_color.darkened(0.25))

	var edge_thickness := minf(6.0, half.y)
	_edge.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, -half.y + edge_thickness),
		Vector2(-half.x, -half.y + edge_thickness),
	])
	_edge.color = top_color
	_edge.visible = draw_top_edge

	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect