class_name ParticlePreset
extends RefCounted
## Presets de particula reaproveitados por player e inimigos.
##
## Sao funcoes estaticas que configuram um `CPUParticles2D` que ja existe na
## cena, em vez de parametro guardado no `.tscn`. O motivo e repeticao: quatro
## emissores com quinze campos cada seriam sessenta linhas quase iguais em
## arquivos que ninguem abre com frequencia. Aqui mudar a poeira e uma linha.
##
## O que o preset NAO define de proposito:
##
## - **geometria de emissao** (`emission_shape`, `emission_rect_extents`): o
##   `.tscn` mostra onde o emissor esta no corpo, e isso e assunto do layout
## - **`z_index`**: cada ator decide onde a particula entra na ordem de desenho
##
## Nenhuma textura. O projeto nao tem arte em disco e nao vai ganhar agora --
## `CPUParticles2D` sem textura desenha o quadradinho solido na cor do
## emissor, o que serve para poeira, respingo e rastro.

## Poeira dos pes. Continua enquanto o corpo corre, e cada particula fica no
## mundo -- se `local_coords` fosse verdadeiro a poeira andaria junto com o
## player, que e exatamente o efeito contrario do desejado.
static func dust(node: CPUParticles2D) -> CPUParticles2D:
	node.emitting = false
	node.local_coords = false
	node.amount = 14
	node.lifetime = 0.55
	node.randomness = 0.5
	node.direction = Vector2(0, -1)
	node.spread = 55.0
	node.gravity = Vector2(0, 150)
	node.initial_velocity_min = 15.0
	node.initial_velocity_max = 55.0
	node.damping_min = 30.0
	node.damping_max = 70.0
	node.scale_amount_min = 2.0
	node.scale_amount_max = 4.5
	node.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	node.emission_rect_extents = Vector2(11.0, 2.0)
	_tint(node, Color(0.82, 0.85, 0.9), 0.55)
	return node


## Respingo do pouso. Sai para os dois lados, achatado, e morre rapido: e o
## recado do impacto, nao uma coluna de fumaça.
static func splash(node: CPUParticles2D) -> CPUParticles2D:
	_one_shot(node)
	node.amount = 14
	node.lifetime = 0.32
	node.direction = Vector2(0, -1)
	node.spread = 78.0
	node.gravity = Vector2(0, 420)
	node.initial_velocity_min = 120.0
	node.initial_velocity_max = 250.0
	node.scale_amount_min = 1.5
	node.scale_amount_max = 3.5
	node.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	node.emission_rect_extents = Vector2(12.0, 2.0)
	_tint(node, Color(0.9, 0.92, 0.95), 0.75)
	return node


## Rastro do dash. O `direction` e reescrito pelo player a cada quadro, porque
## o dash pode ser para os quatro lados e um preset fixo so funcionaria em um.
static func trail(node: CPUParticles2D) -> CPUParticles2D:
	node.emitting = false
	node.local_coords = false
	node.amount = 34
	node.lifetime = 0.42
	node.randomness = 0.25
	node.direction = Vector2(-1, 0)
	node.spread = 25.0
	node.gravity = Vector2.ZERO
	node.initial_velocity_min = 0.0
	node.initial_velocity_max = 25.0
	node.damping_min = 0.0
	node.damping_max = 10.0
	node.scale_amount_min = 4.0
	node.scale_amount_max = 8.0
	node.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	node.emission_sphere_radius = 7.0
	# Encolhe em vez de sumir: o rastro afina e so fica o risco. Some de uma
	# vez no fim da vida e o corte fica visivel.
	node.scale_amount_curve = _curve([[0.0, 1.0], [0.35, 0.7], [1.0, 0.0]])
	_tint(node, Color(0.45, 0.78, 1.0), 0.95)
	return node


## Estouro radial: usada na morte do inimigo.
static func burst(node: CPUParticles2D, tint: Color) -> CPUParticles2D:
	_one_shot(node)
	node.amount = 20
	node.lifetime = 0.5
	node.direction = Vector2(0, -1)
	node.spread = 180.0
	node.gravity = Vector2(0, 240)
	node.initial_velocity_min = 90.0
	node.initial_velocity_max = 280.0
	node.damping_min = 40.0
	node.damping_max = 120.0
	node.angular_velocity_min = -220.0
	node.angular_velocity_max = 220.0
	node.scale_amount_min = 2.0
	node.scale_amount_max = 5.0
	node.scale_amount_curve = _curve([[0.0, 0.6], [0.2, 1.0], [1.0, 0.0]])
	node.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	node.emission_sphere_radius = 6.0
	_tint(node, tint, 0.95)
	return node


## Cria e solta um estouro de uma vez.
##
## Existe como metodo de fabrica, e nao como no dentro da cena do inimigo,
## porque a explosao tem que continuar depois que o inimigo some. A cena de
## morte dura 0.45 s e depois chama `queue_free`; um emissor filho morreria
## junto, e o jogador veria a explosao engolir.
## [param parent] Onde pendurar. A cena corrente quando existir, senão o
## próprio nó -- um emissor solto não serve para nada.
## Estouro de moeda: dourado, radial, curto.
static func coin_burst(node: CPUParticles2D) -> CPUParticles2D:
	_one_shot(node)
	node.amount = 16
	node.lifetime = 0.4
	node.direction = Vector2(0, -1)
	node.spread = 180.0
	node.gravity = Vector2(0, 200)
	node.initial_velocity_min = 60.0
	node.initial_velocity_max = 180.0
	node.scale_amount_min = 2.0
	node.scale_amount_max = 4.0
	node.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	node.emission_sphere_radius = 4.0
	_tint(node, Color(0.976, 0.831, 0.376), 0.95)
	return node

## Cria e solta um estouro de moeda.
static func spawn_coin_burst(parent: Node, world_position: Vector2) -> CPUParticles2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var layer: Node = parent.get_tree().current_scene
	if layer == null:
		layer = parent
	var node := CPUParticles2D.new()
	coin_burst(node)
	node.z_index = 35
	layer.add_child(node)
	node.global_position = world_position
	node.emitting = true
	return node

static func spawn_burst(parent: Node, world_position: Vector2, tint: Color, count: int = 20) -> CPUParticles2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var layer: Node = parent.get_tree().current_scene
	if layer == null:
		layer = parent
	var node := CPUParticles2D.new()
	burst(node, tint)
	node.amount = maxi(1, count)
	node.z_index = 35
	layer.add_child(node)
	# `global_position` so existe depois que o no entrou na arvore. Atribuir
	# `position` antes disso daria a posicao local do pai, que aqui e o
	# jogador -- o numero flutuante nasceria em cima do personagem.
	node.global_position = world_position
	node.emitting = true
	return node


static func _one_shot(node: CPUParticles2D) -> void:
	node.emitting = false
	node.one_shot = true
	node.explosiveness = 1.0
	node.local_coords = false
	node.randomness = 0.4


## Cor com rampa de transparencia. `color` fica branco de proposito: a rampa
## multiplica por ele, e um `color` ja tingido escurece a rampa duas vezes.
static func _tint(node: CPUParticles2D, tint: Color, peak_alpha: float) -> void:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tint.r, tint.g, tint.b, peak_alpha))
	# Aparece rapido e some devagar: a particula nunca pisca no primeiro quadro.
	ramp.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	ramp.add_point(0.18, Color(tint.r, tint.g, tint.b, peak_alpha))
	node.color = Color.WHITE
	node.color_ramp = ramp


static func _curve(points: Array) -> Curve:
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = 1.0
	for point in points:
		curve.add_point(Vector2(point[0], point[1]))
	return curve