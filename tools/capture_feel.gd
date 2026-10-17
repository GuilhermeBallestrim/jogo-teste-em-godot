extends SceneTree
## Capturas da onda 1: camera antecipada, feedback de combate e particulas.
##
## Roda COM janela (sem `--headless`), como as outras ferramentas:
##
##   godot --path . --script res://tools/capture_feel.gd
##
## ## Por que cada tiro traz um controle
##
## A primeira versao contava os pixels da cor do efeito e dava "1505 px de
## vermelho" como prova do numero de dano. Era mentira: o vermelho do numero
## do player e o vermelho do slime ficam dentro da tolerancia de cor, e os
## 1505 pixels eram o slime. A ferramenta confirmava o que era preciso
## confirmar.
##
## Entao todo tiro medido tem um **controle**: a mesma cena, no mesmo numero de
## quadros, sem o efeito. O que se exige e a **diferenca** entre os dois, e nao
## o total. Isso vale seja a cor ambigua ou nao -- e a unica forma de contar
## "algo mudou" sem saber o que mais a cena tinha.
##
## ## O que este arquivo NAO prova
##
## - **O peso do hitstop.** Um instante congelado e indistinguivel de um
##   instante normal numa foto. O unico jeito de sentir os 60 ms e jogando.
## - **Que o teclado de verdade chega ao jogo.** [method _setup_run_right] usa
##   `Input.action_press`, que mexe no estado da acao e nao no fluxo de
##   eventos. Move o bone; nao substitui o teste de input real que o projeto
##   ainda nao tem.
##
## O que ele prova: que a antecipacao da camera mede o valor certo (numero
## impresso, nao so a imagem) e que numero, poeira e rastro aparecem.

const LEVEL := "res://scenes/levels/level_01.tscn"
const OUT_DIR := "user://capturas"

## Cor de cada efeito. Importante: nenhuma delas precisa ser unica no cenario
## -- e a diferenca contra o controle que isola o efeito.
const PLAYER_HURT := Color(1.0, 0.44, 0.44)
const ENEMY_HURT := Color(0.55, 1.0, 0.5)
const DASH_BLUE := Color(0.45, 0.78, 1.0)

## Pixels de **diferenca** que contam como "o efeito apareceu".
## Pixels de **diferenca** que contam como "o efeito apareceu".
##
## Baixo de proposito, e so o rastro do dash usa este numero. A contagem
## dele varia de 14 a 43 px conforme em que quadro a foto pega a trilha --
## ela e emitida enquanto o dash corre, entao o pixel count depende do
## alinhamento entre o inicio do dash e o passo da fisica. Um limiar em 30
## deixaria o tiro instavel, e um tiro instavel e pior do que um tiro fraco:
## a gente para de confiar nele.
##
## O que este limiar precisa pegar e a AUSENCIA do efeito, que mediu -2 px
## quando a trilha nao estava sendo emitida. Nao medir o tamanho dela.
const MIN_PIXELS := 8
## Tolerancia da contagem de cor. O numero e o rastro sao desenhados com
## antisserrilhamento e contorno, entao poucos pixels batem exatamente.
const COLOR_TOLERANCE := 0.25

var _shots: Array = []
var _index := 0
var _frames := 0
var _saved := 0
var _pending := StringName(&"")
var _live: Array[Node] = []
var _problems: PackedStringArray = PackedStringArray()
var _player: Node2D = null
var _arena: EnemyArena = null
## Pixels contados por tiro, para a proxima linha usar de base.
var _hits: Dictionary[String, int] = {}


