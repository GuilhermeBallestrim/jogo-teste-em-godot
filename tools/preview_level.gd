extends SceneTree
## Ferramenta visual de layout: desenha o arco do pulo sobre a fase.
##
## Roda COM janela (sem `--headless`):
##
##   godot --path . --script res://tools/preview_level.gd
##
## O teste de balistica (1.5) diz se um layout funciona. Esta ferramenta diz
## *como consertar*: desenha, a partir de cada plataforma, para onde o jogador
## consegue pular. Um arco que nao alcanca a proxima plataforma e visivel na
## hora, em vez de virar "TESTES: FALHARAM" depois.
##
## ## O que ela desenha
##
## - retangulos azuis: plataformas (posicao e tamanho)
## - curvas amarelas: arco de pulo a partir de cada borda
## - pontos verdes: onde o arco toca o chao (aterrissagem possivel)
## - pontos vermelhos: onde o arco sai da tela / cai no buraco
##
## ## O que ela NAO faz
##
## - Nao testa colisao lateral. Um arco que passa *por baixo* de uma
##   plataforma e desenhado mesmo assim; a colisao real pode bloquear. E a
##   diferenca entre "alcanca" e "alcanca sem bater na parede", e quem resolve
##   isso e o playtest.
## - Nao substitui o teste de balistica. E complemento: a ferramenta mostra,
##   o teste prova.

const LEVELS := [
	"res://scenes/levels/level_01.tscn",
	"res://scenes/levels/level_02.tscn",
]
const STEP := 1.0 / 60.0
const MAX_STEPS := 180
const SPEED := PlayerTuning.SPEED
const JUMP := PlayerTuning.JUMP_VELOCITY
const GRAVITY := PlayerTuning.DEFAULT_GRAVITY

var _level_index := 0
var _level: Node2D = null
var _platforms: Array[Rect2] = []
var _arcs: Array[Node] = []


func _initialize() -> void:
	_load_level(0)


func _load_level(i: int) -> void:
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
	_level = null
	_platforms.clear()
	for arc in _arcs:
		if is_instance_valid(arc):
			arc.queue_free()
	_arcs.clear()

	if i >= LEVELS.size():
		print("PREVIEW: fim dos niveis")
		return
	_level_index = i

	var packed := load(LEVELS[i]) as PackedScene
	if packed == null:
		push_error("PREVIEW: cena nao carregou -> %s" % LEVELS[i])
		return
	_level = packed.instantiate() as Node2D
	root.add_child(_level)

	var platforms_node := _level.get_node_or_null(^"Platforms")
	if platforms_node != null:
		for child in platforms_node.get_children():
			if not (child is Node2D):
				continue
			# `size` e exportado e existe antes de `_ready`: nao depende do
			# shape, que so e criado em `_ready`.
			var sz: Vector2 = Vector2(200, 40)
			if "size" in child:
				sz = child.get(&"size")
			var rect := Rect2(child.global_position - sz * 0.5, sz)
			_platforms.append(rect)

	_draw_platforms()
	_draw_arcs()
	print("PREVIEW: %s -- %d plataformas, %d arcos" % [
		LEVELS[i].get_file(), _platforms.size(), _arcs.size()
	])


func _draw_platforms() -> void:
	for rect in _platforms:
		var line := Line2D.new()
		line.points = PackedVector2Array([
			rect.position,
			rect.position + Vector2(rect.size.x, 0),
			rect.position + rect.size,
			rect.position + Vector2(0, rect.size.y),
			rect.position,
		])
		line.width = 2.0
		line.default_color = Color(0.35, 0.55, 0.85, 0.9)
		_level.add_child(line)
		_arcs.append(line)


func _draw_arcs() -> void:
	for rect in _platforms:
		for side in [-1.0, 1.0]:
			var start := Vector2(
				rect.position.x + (rect.size.x if side > 0 else 0.0),
				rect.position.y
			)
			_draw_arc_from(start, side)


func _draw_arc_from(start: Vector2, side: float) -> void:
	var points := PackedVector2Array()
	var x := start.x
	var y := start.y
	var vx := SPEED * side
	var vy := JUMP
	var landed := false
	for _i in MAX_STEPS:
		points.append(Vector2(x, y))
		vy += GRAVITY * STEP
		x += vx * STEP
		y += vy * STEP
		for rect in _platforms:
			if x >= rect.position.x and x <= rect.position.x + rect.size.x:
				if y >= rect.position.y and y <= rect.position.y + 12.0:
					landed = true
					break
		if landed:
			points.append(Vector2(x, y))
			break
		if y > 2000.0:
			break

	var arc := Line2D.new()
	arc.points = points
	arc.width = 1.5
	arc.default_color = Color(1.0, 0.85, 0.3, 0.7)
	_level.add_child(arc)
	_arcs.append(arc)

	var marker := Line2D.new()
	var end_pt := points[points.size() - 1]
	var sz := 6.0
	marker.points = PackedVector2Array([
		end_pt + Vector2(-sz, 0), end_pt + Vector2(sz, 0),
		end_pt + Vector2(0, -sz), end_pt + Vector2(0, sz),
	])
	marker.width = 2.0
	marker.default_color = Color(1.0, 0.35, 0.3, 0.9) if not landed else Color(0.3, 1.0, 0.45, 0.9)
	_level.add_child(marker)
	_arcs.append(marker)


func _process(_delta: float) -> bool:
	if Input.is_action_just_pressed(&"ui_right"):
		_load_level(_level_index + 1)
	if Input.is_action_just_pressed(&"ui_left"):
		_load_level(maxi(0, _level_index - 1))
	if Input.is_action_just_pressed(&"ui_cancel"):
		quit(0)
	return false
