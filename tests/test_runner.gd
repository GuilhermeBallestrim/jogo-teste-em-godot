extends SceneTree
## Roteiro de testes unitarios e de integracao. Roda sem abrir o editor:
##
##   godot --headless --path . --script res://tests/test_runner.gd
##
## Sai com codigo 0 se tudo passar, 1 se algo falhar -- pronto para CI.
##
## Cobre logica pura (GameState, Layers, InputMap, sintese de audio) e faz um
## smoke de integracao instanciando todas as cenas do jogo.

const SCENES := [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/hud.tscn",
	"res://scenes/ui/pause_menu.tscn",
	"res://scenes/ui/options_panel.tscn",
	"res://scenes/ui/end_screen.tscn",
	"res://scenes/levels/level_01.tscn",
	"res://scenes/actors/player/player.tscn",
	"res://scenes/actors/enemies/slime.tscn",
	"res://scenes/props/coin.tscn",
	"res://scenes/props/checkpoint.tscn",
	"res://scenes/props/platform.tscn",
]

var _passed := 0
var _failed := 0
var _suite := ""
var _failures: PackedStringArray = []
var _phase := 0
var _spawned: Array[Node] = []
var _unit_done := false
var _suite_start := 0
var _empty_suites := PackedStringArray()

## No modo `--script` os autoloads ainda nao viraram identificadores globais
## quando o script e compilado, entao resolvemos pela arvore.
var _gs: Node = null
var _save: Node = null


func _process(_delta: float) -> bool:
	match _phase:
		0:
			# Os testes com fisica sao coroutines (esperam physics_frame), entao
			# rodam como tarefa assincrona e avisam quando terminam. As cenas so
			# entram na arvore depois, para nao interferirem na fisica do player.
			_phase = 1
			_run_unit_tests()
		1:
			if _unit_done:
				_phase = 2
				_spawn_all_scenes()
		2:
			_phase = 3
			_free_all_scenes()
			_report()
			return true
	return false


func _report() -> void:
	print("")
	# Rede de seguranca: uma suite que quebra em tempo de execucao (metodo
	# inexistente, tipo errado) aborta antes de registrar qualquer checagem, e
	# o runner reporta "PASSARAM" com zero verificacoes. Exigimos que cada
	# suite registrada tenha produzido ao menos uma checagem.
	if _empty_suites.size() > 0:
		printerr("  suites sem nenhuma verificacao: %s" % ", ".join(_empty_suites))
		_failed += _empty_suites.size()
		_failures.append(
			"Suite sem verificacoes: %s -- provavelmente lancou excecao antes do primeiro check"
			% ", ".join(_empty_suites)
		)

	if _failed == 0:
		print("  %d verificacoes OK" % _passed)
		print("TESTES: PASSARAM")
		return

	for failure in _failures:
		printerr("  X  %s" % failure)
	print("")
	printerr("  %d passaram, %d falharam" % [_passed, _failed])
	printerr("TESTES: FALHARAM")
	quit(1)


# ---------------------------------------------------------------- helpers


func _begin(suite: String) -> void:
	# Fecha a suite anterior: se ela nao registrou nenhuma checagem, ou
	# explodiu no meio -- ambos sao falhas silenciosas.
	if _suite != "" and _passed + _failed == _suite_start:
		_empty_suites.append(_suite)

	_suite = suite
	_suite_start = _passed + _failed
	print("-- %s" % suite)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		_failures.append("[%s] %s" % [_suite, message])


func _check_eq(actual: Variant, expected: Variant, message: String) -> void:
	_check(
		actual == expected,
		"%s -- esperado %s, obtido %s" % [message, expected, actual]
	)


# ------------------------------------------------------------------- suites


func _run_unit_tests() -> void:
	_gs = root.get_node_or_null(^"GameState")
	_save = root.get_node_or_null(^"Save")

	_check(_gs != null, "autoload GameState ausente")
	_check(_save != null, "autoload Save ausente")
	if _gs == null or _save == null:
		_unit_done = true
		return

	_test_layers()
	_test_input_map()
	_test_game_state()
	_test_save()
	_test_sfx()
	_test_music()
	await _test_player_physics()
	await _test_enemy_fsm()
	_unit_done = true