func _initialize() -> void:
	# `nome`, quadros ate a virada, acao de abertura, quadros ate a foto,
	# acao da virada, cor a contar, px de diferenca exigidos, velocidade
	# exigida do corpo, nome do controle.
	#
	# Os controles vem ANTES dos tiros que eles medem, porque a diferenca so
	# pode ser tirada depois que os dois existem.
	#
	# Os tres primeiros rodam na arena plana, nao na fase. Na fase o bone
	# corre pro buraco entre as plataformas, perde 25 de vida e volta pro
	# checkpoint: o tiro media +67.9 px num dia e +2.5 px no seguinte, sem
	# que nada na camera tivesse mudado.
	# `nome`, quadros ate a virada, acao de abertura, quadros ate a foto,
	# acao da virada, cor a contar, px de diferencia exigidos, velocidade
	# exigida do corpo, nome do controle, numero de dano esperado na cena.
	#
	# Os controles vem ANTES dos tiros que eles medem, porque a diferenca so
	# pode ser tirada depois que os dois existem.
	#
	# Os tres primeiros rodam na arena plana, nao na fase. Na fase o bone
	# corre pro buraco entre as plataformas, perde 25 de vida e volta pro
	# checkpoint: o tiro media +67.9 px num dia e +2.5 px no seguinte, sem
	# que nada na camera tivesse mudado.
	#
	# Os numeros de dano NAO sao julgados por contagem de pixel: a area
	# solida de um glifo depende do digito, e o "1" -- o mais fino que existe
	# -- rende ~10 px contra os ~50 do "7" do player. Um limiar unico seria
	# medindo o digito, nao o efeito. A ultima coluna verifica o que importa:
	# que existe um [FloatingNumber] vivo na cena, no nivel de verdade, depois
	# do caminho de dano de verdade. O pixel fica no relatorio, sem julgar.
	_shots = [
		["01_parado", 90, _setup_idle, 0, Callable(), DASH_BLUE, 0, 0.0, "", 0],
		["02_correndo_direita", 110, _setup_run_right, 0, Callable(), DASH_BLUE, 0, PlayerTuning.SPEED * 0.9, "", 0],
		["03_correndo_esquerda", 100, _setup_run_right, 60, _setup_turn_left, DASH_BLUE, 0, PlayerTuning.SPEED * 0.9, "", 0],
		["04_dash_direita", 7, _setup_dash_right, 0, Callable(), DASH_BLUE, MIN_PIXELS, 0.0, "02_correndo_direita", 0],
		["05_controle_inimigo", 12, _setup_look_enemy, 0, Callable(), ENEMY_HURT, 0, 0.0, "", 0],
		["06_numero_no_inimigo", 12, _setup_hit_enemy, 0, Callable(), ENEMY_HURT, 0, 0.0, "05_controle_inimigo", 1],
		["07_controle_player", 12, _setup_look_player, 0, Callable(), PLAYER_HURT, 0, 0.0, "", 0],
		["08_numero_no_player", 12, _setup_hurt_player, 0, Callable(), PLAYER_HURT, 0, 0.0, "07_controle_player", 1],
		["09_inimigo_morre", 8, _setup_kill_enemy, 0, Callable(), Color.TRANSPARENT, 0, 0.0, "", 0],
	]
	_problems.clear()
	_release()


# --------------------------------------------------------------- montagens


func _release() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")


func _clear() -> void:
	_release()
	for node in _live:
		if is_instance_valid(node):
			node.free()
	_live.clear()
	_player = null
	# current_scene apontando para uma cena liberada abaixo danglingaria,
	# e o proximo FloatingNumber.spawn cairia num no invalido.
	current_scene = null
	_arena = null


## Arena plana para os tiros de camera e dash.
##
## O chao da arena e so `StaticBody2D` e nao desenha nada, entao os tres tiros
## de camera saem quase pretos com um bone de 30 px no meio. Por isso a marca
## vertical na origem: e o que torna "o bone saiu do centro" visivel a olho.
func _mount_arena() -> void:
	_clear()
	_arena = EnemyArena.new()
	root.add_child(_arena)
	_arena.build(true)
	_player = _arena.player as Node2D
	if _player == null:
		_problems.append("arena sem player")
		return

	# A arena desliga a camera do player para nao atrapalhar os testes dela.
	# Aqui e o oposto: a camera e o que esta sendo medido.
	var cam := _player.get_node_or_null(^"Camera2D") as Camera2D
	if cam != null:
		cam.enabled = true
		# Os limites default (±800) deixariam a camera pregada no centro numa
		# arena de 4000 px, e a foto mostraria um bone parado no meio da tela
		# com a antecipacao ligada.
		cam.limit_left = -2000
		cam.limit_right = 2000
		cam.limit_top = -800
		cam.limit_bottom = 400

	var marker := Line2D.new()
	marker.points = PackedVector2Array([Vector2(0, -140), Vector2(0, 160)])
	marker.width = 2.0
	marker.default_color = Color(0.45, 0.5, 0.6, 0.75)
	_arena.add_child(marker)

	# Sem inimigo: um slime perto da origem seria um obstaculo, nao conteudo.
	if _arena.enemy != null and is_instance_valid(_arena.enemy):
		_arena.enemy.queue_free()
		_arena.enemy = null


