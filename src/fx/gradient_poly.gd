class_name GradientPoly
extends RefCounted
## Gradiente procedural em [Polygon2D], sem arquivo de imagem.
##
## `Polygon2D` nao tem gradiente nativo, mas tem `vertex_colors`: uma cor por
## vertice. Basta calcular a cor de cada vertice a partir da sua posicao e
## a forma vira um gradiente. Isto e o que faz a arte "geometrica em codigo"
## parar de parecer chapada, sem sair do zero-assets.

## Aplica um gradiente vertical (topo -> base) a um `Polygon2D`.
## `top` e a cor do topo, `bottom` a do fundo. A interpolacao e linear por
## altura, e o meio fica em `lerp(top, bottom, 0.5)`.
static func vertical(poly: Polygon2D, top: Color, bottom: Color) -> void:
	if poly == null or poly.polygon.is_empty():
		return
	var ys := PackedFloat32Array()
	var min_y := 1e9
	var max_y := -1e9
	for v in poly.polygon:
		ys.append(v.y)
		min_y = minf(min_y, v.y)
		max_y = maxf(max_y, v.y)
	var range_y := maxf(max_y - min_y, 1.0)
	var colors := PackedColorArray()
	colors.resize(poly.polygon.size())
	for i in poly.polygon.size():
		var t := (poly.polygon[i].y - min_y) / range_y
		colors[i] = top.lerp(bottom, t)
	poly.vertex_colors = colors


## Aplica um gradiente radial (centro -> borda).
static func radial(poly: Polygon2D, center_color: Color, edge_color: Color) -> void:
	if poly == null or poly.polygon.is_empty():
		return
	var max_r := 0.0
	for v in poly.polygon:
		max_r = maxf(max_r, v.length())
	max_r = maxf(max_r, 1.0)
	var colors := PackedColorArray()
	colors.resize(poly.polygon.size())
	for i in poly.polygon.size():
		var t := poly.polygon[i].length() / max_r
		colors[i] = center_color.lerp(edge_color, t)
	poly.vertex_colors = colors


## Sombra projetada: um `Polygon2D` mais escuro, deslocado para baixo e para
## o lado, filho do no pai. Retorna o no criado para quem quiser animar.
static func shadow(parent: Node2D, polygon: PackedVector2Array, offset: Vector2, color: Color) -> Polygon2D:
	var sh := Polygon2D.new()
	sh.polygon = polygon
	sh.color = color
	sh.position = offset
	sh.z_index = -1
	parent.add_child(sh)
	parent.move_child(sh, 0)
	return sh