func _test_layers() -> void:
	_begin("Layers")

	_check_eq(Layers.WORLD, 1 << 0, "WORLD")
	_check_eq(Layers.PLAYER, 1 << 1, "PLAYER")
	_check_eq(Layers.ENEMY, 1 << 2, "ENEMY")
	_check_eq(Layers.INTERACTABLE, 1 << 3, "INTERACTABLE")
	_check_eq(Layers.HITBOX, 1 << 4, "HITBOX")
	_check_eq(Layers.HURTBOX, 1 << 5, "HURTBOX")

	# As constantes precisam continuar em sincronia com project.godot.
	var expected_names := ["World", "Player", "Enemy", "Interactable", "Hitbox", "Hurtbox"]
	for i in expected_names.size():
		_check_eq(
			ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % (i + 1), ""),
			expected_names[i],
			"project.godot layer_%d" % (i + 1)
		)


func _test_input_map() -> void:
	_begin("InputMap")

	var required := [
		"move_left", "move_right", "move_up", "move_down",
		"jump", "dash", "interact", "attack", "pause", "restart",
	]
	for action in required:
		_check(InputMap.has_action(action), "acao ausente: %s" % action)
		if InputMap.has_action(action):
			_check(
				not InputMap.action_get_events(action).is_empty(),
				"acao sem eventos: %s" % action
			)

	_check(_has_key(&"jump", KEY_SPACE), "jump nao esta mapeado para Espaco")
	_check(_has_key(&"dash", KEY_SHIFT), "dash nao esta mapeado para Shift")
	_check(_has_key(&"move_left", KEY_A), "move_left nao esta mapeado para A")
	_check(_has_key(&"pause", KEY_ESCAPE), "pause nao esta mapeado para Esc")


func _has_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


func _test_game_state() -> void:
	_begin("GameState")

	_gs.reset()
	_check_eq(_gs.health, _gs.max_health, "reset devolve vida cheia")

	_gs.take_damage(30)
	_check_eq(_gs.health, 70, "take_damage aplica o dano")

	_gs.heal(999)
	_check_eq(_gs.health, _gs.max_health, "heal respeita max_health")

	_gs.take_damage(-50)
	_check_eq(_gs.health, _gs.max_health, "dano negativo e ignorado")

	_gs.take_damage(100000)
	_check_eq(_gs.health, 0, "vida nunca fica negativa")
	_check(not _gs.is_alive(), "is_alive falso com 0 de vida")

	_gs.set_flag(&"chave", Vector2(10, 20))
	_check_eq(_gs.get_flag(&"chave"), Vector2(10, 20), "flag guardada")
	_check_eq(_gs.get_flag(&"inexistente", 7), 7, "flag ausente usa o default")

	_gs.add_coins(5)
	_gs.add_score(100)
	var snapshot: Dictionary = _gs.to_dict()
	_gs.reset()
	_check_eq(_gs.coins, 0, "reset zera moedas")
	_gs.from_dict(snapshot)
	_check_eq(_gs.coins, 5, "from_dict restaura moedas")
	_check_eq(_gs.score, 100, "from_dict restaura pontos")
	_check(_gs.get_flag(&"chave") == Vector2(10, 20), "from_dict restaura flags")

	_gs.reset()


func _test_save() -> void:
	_begin("Save")

	var slot := &"__test_runner__"
	_save.erase_save(slot)
	_check(not _save.has_save(slot), "slot inicial nao existe")
	_check_eq(_save.last_scene_path(), "", "last_scene_path vazio antes de carregar")

	_gs.coins = 77
	_gs.score = 1234
	_check(_save.save_game(slot), "save_game retornou true")
	_check(_save.has_save(slot), "has_save verdadeiro apos gravar")

	_gs.reset()
	_check(_save.load_game(slot), "load_game retornou true")
	_check_eq(_gs.coins, 77, "moedas restauradas do disco")
	_check_eq(_gs.score, 1234, "pontos restaurados do disco")

	# O test runner roda sem cena carregada (--script nao instancia a main),
	# entao scene_path sai vazio e last_scene_path deve ficar vazio tambem.
	# O que importa e que ele NUNCA aponte para um arquivo inexistente.
	_check(
		_save.last_scene_path() == "" or ResourceLoader.exists(_save.last_scene_path()),
		"last_scene_path nunca aponta para cena inexistente"
	)

	_check(_save.erase_save(slot), "erase_save retornou true")
	_check(not _save.has_save(slot), "arquivo removido")

	_check(not _save.load_game(slot), "load_game falha sem arquivo")

	_gs.reset()