func _mount_level() -> void:
	_clear()
	var packed := load(LEVEL) as PackedScene
	if packed == null:
		_problems.append("fase nao carregou")
		return
	var level := packed.instantiate()
	root.add_child(level)
	_live.append(level)
	# `current_scene` e o que [method FloatingNumber.spawn] usa para saber
	# onde pendurar o numero. Sem esta linha ele recebe nulo e devolve nulo:
	# o tiro 06 media uma diferenca de -10 px e nao achava numero nenhum.
	current_scene = level
	for node in get_nodes_in_group(&"player"):
		_player = node as Node2D
		break
	if _player == null:
		_problems.append("fase sem player no grupo")


## Sem entrada nenhuma. E a referencia: a camera tem de estar em zero.
func _setup_idle() -> void:
	_mount_arena()


## `Input.action_press` mexe no estado da acao, e nao no fluxo de eventos.
## E o unico jeito de mover o player numa ferramenta de captura.
func _setup_run_right() -> void:
	_mount_arena()
	Input.action_press(&"move_right")


## Vira para a esquerda sem remontar a cena: e a segunda etapa do tiro 03.
func _setup_turn_left() -> void:
	Input.action_release(&"move_right")
	Input.action_press(&"move_left")


func _setup_dash_right() -> void:
	_mount_arena()
	Input.action_press(&"move_right")
	if _player != null and _player.has_method(&"_start_dash"):
		_player.call(&"_start_dash", Vector2.RIGHT)
	Input.action_release(&"move_right")


## Controle do tiro 06: a mesma fase, o mesmo numero de quadros, sem o golpe.
func _setup_look_enemy() -> void:
	_mount_level()
	if _first_enemy() == null:
		_problems.append("fase sem inimigo para o tiro de dano")


## Controle do tiro 08: idem, sem o dano no player.
func _setup_look_player() -> void:
	_mount_level()
	if _player == null:
		_problems.append("fase sem player para o tiro de dano")


## Golpe pelo caminho de verdade do dano. Pula a deteccao de `Area2D`: a
## sobreposicao ja tem suite propria, e aqui o que importa e o que o jogador ve
## depois do acerto.
func _setup_hit_enemy() -> void:
	_mount_level()
	var enemy := _first_enemy()
	if enemy == null:
		_problems.append("fase sem inimigo para o tiro de dano")
		return
	enemy.call(&"apply_damage", 1, _player, Vector2.RIGHT, 160.0)


func _setup_kill_enemy() -> void:
	_mount_level()
	var enemy := _first_enemy()
	if enemy == null:
		_problems.append("fase sem inimigo para o tiro de morte")
		return
	enemy.call(&"apply_damage", 99, _player, Vector2.RIGHT, 160.0)


func _setup_hurt_player() -> void:
	_mount_level()
	if _player == null or not _player.has_method(&"apply_damage"):
		_problems.append("fase sem player com apply_damage")
		return
	_player.call(&"apply_damage", 1, null, Vector2.LEFT, 220.0)


