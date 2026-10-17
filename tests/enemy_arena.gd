class_name EnemyArena
extends Node2D
## Monta uma arena isolada para testar o comportamento do [Enemy].
##
## Sem cena de fase: o teste precisa de chão, um player e (opcionalmente) uma
## parede entre os dois, com controle total sobre posição e tempo.
##
##     var arena := EnemyArena.new()
##     root.add_child(arena)
##     arena.build(true)              # chão + player + slime
##     arena.enemy.global_position = Vector2(220, -20)
##     await arena.settle()
##     ...
##     arena.dispose()

const PLAYER_SCENE := "res://scenes/actors/player/player.tscn"
const SLIME_SCENE := "res://scenes/actors/enemies/slime.tscn"

var floor_body: StaticBody2D
var player: Node2D = null
var enemy: Node2D = null


## Cria chão, player opcional e inimigo. A arena precisa estar na árvore antes.
func build(with_player: bool = true, enemy_scene: String = SLIME_SCENE) -> void:
	floor_body = StaticBody2D.new()
	floor_body.collision_layer = Layers.WORLD
	floor_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 200)
	shape.shape = rect
	shape.position = Vector2(0, 100)
	floor_body.add_child(shape)
	add_child(floor_body)

	if with_player:
		player = (load(PLAYER_SCENE) as PackedScene).instantiate()
		# A camera do player viraria a visao do teste e atrapalharia.
		player.get_node(^"Camera2D").enabled = false
		add_child(player)

	enemy = (load(enemy_scene) as PackedScene).instantiate()
	add_child(enemy)


## Plataforma estreita, para testar beirada: o inimigo nao tem para onde ir
## quando chega na ponta e precisa parar, nao cair.
func build_ledge(width: float = 240.0, with_player: bool = false) -> void:
	floor_body = StaticBody2D.new()
	floor_body.collision_layer = Layers.WORLD
	floor_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 200)
	shape.shape = rect
	shape.position = Vector2(0, 100)
	floor_body.add_child(shape)
	add_child(floor_body)

	if with_player:
		player = (load(PLAYER_SCENE) as PackedScene).instantiate()
		player.get_node(^"Camera2D").enabled = false
		add_child(player)

	enemy = (load(SLIME_SCENE) as PackedScene).instantiate()
	add_child(enemy)


## Topo do chao da arena, em coordenada de mundo. Os corpos restingam com o
## centro `half_height` acima daqui.
func floor_top() -> float:
	return floor_body.position.y


## Muro vertical, para bloquear a linha de visao entre player e inimigo.
func add_wall(x: float, height: float = 400.0) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = Layers.WORLD
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, height)
	shape.shape = rect
	shape.position = Vector2(0, -height * 0.5)
	wall.add_child(shape)
	wall.position = Vector2(x, 0)
	add_child(wall)


## Deixa os corpos assentarem no chão.
func settle(frames: int = 20) -> void:
	for _i in frames:
		await get_tree().physics_frame


## Anda N passos de física (alias de settle, para o loop de transição).
func step(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


## Espera o inimigo entrar em algum dos estados previstos, com limite de
## tempo. Recebe NOMES ("CHASE"), nao indices: quem chama nao precisa
## conhecer a ordem do enum -- e assim o teste continua valendo depois que
## um estado novo for inserido no meio.
func wait_for_state(states: Array, max_frames: int) -> bool:
	for _i in max_frames:
		await get_tree().physics_frame
		if states.has(enemy.state_name()):
			return true
	return false


func dispose() -> void:
	queue_free()
	await get_tree().physics_frame