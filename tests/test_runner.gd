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

## No modo `--script` os autoloads ainda nao viraram identificadores globais
## quando o script e compilado, entao resolvemos pela arvore.
var _gs: Node = null
var _save: Node = null


func _process(_delta: float) -> bool:
	match _phase:
		0:
			_phase = 1
			_run_unit_tests()
			_spawn_all_scenes()
		1:
			_phase = 2
			_free_all_scenes()
			_report()
			return true
	return false


func _report() -> void:
	print("")
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
	_suite = suite
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
		return

	_test_layers()
	_test_input_map()
	_test_game_state()
	_test_save()
	_test_sfx()
	_test_music()


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