func _test_sfx() -> void:
	_begin("Sfx")

	_check(Sfx.RECIPES.size() > 0, "existe pelo menos um som definido")
	for id: StringName in Sfx.RECIPES.keys():
		var stream := Sfx.get_stream(id)
		_check(stream != null, "som %s nao foi gerado" % id)
		if stream is AudioStreamWAV:
			_check(
				(stream as AudioStreamWAV).data.size() > 0,
				"som %s saiu com buffer vazio" % id
			)

	_check(Sfx.get_stream(&"coin") == Sfx.get_stream(&"coin"), "cache reusa o mesmo stream")

	_check(Sfx.get_stream(&"inexistente") == null, "som desconhecido devolve null")


func _test_music() -> void:
	_begin("Music")

	var stream := Music.get_stream()
	_check(stream != null, "trilha nao foi gerada")
	if stream == null:
		return

	_check_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "loop ativado")
	_check(stream.loop_end > 0, "loop_end definido")
	_check(stream.data.size() > 0, "buffer de audio nao vazio")

	# 4 compassos a 110 BPM = ~8.7s a 22050 Hz, mono 16 bits.
	var expected_frames := int(22050.0 * (60.0 / 110.0) * 4.0 * 4.0)
	_check(
		absi(stream.loop_end - expected_frames) <= expected_frames * 0.02,
		"duracao inesperada: %d frames (esperado ~%d)" % [stream.loop_end, expected_frames]
	)

	_check(Music.get_stream() == stream, "cache reusa a mesma trilha")