## O inimigo mais proximo do player.
##
## Pegar o primeiro do grupo dava um inimigo possivelmente fora da tela: o
## numero de dano nascia la, e a captura media uma diferenca de -10 px.
## O efeito existia; o tiro que nao conseguia ve-lo.
func _first_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var distance := 0.0 if _player == null else enemy.global_position.distance_to(_player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best

# ------------------------------------------------------------------ roteiro


func _process(_delta: float) -> bool:
	if _pending != &"":
		_save(_pending)
		_pending = &""
		_frames = 0
		return false

	if _saved >= _shots.size():
		print("CAPTURA: %d imagem(ns) em %s" % [
			_saved, ProjectSettings.globalize_path(OUT_DIR)
		])
		for problem in _problems:
			push_error("CAPTURA: %s" % problem)
		# Sai com codigo 1 quando algo faltou. Devolver `_problems.is_empty()`
		# deste `_process` e o defeito mais caro de uma ferramenta de captura:
		# problema encontrado virava "nao sai", e o roteiro completava os
		# tiros e depois repetia o resumo para sempre, com a janela aberta.
		quit(0 if _problems.is_empty() else 1)
		return true

	if _frames == 0:
		var shot: Array = _shots[_index]
		_index += 1
		(shot[2] as Callable).call()
		# Conta o proprio quadro: sem isto `_frames` continua 0, o `if` acima
		# remonta a cena todo quadro e o roteiro nunca sai do primeiro tiro.
		_frames = 1
		return false

	_frames += 1
	var current: Array = _shots[_index - 1]
	# Virada de entrada: so uma vez, no quadro exato. Sem isto o tiro tiraria
	# a foto no mesmo quadro da virada, com o corpo ainda indo para o lado
	# antigo.
	if _frames == int(current[1]) and (current[4] as Callable).is_valid():
		(current[4] as Callable).call()

	if _frames < int(current[1]) + int(current[3]):
		return false

	_pending = StringName(String(current[0]))
	return false


## O pixel esta perto o bastante da cor alvo?
##
## `Color` nao tem `distance_to` em Godot 4.5, entao a comparacao passa por
## `Vector3`.
func _near(px: Color, target: Color) -> bool:
	var delta := absf(px.r - target.r) + absf(px.g - target.g) + absf(px.b - target.b)
	return delta / 3.0 < COLOR_TOLERANCE


## Quanto a camera antecipou agora, em px. Sinal = direcao.
##
## Numero, e nao imagem: uma foto mostra onde a camera esta, e nao se ela
## respondeu a velocidade do corpo.
## Quantos numeros de dano estao vivos na cena neste instante.
##
## Verificacao exata onde a contagem de pixel nao serve: a area solida de um
## glifo depende do digito, e o "1" rende uma fracao do que o "7" rende.
## Aqui nao ha digito no meio -- ou existe um numero na tela, ou nao existe.
func _damage_numbers_alive() -> int:
	if current_scene == null:
		return 0
	var total := 0
	for child in current_scene.get_children():
		if child is FloatingNumber:
			total += 1
	return total


func _camera_look_offset() -> float:
	if _player == null:
		return 0.0
	var cam := _player.get_node_or_null(^"Camera2D")
	if cam != null and cam.has_method(&"look_offset"):
		return cam.call(&"look_offset")
	return 0.0


## Velocidade horizontal do corpo observado.
func _player_velocity() -> Vector2:
	var body := _player as CharacterBody2D
	return body.velocity if body != null else Vector2.ZERO


func _save(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var image := root.get_texture().get_image()
	if image == null:
		_problems.append("sem imagem (rode SEM --headless)")
		return
	if image.save_png("%s/%s.png" % [OUT_DIR, name]) != OK:
		_problems.append("%s: falha ao salvar" % name)
		return

	var shot: Array = _shots[_index - 1]
	var target: Color = shot[5]
	var wanted: int = shot[6]
	var want_speed: float = shot[7]
	var control := String(shot[8])
	var want_numbers: int = shot[9]

	var distinct := {}
	var hit := 0
	# Amostra de 2 em 2: a contagem exata nao importa, e o passo maior mantem
	# o roteiro em poucos segundos.
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var px := image.get_pixel(x, y)
			distinct[px.to_rgba32()] = true
			if target.a > 0.0 and _near(px, target):
				hit += 1
	_saved += 1
	_hits[name] = hit

	# O numero precisa estar NA CENA, no nivel de verdade, depois do caminho
	# de dano de verdade. Um no [FloatingNumber] vivo e prova; pixel contem
	# borda e antisserrilhamento, entao mede o digito e nao o efeito.
	var numbers := _damage_numbers_alive()
	if numbers < want_numbers:
		_problems.append("%s sem numero de dano na tela (%d de %d)" % [
			name, numbers, want_numbers
		])

	if distinct.size() < 8:
		_problems.append("%s saiu praticamente vazia (%d cores)" % [name, distinct.size()])

	# A diferenca contra o controle, e nao o total. Ver a nota do cabecalho:
	# contar o total confirmava o slime, nao o numero de dano.
	var base := 0
	if control != "" and _hits.has(control):
		base = _hits[control]
	var delta := hit - base
	if wanted > 0 and delta < wanted:
		_problems.append("%s sem o efeito esperado (%d px a mais que '%s', esperava %d)" % [
			name, delta, control, wanted
		])
	if wanted > 0 and control != "" and not _hits.has(control):
		_problems.append("%s pede controle '%s', que nao foi tirado antes" % [name, control])

	# Reprova quando o corpo nao esta correndo no jeito. Antecipacao medida com
	# o bone encostado numa parede e um numero plausivel que nao mede nada.
	if want_speed > 0.0:
		var speed := absf(_player_velocity().x)
		if speed < want_speed:
			_problems.append("%s nao mostra antecipacao valida: corpo a %.0f px/s, esperava %.0f" % [
				name, speed, want_speed
			])

	var medida := "%d px de %s" % [hit, target.to_html(false)]
	if control != "":
		medida += " (controle %d, dif %+d)" % [base, delta]
	print("  %s -> %d cores, %s%s%s" % [
		name, distinct.size(), medida,
		("  camera %+.1f px" % _camera_look_offset()) if want_speed > 0.0 else "",
		("  %d numero(s) de dano" % numbers) if want_numbers > 0 else "",
	])