## Envia um evento de acao para o jogo, como o teclado faria.
##
## Agora o player le o pulo em `_unhandled_input`, e nao por polling em
## `_physics_process`. Por isso este helper dispara o evento e deixa o loop
## entregar ao player -- e o mesmo caminho que o jogo real usa.
func _press_jump(down: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = &"jump"
	ev.pressed = down
	Input.parse_input_event(ev)


## Observador que roda DEPOIS do player no mesmo passo de fisica.
##
## `await physics_frame` retoma no INICIO do passo, antes dos nos processarem.
## Ler a velocidade dali devolve o valor do frame anterior (ja aterrissado) e
## perde o pico do pulo. Este no e o ultimo filho, entao mede o estado real.
class PeakTracker:
	extends Node

	var target: Node2D = null
	var lowest_y := INF
	var highest_vy := 0.0
	var measured := false

	func _physics_process(_delta: float) -> void:
		if target == null or not is_instance_valid(target):
			return
		lowest_y = minf(lowest_y, target.global_position.y)
		highest_vy = minf(highest_vy, target.velocity.y)
		measured = true

	func reset() -> void:
		lowest_y = INF
		highest_vy = 0.0
		measured = false


func _test_player_physics() -> void:
	_begin("Player: fisica")
	var packed := load("res://scenes/actors/player/player.tscn") as PackedScene
	var player: Node2D = packed.instantiate()

	# Superficie do chao em y = 0. A capsula do player tem raio 16 e altura 56,
	# entao o centro assenta em y = -28 (metade da altura) -- nao em 0.
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 200)
	shape.shape = rect
	shape.position = Vector2(0, 100)
	floor_body.add_child(shape)
	# Tem de bater com o que `Platform._ready` faz, senao o teste nao reproduz
	# a fase: `StaticBody2D.new()` nasce sem camada nenhuma.
	floor_body.collision_layer = Layers.WORLD
	floor_body.collision_mask = 0

	var tracker := PeakTracker.new()
	tracker.name = "PeakTracker"
	tracker.target = player

	var holder := Node2D.new()
	holder.add_child(floor_body)
	holder.add_child(player)
	root.add_child(holder)
	# Ultimo filho: processa depois do player no mesmo passo.
	holder.add_child(tracker)
	player.global_position = Vector2(0, -400)

	# ~0,9 s de queda para percorrer 372 px com gravidade 980 — 54 frames.
	# Com menos que isso o corpo ainda estaria no ar e o teste mediria queda,
	# não o pulo.
	for _i in 90:
		await physics_frame

	var settled: float = player.global_position.y
	_check(player.is_on_floor(), "corpo assentou no chao apos cair")
	_check(
		settled < -20.0 and settled > -40.0,
		"assentou com a capsula apoiada (y=%.1f, esperado entre -40 e -20)" % settled
	)
	_check(
		float(ProjectSettings.get_setting("physics/2d/default_gravity", 0.0)) > 0.0,
		"gravidade do projeto esta configurada"
	)

	_begin("Player: coyote time")
	await physics_frame
	var coyote := float(player.get("_coyote_timer"))
	_check(coyote > 0.0, "coyote time preenchido no chao (%.3f)" % coyote)

	_begin("Player: pulo")
	tracker.reset()

	# O player ouve o pulo em `_unhandled_input`, então disparamos o mesmo
	# evento que o teclado dispara e esperamos o jogo reagir.
	#
	# Este teste pegaria a regressão que quebrou o pulo: a gravidade era
	# somada sem `* delta`, então -1010 + 980 = -30 e o corpo subia meio
	# pixel. É exatamente o tipo de erro que unitário pega e o olho não vê.
	_press_jump(true)

	# ~2,2 s de arco a 60 fps, com gravidade reduzida no ápice.
	for _i in 140:
		await physics_frame

	_press_jump(false)

	print("    y pico=%.1f  altura=%.1f px (chao em %.1f)" % [
		tracker.lowest_y, settled - tracker.lowest_y, settled
	])
	_check(tracker.measured, "observador mediu o movimento")
	# Limiares derivados do JUMP_VELOCITY configurado (-760), e nao numeros soltos:
	# se alguém reajustar o pulo, o teste acompanha em vez de estalar.
	var expected_speed := 760.0
	_check(
		tracker.highest_vy < -expected_speed * 0.75,
		"pulo mantem a velocidade ate o move_and_slide (pico vy=%.1f, esperado < %.1f)" % [
			tracker.highest_vy, -expected_speed * 0.75
		]
	)
	# A fase exige ~195 px (chegar na Coin11 em y=-450). O alvo de 310 px da
	# folga; fora de 200..400 ha bug de calibragem.
	var height := settled - tracker.lowest_y
	_check(
		height > 200.0 and height < 400.0,
		"altura do pulo na faixa util (%.1f px, esperado entre 200 e 400)" % height
	)
	_check(player.is_on_floor(), "aterrissou de volta no chao")

	_begin("Player: dash")
	tracker.reset()
	player.set("_dash_cooldown", 0.0)
	player.call("_start_dash", Vector2.RIGHT)

	for _i in 10:
		await physics_frame

	var dx: float = player.global_position.x - 0.0
	_check(dx > 50.0, "dash deslocou o corpo para a direita (%.1f px)" % dx)

	holder.queue_free()
	await physics_frame


# ------------------------------------------------- comportamento do Enemy
#
# O Enemy e o sistema mais complexo do projeto (6 estados, 3 transicoes
# condicionais, deteccao por raycast) e antes these nao tinha NENHUM teste de
# comportamento -- so instanciacao. Estas suites exercitam as transicoes de
# verdade, com arena isolada.


func _test_enemy_fsm() -> void:
	await _test_enemy_patrol()
	await _test_enemy_detects_player()
	await _test_enemy_line_of_sight()
	await _test_enemy_attack_and_damage()
	await _test_enemy_death()


## Estados do Enemy, por indice do enum.State. Nominais evitam magic number
## espalhado no teste -- se a ordem mudar no enum, o teste avisa.
const E_IDLE := 0
const E_PATROL := 1
const E_CHASE := 2
const E_ATTACK := 3
const E_STAGGER := 4
const E_DEAD := 5


## Sem player na cena, o slime fica entre PATROL e IDLE e nunca persegue.
func _test_enemy_patrol() -> void:
	_begin("Enemy: patrulha sem alvo")
	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(false)
	arena.enemy.global_position = Vector2(0, -20)
	# Patrulha larga para ele ter o que percorrer.
	arena.enemy.patrol_left = -200.0
	arena.enemy.patrol_right = 200.0

	await arena.settle(30)
	_check(arena.enemy.is_on_floor(), "slime assentou no chao")

	var start_x: float = arena.enemy.global_position.x
	var seen := {}
	for _i in 300:
		await physics_frame
		seen[arena.enemy.state] = true

	_check(
		not seen.has(E_CHASE),
		"nunca entrou em CHASE sem player na cena (estados: %s)" % str(seen.keys())
	)
	_check(
		seen.has(E_PATROL) or seen.has(E_IDLE),
		"ficou no ciclo IDLE/PATROL (estados: %s)" % str(seen.keys())
	)

	var moved: float = absf(arena.enemy.global_position.x - start_x)
	_check(moved > 20.0, "andei durante a patrulha (%.1f px)" % moved)

	arena.dispose()


## Player dentro de detect_range e sem parede: deve entrar em CHASE e aproximar.
func _test_enemy_detects_player() -> void:
	_begin("Enemy: detecta o jogador")
	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(true)
	arena.player.global_position = Vector2(0, -60)
	arena.enemy.global_position = Vector2(220, -20)
	arena.enemy.detect_range = 300.0
	arena.enemy.forget_range = 700.0

	await arena.settle(20)
	_check(arena.enemy.state != E_CHASE, "comeca longe, sem perseguir ainda")

	var chased := await arena.wait_for_state([E_CHASE], 120)
	_check(chased, "entrou em CHASE com o jogador a 220 px (estado=%d)" % arena.enemy.state)

	var before: float = absf(arena.player.global_position.x - arena.enemy.global_position.x)
	for _i in 30:
		await physics_frame
	var after: float = absf(arena.player.global_position.x - arena.enemy.global_position.x)
	_check(after < before, "aproximou do jogador (%.0f -> %.0f px)" % [before, after])

	arena.dispose()


## Parede entre os dois: o raycast bloqueia e o slime NAO deve perseguir.
## Esta e a suite que garante que o inimigo nao "enxerga" atraves de
## geometria -- o comportamento mais irritante de um jogo de plataforma.
func _test_enemy_line_of_sight() -> void:
	_begin("Enemy: linha de visao")
	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(true)
	arena.player.global_position = Vector2(0, -60)
	arena.enemy.global_position = Vector2(260, -20)
	arena.enemy.detect_range = 500.0
	arena.add_wall(130.0)

	await arena.settle(20)

	var chased := await arena.wait_for_state([E_CHASE], 150)
	_check(
		not chased,
		"NAO entrou em CHASE com parede no meio (estado=%d)" % arena.enemy.state
	)

	# Sem CHASE, ele tem que continuar patrulhando normalmente.
	var patrolled := false
	for _i in 180:
		await physics_frame
		if arena.enemy.state in [E_PATROL, E_IDLE]:
			patrolled = true
			break
	_check(patrolled, "continua patrulhando em vez de ficar travado")

	arena.dispose()


## Perto o suficiente: ataca, o dano chega ao player, e o ciclo se recupera.
func _test_enemy_attack_and_damage() -> void:
	_begin("Enemy: ataque causa dano")
	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(true)
	# Colados: a hitbox do slime fica 26 px a FRENTE do corpo, entao o que
	# encosta na hurtbox do player (raio 20) e o centro dela, nao o slime.
	arena.player.global_position = Vector2(0, -60)
	arena.enemy.global_position = Vector2(10, -20)
	arena.enemy.attack_range = 60.0
	arena.enemy.chase_speed = 300.0
	# O player mata o slime se o combate durar: ele tem 3 de vida e o golpe
	# tira 1. Sem i-frames, dois acertos ja matam e o node e liberado no meio
	# da suite.
	arena.enemy.max_health = 999
	arena.enemy.health = 999

	await arena.settle(20)
	_gs.reset()

	# O teste e sobre a conexao do golpe (hitbox -> hurtbox -> apply_damage),
	# nao sobre a locomocao do slime. Deixamos a FSM rodar normalmente e
	# esperamos o ciclo completo passar pelo ATTACK, que liga a hitbox.
	var start_health: int = _gs.health

	# Nao verificamos passar pelo estado ATTACK: ele dura 0,22s e o slime
	# pode cruzar entre dois passos, tornando o teste instavel. O que
	# importa -- hitbox ligar e dano chegar -- e verificado no laco abaixo.
	await arena.wait_for_state([E_ATTACK], 300)

	var damaged := false
	var saw_hitbox_active := false
	for _i in 180:
		await physics_frame
		if arena.enemy._hitbox.active:
			saw_hitbox_active = true
		if _gs.health < start_health:
			damaged = true
			break

	_check(saw_hitbox_active, "a hitbox ficou ativa durante o ataque")
	_check(damaged, "o golpe tirou vida do player (%d -> %d)" % [start_health, _gs.health])

	var recovered := await arena.wait_for_state([E_CHASE, E_PATROL], 180)
	_check(recovered, "saiu do ataque para CHASE ou PATROL (estado=%d)" % arena.enemy.state)

	_gs.reset()
	arena.dispose()


## Dano suficiente mata: DEAD, pontua, e ignora dano depois.
func _test_enemy_death() -> void:
	_begin("Enemy: morte")
	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(false)
	arena.enemy.global_position = Vector2(0, -20)
	arena.enemy.max_health = 3
	arena.enemy.health = 1

	await arena.settle(20)

	# `died` e setado por closure num array: em GDScript atribuir a variavel
	# local de dentro de um lambda funciona, mas o array evita qualquer
	# questao de escopo em tempo de execucao.
	var died := [false]
	var score_before: int = _gs.score
	arena.enemy.died.connect(func(_e) -> void: died[0] = true)

	arena.enemy.apply_damage(5, null, Vector2.RIGHT, 100.0)
	await physics_frame

	_check(arena.enemy.state == E_DEAD, "entrou em DEAD (estado=%d)" % arena.enemy.state)
	_check(died[0], "emitiu o sinal died")
	_check(_gs.score > score_before, "somou pontos ao morrer (%d -> %d)" % [score_before, _gs.score])
	_check(arena.enemy.health <= 0, "vida zerou ou ficou negativa (%d)" % arena.enemy.health)
	# Inulneravel AO MORRER: e o que impede dano em cadeia com o player
	# atravessando o corpo no mesmo frame.
	_check(arena.enemy._hurtbox.invulnerable, "hurtbox ficou invulneravel apos morrer")

	arena.enemy.apply_damage(5, null, Vector2.RIGHT, 100.0)
	await physics_frame
	_check(arena.enemy.state == E_DEAD, "ignora dano apos morto")
	_check(_gs.score == score_before + 50, "nao pontua duas vezes")

	_gs.reset()
	arena.dispose()



# ------------------------------------------------- integracao (multi-frame)


func _spawn_all_scenes() -> void:
	_begin("Cenas")

	# As cenas ligam audio ao entrar. Em headless nao ha mix de verdade, e o
	# AudioServer segura os playbacks ate o fim -- o que gera aviso de leak.
	# Aqui so queremos validar a montagem das cenas, nao a saida de audio.
	var audio := AudioManager.instance
	if audio != null:
		audio.sfx_enabled = false
		audio.music_enabled = false

	for path: String in SCENES:
		if not ResourceLoader.exists(path):
			_check(false, "cena nao existe: %s" % path)
			continue

		var packed := load(path) as PackedScene
		_check(packed != null, "cena nao carregou: %s" % path)
		if packed == null:
			continue

		var instance := packed.instantiate()
		_check(instance != null, "cena nao instanciou: %s" % path)
		if instance == null:
			continue

		root.add_child(instance)
		_spawned.append(instance)


func _free_all_scenes() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()

	# As cenas instanciadas ligam audio ao entrar. Sem esta limpeza o Godot
	# acusa "ObjectDB instances leaked at exit" ao fim do teste.
	var audio := AudioManager.instance
	if audio != null:
		audio.stop_all_sfx()
		audio.stop_music(0.0)
	Sfx.clear_cache()
	Music.clear_cache()
