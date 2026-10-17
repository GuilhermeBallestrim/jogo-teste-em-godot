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
	"res://scenes/levels/level_02.tscn",
	"res://scenes/levels/level_03.tscn",
	"res://scenes/levels/level_04.tscn",
	"res://scenes/actors/player/player.tscn",
	"res://scenes/actors/enemies/slime.tscn",
	"res://scenes/actors/enemies/bat.tscn",
	"res://scenes/actors/enemies/archer.tscn",
	"res://scenes/actors/enemies/crawler.tscn",
	"res://scenes/actors/enemies/bomber.tscn",
	"res://scenes/actors/enemies/guard.tscn",
	"res://scenes/actors/enemies/boss.tscn",
	"res://scenes/actors/enemies/shield.tscn",
	"res://scenes/actors/enemies/teleporter.tscn",
	"res://scenes/actors/enemies/mini_boss.tscn",
	"res://scenes/props/projectile.tscn",
	"res://scenes/props/coin.tscn",
	"res://scenes/props/checkpoint.tscn",
	"res://scenes/props/platform.tscn",
]

## Fases cujo layout precisa ser provado atravessavel.
const LEVELS := [
	"res://scenes/levels/level_01.tscn",
	"res://scenes/levels/level_02.tscn",
]

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const RIG_SCENE := "res://scenes/actors/player/player_rig.tscn"
const PLAYER_SCENE := "res://scenes/actors/player/player.tscn"
const SLIME_SCENE := "res://scenes/actors/enemies/slime.tscn"

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
## Preferencias globais. Os testes mexem nelas (remapeamento, contraste) e
## `_report()` as restaura: um `settings.cfg` sujo contamina a proxima
## execucao.
var _settings: Node = null


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
	# As preferencias de teclado, audio e contraste persistem em
	# `user://settings.cfg`. Os testes mexem nelas de proposito, e um
	# `settings.cfg` deixado para tras faria a proxima execucao comecar com a
	# tecla de pulo trocada -- e o teste de InputMap reprovaria sem ninguem ter
	# mexido em nada. Voltar ao padrao faz parte do teste, nao e limpeza extra.
	if _settings != null:
		_settings.reset_bindings()
		_settings.set_ui_scale(1.0)
		_settings.set_shake_scale(1.0)
		_settings.set_high_contrast(false)
		_settings.save_settings()

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
	_settings = root.get_node_or_null(^"Settings")

	_check(_gs != null, "autoload GameState ausente")
	_check(_save != null, "autoload Save ausente")
	_check(_settings != null, "autoload Settings ausente")
	if _gs == null or _save == null:
		_unit_done = true
		return

	_test_layers()
	_test_input_map()
	_test_game_state()
	_test_level_registry()
	_test_save()
	_test_sfx()
	_test_music()
	await _test_player_physics()
	await _test_enemy_fsm()
	_test_inventory()
	await _test_use_item_action()
	await _test_key_remap()
	await _test_accessibility()
	_test_level_reachability()
	await _test_levels_keep_enemies()
	await _test_menu_lists_every_level()
	await _test_player_rig_poses()
	await _test_parry()
	await _test_glide()
	_test_session_stats()
	_test_abilities()
	await _test_camera_look()
	_test_hitstop()
	await _test_combat_feedback()
	await _test_particle_presets()
	_unit_done = true


## O menu tem de oferecer exatamente uma entrada por fase registrada: nem
## menos (uma fase que ninguem consegue escolher) nem mais (um botao que abre
## um id inexistente).
## O bone do player precisa de 8 estados que deem silhuetas diferentes.
##
## Nao basta existir a pose: se duas renderizam a mesma coisa, o jogador nao
## tem leitura de "ele esta caindo" vs "ele esta pulando", e o defeito e
## invisivel numa captura pequena e invisivel nos testes estruturais.
func _test_player_rig_poses() -> void:
	_begin("Player: poses do bone")

	var rig_scene := load(RIG_SCENE) as PackedScene
	_check(rig_scene != null, "player_rig.tscn carregou")
	if rig_scene == null:
		return

	var rig := rig_scene.instantiate() as PlayerRig
	root.add_child(rig)
	await process_frame

	_check(rig != null, "rig instancia com a classe certa")
	if rig == null:
		return

	# Uma "assinatura" por estado: angulos e posicoes de todas as pecas, com
	# duas casas. Dois estados com a mesma assinatura sao o mesmo desenho.
	var signatures := {}
	var states := [
		PlayerRig.State.IDLE, PlayerRig.State.WALK, PlayerRig.State.RUN,
		PlayerRig.State.DASH, PlayerRig.State.JUMP, PlayerRig.State.FALL,
		PlayerRig.State.ATTACK, PlayerRig.State.DAMAGE, PlayerRig.State.DEATH,
	]
	for state: PlayerRig.State in states:
		rig.facing = 1.0
		rig.play(state)
		for _i in 40:
			rig.tick(1.0 / 60.0)
		signatures[state] = _pose_signature(rig)

	_check(
		signatures.size() == states.size(),
		"os %d estados produziram assinatura" % states.size()
	)

	var duplicates := PackedStringArray()
	var names := PackedStringArray()
	for state: PlayerRig.State in states:
		names.append(rig.State.keys()[state])
		for other: PlayerRig.State in states:
			if other <= state:
				continue
			if signatures[state] == signatures[other]:
				duplicates.append("%s==%s" % [names[state], names[other]])
	_check(
		duplicates.is_empty(),
		"nenhuma pose duplicada%s" % ("" if duplicates.is_empty() else ": " + ", ".join(duplicates))
	)

	# O arco do golpe é exclusive dele: aparecendo em outra pose vira um
	# borrão amarelo permanente na tela.
	for state: PlayerRig.State in states:
		rig.facing = 1.0
		rig.play(PlayerRig.State.IDLE)
		for _i in 20:
			rig.tick(1.0 / 60.0)
		rig.play(state)
		rig.tick(1.0 / 60.0)
		var should_show: bool = state == PlayerRig.State.ATTACK
		_check(
			rig.slash_visible() == should_show,
			"arco %s em %s" % ["presente" if should_show else "ausente", names[state]]
		)

	# Espelhar e o que faz o bone virar na direcao do movimento.
	rig.facing = -1.0
	rig.play(PlayerRig.State.IDLE)
	rig.tick(1.0 / 60.0)
	_check(rig.scale.x < 0.0, "facing -1 espelha o bone")

	rig.queue_free()
	await process_frame


## Assinatura numérica da pose atual, com 2 casas.
func _pose_signature(rig: Node2D) -> String:
	var parts := ["leg_back", "scarf", "leg_front", "arm_back", "torso", "arm_front", "head"]
	var out := PackedStringArray()
	for part: String in parts:
		var node := rig.get_node_or_null(NodePath(String(part).to_pascal_case())) as Node2D
		if node == null:
			out.append(part + ":?")
			continue
		out.append("%s:%.2f,%.2f,%.2f,%.2f" % [
			part,
			snappedf(node.rotation, 0.01),
			node.position.x,
			node.position.y,
			node.scale.y,
		])
	return "|".join(out)


func _test_menu_lists_every_level() -> void:
	_begin("Menu: lista de fases")

	# O menu liga a musica ao entrar. Como aqui so queremos contar botoes,
	# cortamos o audio -- e o mesmo cuidado que a suite "Cenas" toma.
	var audio := AudioManager.instance
	if audio != null:
		audio.music_enabled = false

	var packed := load(MENU_SCENE) as PackedScene
	_check(packed != null, "main_menu carregou")
	if packed == null:
		return

	var menu := packed.instantiate()
	root.add_child(menu)
	await process_frame

	var expected := 0
	for id: StringName in LevelRegistry.all_ids():
		if id != &"main_menu":
			expected += 1

	var list := menu.get_node_or_null(^"Center/Column/LevelList") as VBoxContainer
	_check(list != null, "main_menu tem a lista de fases")
	if list != null:
		_check(
			list.get_child_count() == expected,
			"a lista tem %d botao(s) para %d fase(s)"
				% [list.get_child_count(), expected]
		)
		_check(list.visible == (expected > 1), "a lista so aparece com 2+ fases")

	menu.free()
	await process_frame


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


## O registro e o que permite salvar com mais de uma fase: id estavel que
## sobrevive a renomear o arquivo, e um caminho padrao para quando a cena
## salva some.
func _test_level_registry() -> void:
	_begin("LevelRegistry")

	_check(LevelRegistry.has(&"level_01"), "level_01 registrado")
	_check(LevelRegistry.has(&"main_menu"), "main_menu registrado")

	var path := LevelRegistry.path_for(&"level_01")
	_check(path == "res://scenes/levels/level_01.tscn", "caminho de level_01 (%s)" % path)
	_check(ResourceLoader.exists(path), "caminho de level_01 existe de verdade")

	_check(
		LevelRegistry.id_for_path("res://scenes/levels/level_01.tscn") == &"level_01",
		"id_for_path reverte o caminho"
	)
	_check(
		LevelRegistry.id_for_path("res://scenes/levels/inexistente.tscn") == &"",
		"id_for_path de cena desconhecida devolve vazio"
	)

	_check(LevelRegistry.path_for(&"nao_existe") == "", "id desconhecido nao tem caminho")

	# O padrao tem de existir, senao o "Continuar" sem save quebraria.
	_check(LevelRegistry.default_id() != &"", "ha uma fase padrao definida")
	_check(ResourceLoader.exists(LevelRegistry.default_path()), "fase padrao existe")

	_check(LevelRegistry.all_ids().size() >= 2, "registro tem as 2 cenas")
	_check(LevelRegistry.all_paths().size() == LevelRegistry.all_ids().size(), "ids e paths em mesmo numero")

	# Registrar de novo nao pode duplicar nem reordenar.
	var before: int = LevelRegistry.all_ids().size()
	LevelRegistry.register(&"level_01", "res://scenes/levels/level_01.tscn")
	_check_eq(LevelRegistry.all_ids().size(), before, "registrar de novo nao duplica")


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

	_test_save_peek_level_id(slot)
	_test_save_with_missing_level(slot)


## Save apontando para uma fase que nao existe mais: o comportamento que
## importa quando a segunda fase ainda nao foi criada. O Continue tem de cair
## na fase padrao e avisar, nunca tentar abrir arquivo morto.
func _test_save_with_missing_level(slot: StringName) -> void:
	_begin("Save: fase removida")

	var path := "user://saves/%s.json" % slot
	var payload := {
		"version": 2,
		"timestamp": 0,
		"scene_id": "level_99",
		"scene_path": "res://scenes/levels/level_99.tscn",
		"game_state": {"coins": 5, "score": 50, "flags": {}},
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "consegui escrever o save de mentira")
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()

	_check(_save.load_game(slot), "load_game leu o save de fase inexistente")
	_check(_save.last_scene_missing(), "marcou a cena como ausente")
	_check_eq(_gs.coins, 5, "restaurou o estado mesmo assim")

	var recovered: String = _save.last_scene_path()
	_check(recovered != "", "caiu numa cena valida em vez de vazio")
	_check(
		ResourceLoader.exists(recovered),
		"a cena de fallback existe (%s)" % recovered
	)
	_check_eq(recovered, LevelRegistry.default_path(), "caiu na fase padrao")

	# Save versao antiga (so tinha path, sem id) tem de continuar funcionando.
	_begin("Save: versao 1 legada")
	var legacy := {
		"version": 1,
		"timestamp": 0,
		"scene_path": "res://scenes/levels/level_01.tscn",
		"game_state": {"coins": 9, "score": 90, "flags": {}},
	}
	var legacy_file := FileAccess.open(path, FileAccess.WRITE)
	_check(legacy_file != null, "consegui escrever o save legado")
	if legacy_file == null:
		return
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()

	_check(_save.load_game(slot), "leu save versao 1")
	_check(not _save.last_scene_missing(), "versao 1 nao e tratada como ausente")
	_check_eq(_save.last_scene_path(), "res://scenes/levels/level_01.tscn", "resolveu pelo path")
	_check_eq(_save.last_level_id(), &"level_01", "deduziu o id pelo path")
	_check_eq(_gs.coins, 9, "restaurou o estado do save legado")

	_save.erase_save(slot)

	_gs.reset()


## `peek_level_id` e o que permite o menu marcar "(continuar)" sem carregar o
## `GameState` inteiro so para desenhar um texto. O risco dele e marcado na
## hora errada -- e por isso que os tres casos abaixo nao podem passar.
func _test_save_peek_level_id(slot: StringName) -> void:
	_begin("Save: peek_level_id")

	var path := "user://saves/%s.json" % slot
	_check_eq(_save.peek_level_id(slot), &"", "slot inexistente devolve vazio")

	# 1. Save de verdade, apontando para a fase 2.
	var real := {
		"version": 2,
		"timestamp": 0,
		"scene_id": "level_02",
		"scene_path": "res://scenes/levels/level_02.tscn",
		"game_state": {"coins": 3, "score": 30, "flags": {}},
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "consegui escrever o save")
	if file == null:
		return
	file.store_string(JSON.stringify(real))
	file.close()
	# Peek nao pode aplicar nada: e leitura, nao carga. Comparamos com o que
	# estava antes, e nao com zero -- o GameState ja vem sujo do teste anterior.
	var coins_before: int = _gs.coins
	_check_eq(_save.peek_level_id(slot), &"level_02", "devolve o id do save")
	_check_eq(_gs.coins, coins_before, "peek nao mexeu no GameState")

	# 2. Save legado, sem id, so com caminho.
	var legacy := {
		"version": 1,
		"timestamp": 0,
		"scene_path": "res://scenes/levels/level_01.tscn",
		"game_state": {"coins": 9, "score": 90, "flags": {}},
	}
	var legacy_file := FileAccess.open(path, FileAccess.WRITE)
	_check(legacy_file != null, "consegui sobrescrever com o legado")
	if legacy_file == null:
		_save.erase_save(slot)
		return
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	_check_eq(_save.peek_level_id(slot), &"level_01", "deduziu o id pelo caminho legado")

	# 3. Lixo: nem JSON valido. Vazio e o unico resposta aceitavel -- um id
	# inventado aqui colocaria "(continuar)" na fase errada.
	var junk_file := FileAccess.open(path, FileAccess.WRITE)
	_check(junk_file != null, "consegui sobrescrever com lixo")
	if junk_file != null:
		junk_file.store_string("isto nao e json {{{")
		junk_file.close()
	_check_eq(_save.peek_level_id(slot), &"", "lixo devolve vazio, nunca um id chute")

	_save.erase_save(slot)


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
	await _test_enemy_ledge_guard()
	await _test_enemy_detects_player()
	await _test_enemy_line_of_sight()
	await _test_enemy_attack_and_damage()
	await _test_enemy_death()
	await _test_flying_enemy()
	await _test_ranged_enemy()
	await _test_crawler_enemy()
	await _test_bomber_explosion()
	await _test_guard_stands_post()
	await _test_boss()


const BAT_SCENE := "res://scenes/actors/enemies/bat.tscn"
const ARCHER_SCENE := "res://scenes/actors/enemies/archer.tscn"
const CRAWLER_SCENE := "res://scenes/actors/enemies/crawler.tscn"
const BOMBER_SCENE := "res://scenes/actors/enemies/bomber.tscn"
const GUARD_SCENE := "res://scenes/actors/enemies/guard.tscn"
const BOSS_SCENE := "res://scenes/actors/enemies/boss.tscn"
const SHIELD_SCENE := "res://scenes/actors/enemies/shield.tscn"
const TELEPORTER_SCENE := "res://scenes/actors/enemies/teleporter.tscn"
const MINI_BOSS_SCENE := "res://scenes/actors/enemies/mini_boss.tscn"


## Voador: a prova de que a arquitetura aceita variacao. Se o [Enemy]
## precisasse de mudanca para admitir um inimigo sem chao, o teste reprovaria.
func _test_flying_enemy() -> void:
	_begin("Enemy: voador")
	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(false, BAT_SCENE)
	arena.enemy.global_position = Vector2(0, -300)

	_check(arena.enemy.flies, "marcado como voador")
	_check(arena.enemy.floor_snap_length == 0.0, "sem snap de chao")

	var start_y: float = arena.enemy.global_position.y
	var max_drop := 0.0

	for _i in 300:
		await physics_frame
		# Sem gravidade, nunca pode cair livremente.
		max_drop = maxf(max_drop, arena.enemy.global_position.y - start_y)
		if arena.enemy.is_on_floor():
			break

	_check(max_drop < 120.0, "nao caiu livremente (desvio maximo %.1f px)" % max_drop)
	_check(not arena.enemy.is_on_floor(), "continua no ar apos 5 segundos")

	# E o mesmo FSM: perto de um player, tem de perseguir.
	arena.dispose()
	await physics_frame

	var chase_arena := EnemyArena.new()
	root.add_child(chase_arena)
	chase_arena.build(true, BAT_SCENE)
	chase_arena.player.global_position = Vector2(0, -300)
	chase_arena.enemy.global_position = Vector2(240, -300)

	await chase_arena.settle(20)
	var chased := await chase_arena.wait_for_state([&"CHASE"], 150)
	_check(chased, "voador tambem persegue (estado=%s)" % chase_arena.enemy.state_name())

	chase_arena.dispose()


## Atirador: o ciclo de telegrafia e o projetil, que sao o que torna o tiro
## justo em vez de impossivel de reagir.
func _test_ranged_enemy() -> void:
	_begin("Enemy: atirador")
	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(true, ARCHER_SCENE)
	arena.player.global_position = Vector2(0, -60)
	arena.enemy.global_position = Vector2(240, -20)
	arena.enemy.max_health = 999
	arena.enemy.health = 999

	await arena.settle(20)
	_check(arena.enemy.contact_damage == 0, "nao causa dano por contato")

	var aimed := await arena.wait_for_state([&"AIM"], 300)
	_check(aimed, "entrou em AIM (telegrafia)")

	# Durante o AIM o inimigo tem de ficar parado -- e a janela de leitura.
	var still_during_aim := true
	for _i in 12:
		await physics_frame
		if arena.enemy.state_name() == &"AIM" and absf(arena.enemy.velocity.x) > 40.0:
			still_during_aim = false

	_check(still_during_aim, "fica parado durante a mira")
	_check(arena.enemy._hitbox.active == false, "hitbox corpo a corpo desligada na mira")

	# O tiro precisa aparecer na cena.
	var projectiles := get_nodes_in_group(&"projectiles")
	var fired := false
	for _i in 90:
		await physics_frame
		if not get_nodes_in_group(&"projectiles").is_empty():
			fired = true
			break

	_check(fired, "criou um projetil")
	_check(arena.enemy.state_name() == &"ATTACK" or arena.enemy.state_name() == &"STAGGER",
		"entrou em recuperacao apos atirar (estado=%s)" % arena.enemy.state_name())

	arena.dispose()


## Sem player na cena, o slime fica entre PATROL e IDLE e nunca persegue.
##
## A afirmacao e sobre a EXTENSAO percorrida, nao sobre a posicao no fim dos
## 300 quadros. Medir a posicao final de um oscilador e teste fragil: passa
## ou falha conforme o instante exato em que a amostra cai, e nao porque o
## comportamento mudou.
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

	# `patrol_left`/`patrol_right` sao deslocamentos a partir de casa, e nao
	# coordenadas de mundo. Com o inimigo em x=0 a distincao nao aparece; com
	# ele deslocado, apareceria -- e era o que fazia o slime atravessar a
	# fase inteira atrás de um alvo em x=150.
	var home: float = arena.enemy.home_x()
	var left_x: float = arena.enemy.patrol_left_x()
	var right_x: float = arena.enemy.patrol_right_x()
	_check(
		is_equal_approx(left_x, home - 200.0) and is_equal_approx(right_x, home + 200.0),
		"patrulha e relativa a casa (casa=%.0f, faixa %.0f..%.0f)" % [home, left_x, right_x]
	)

	var seen := {}
	var lowest: float = arena.enemy.global_position.x
	var highest: float = lowest
	# 700 quadros (~11,6s): uma ida e volta completa entre -200 e +200 leva
	# ~7,2s a 90 px/s, mais a pausa de 0,6s em cada ponta. Com menos quadros a
	# amostra so pegaria a ida -- e o teste mediria a velocidade, nao o
	# comportamento.
	for _i in 700:
		await physics_frame
		seen[arena.enemy.state_name()] = true
		var x: float = arena.enemy.global_position.x
		lowest = minf(lowest, x)
		highest = maxf(highest, x)

	_check(
		not seen.has(&"CHASE"),
		"nunca entrou em CHASE sem player na cena (estados: %s)" % str(seen.keys())
	)
	_check(
		seen.has(&"PATROL") or seen.has(&"IDLE"),
		"ficou no ciclo IDLE/PATROL (estados: %s)" % str(seen.keys())
	)
	_check(
		highest - lowest > 300.0,
		"percorreu a faixa inteira (%.0f px, de %.0f a %.0f)"
			% [highest - lowest, lowest, highest]
	)
	_check(
		lowest >= left_x - 40.0 and highest <= right_x + 40.0,
		"nao saiu da faixa de patrulha (%.0f..%.0f, limite %.0f..%.0f)"
			% [lowest, highest, left_x, right_x]
	)

	arena.dispose()


## O inimigo nao pode cair no vazio. E o teste que cobre a promessa feita ao
## jogador de que a beirada e segura.
func _test_enemy_ledge_guard() -> void:
	_begin("Enemy: guarda de borda")
	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build_ledge(240.0)
	# Patrulha maior que a plataforma: ele nao tem para onde ir, e isso e o teste.
	arena.enemy.patrol_left = -400.0
	arena.enemy.patrol_right = 400.0
	arena.enemy.global_position = Vector2(0, -20)

	await arena.settle(30)
	_check(arena.enemy.is_on_floor(), "slime assentou na plataforma estreita")

	# O probe precisa concordar com a borda: no meio acha chao dos dois lados.
	_check(arena.enemy.has_ground_ahead(1.0), "acha chao no meio da plataforma")
	_check(arena.enemy.has_ground_ahead(-1.0), "acha chao no meio (esquerda)")

	var floor_y: float = arena.enemy.global_position.y
	var deepest := 0.0
	for _i in 600:
		await physics_frame
		deepest = maxf(deepest, arena.enemy.global_position.y - floor_y)

	# Tolerancia de 60px: o pulo do slime (~46px) mais a penetracao no chao.
	# Acima disso ele saiu da plataforma.
	_check(
		deepest < 60.0,
		"nao caiu da plataforma (afundou %.0f px em 10 segundos)" % deepest
	)
	_check(
		absf(arena.enemy.global_position.x) < 140.0,
		"nao andou alem da ponta (x=%.0f)" % arena.enemy.global_position.x
	)

	# E a rede final: se cair mesmo assim, volta para casa em vez de sumir.
	arena.enemy.global_position.y += 900.0
	for _i in 6:
		await physics_frame
	_check(
		arena.enemy.is_on_floor(),
		"voltou para a plataforma depois de cair no vazio (y=%.0f)"
			% arena.enemy.global_position.y
	)
	_check(
		arena.enemy.global_position.distance_to(arena.enemy.home_position()) < 40.0,
		"e voltou para perto de casa, nao para um lugar aleatorio"
	)

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
	_check(arena.enemy.state_name() != &"CHASE", "comeca longe, sem perseguir ainda")

	var chased := await arena.wait_for_state([&"CHASE"], 120)
	_check(chased, "entrou em CHASE com o jogador a 220 px (estado=%s)" % arena.enemy.state_name())

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

	var chased := await arena.wait_for_state([&"CHASE"], 150)
	_check(
		not chased,
		"NAO entrou em CHASE com parede no meio (estado=%s)" % arena.enemy.state_name()
	)

	# Sem CHASE, ele tem que continuar patrulhando normalmente.
	var patrolled := false
	for _i in 180:
		await physics_frame
		if arena.enemy.state_name() in [&"PATROL", &"IDLE"]:
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

	# O ciclo agora passa por AIM (telegrafia) antes de ATTACK, entao
	# esperamos qualquer um dos dois estados de ataque.
	await arena.wait_for_state([&"AIM", &"ATTACK"], 300)

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

	var recovered := await arena.wait_for_state([&"CHASE", &"PATROL"], 180)
	_check(recovered, "saiu do ataque para CHASE ou PATROL (estado=%s)" % arena.enemy.state_name())

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

	_check(arena.enemy.state_name() == &"DEAD", "entrou em DEAD (estado=%s)" % arena.enemy.state_name())
	_check(died[0], "emitiu o sinal died")
	_check(_gs.score > score_before, "somou pontos ao morrer (%d -> %d)" % [score_before, _gs.score])
	_check(arena.enemy.health <= 0, "vida zerou ou ficou negativa (%d)" % arena.enemy.health)
	# Inulneravel AO MORRER: e o que impede dano em cadeia com o player
	# atravessando o corpo no mesmo frame.
	_check(arena.enemy._hurtbox.invulnerable, "hurtbox ficou invulneravel apos morrer")

	arena.enemy.apply_damage(5, null, Vector2.RIGHT, 100.0)
	await physics_frame
	_check(arena.enemy.state_name() == &"DEAD", "ignora dano apos morto")
	_check(_gs.score == score_before + 50, "nao pontua duas vezes")

	_gs.reset()
	arena.dispose()



# ------------------------------------------------- balistica das fases

## Prova que o layout de cada fase e atravessavel com o pulo do [Player].
##
## Sem isto, mexer numa posicao no editor passa despercebido e a fase fica
## impossível -- e ninguem descobre ate jogar ate o fim e travar no meio.
##
## O modelo e a balistica real do pulo (ver [PlayerTuning]), incluindo o
## `APEX_GRAVITY_SCALE`. O que ele ignora e a rampa de aceleracao do
## jogador, que so ajuda: um modelo que a ignora so pode acusar um vao
## impossível quando ele e de fato impossivel.
##
## E um grafo, nao uma comparacao par a par: na fase 1 as plataformas
## flutuantes ficam altas demais para sair do chao, mas o caminho existe
## passando por elas. So o grafo sabe disso.
## A fase real, rodada por 15 segundos, com a IA de verdade.
##
## E o teste que cobre a promessa que o jogador faz a cada fase: "ali tem
## um inimigo". Sem ele, um slime que cai no vazio some e a fase fica
## trivial sem ninguem perceber -- foi exatamente assim que os inimigos
## atravessavam o mapa.
func _test_levels_keep_enemies() -> void:
	for level_path: String in LEVELS:
		var name := level_path.get_file().get_basename()
		_begin("Fase: inimigos nao caem (%s)" % name)

		var packed := load(level_path) as PackedScene
		if packed == null:
			_check(false, "%s carregou" % name)
			continue

		var level := packed.instantiate()
		root.add_child(level)
		await process_frame

		var kill_zone := level.get_node_or_null(^"KillZone") as Node2D
		var kill_y: float = kill_zone.global_position.y if kill_zone != null else 110.0

		var initial: Array[Node2D] = _enemies_of(level)
		_check(initial.size() > 0, "%s tem %d inimigos" % [name, initial.size()])
		# Congela o nome agora, enquanto todo inimigo ainda esta vivo. Vai num
		# dicionario do runner, e nao em metadado do node: um inimigo morto no
		# ultimo quadro e `queue_free()`-ado, e um node liberado transformaria
		# o proprio `get_meta` numa falha.
		var names_at_start := {}
		for enemy: Node2D in initial:
			names_at_start[enemy] = enemy.name

		# O player vai para o alto da fase, fora do alcance de qualquer inimigo.
		#
		# Deixá-lo no SpawnPoint parece inofensivo e não é: o slime mais próximo
		# está a 80 px, dentro do `detect_range`, persegue e mata o player. Aí
		# o teste deixa de medir "os inimigos ficam na fase" e passa a medir
		# "quantos o player matou" — e a falha aparece como "inimigo perdido",
		# que é um diagnóstico que aponta para o lugar errado.
		var player := level.get_node_or_null(^"Player") as Node2D
		if player != null:
			player.global_position = Vector2(0.0, -2000.0)

		for _i in 900:
			await physics_frame

		var alive := 0
		var present := {}
		for enemy: Node2D in _enemies_of(level):
			if not is_instance_valid(enemy):
				continue
			alive += 1
			present[enemy.name] = true
			var y: float = enemy.global_position.y
			_check(
				y < kill_y,
				"%s: %s esta acima do KillZone (y=%.0f, zona em %.0f)"
					% [name, enemy.name, y, kill_y]
			)

		# O nome vem do dicionario congelado acima: ler `enemy.name` agora
		# estoura em um node ja liberado.
		var lost := PackedStringArray()
		for enemy: Node2D in initial:
			var enemy_name := String(names_at_start.get(enemy, "&"))
			if not is_instance_valid(enemy) or not present.has(enemy_name):
				lost.append(enemy_name)
		_check(
			lost.is_empty(),
			"%s: nenhum inimigo sumiu (%d de %d)%s"
				% [
					name,
					alive,
					initial.size(),
					"" if lost.is_empty() else " -- perdidos: " + ", ".join(lost),
				]
		)

		level.free()
		await process_frame


func _enemies_of(level: Node) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for node in level.get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy != null and level.is_ancestor_of(enemy):
			out.append(enemy)
	return out


## O inventario tem que sobreviver ao save e recusar o que nao faz sentido.
## O caso que mais importa e o ultimo: item desconhecido no save e bug de
## conteudo, e inventar um item desconhecido esconderia esse bug.
func _test_inventory() -> void:
	_begin("GameState: inventario")

	_gs.reset()
	_check(ItemLibrary.all_ids().size() >= 2, "catalogo tem itens")
	_check(ItemLibrary.has(&"potion"), "pocao existe no catalogo")
	_check(ItemLibrary.definition(&"potion").has_use(), "pocao tem efeito")
	_check(not ItemLibrary.has(&"nao_existe"), "item inexistente nao existe")
	_check(ItemLibrary.definition(&"nao_existe") == null, "item inexistente devolve null")

	# Coletar
	_check_eq(_gs.add_item(&"potion", 2), 2, "add_item devolve o aceito")
	_check_eq(_gs.item_count(&"potion"), 2, "contagem correta")
	_check(_gs.has_item(&"potion", 2), "has_item com quantidade")
	_check(not _gs.has_item(&"potion", 3), "has_item sem quantidade suficiente")

	# Recusas: cada uma tem de devolver 0 e nao mexer em nada.
	_check_eq(_gs.add_item(&"nao_existe", 1), 0, "id desconhecido devolve 0")
	_check_eq(_gs.add_item(&"potion", 0), 0, "quantidade zero devolve 0")
	_check_eq(_gs.add_item(&"potion", -3), 0, "quantidade negativa devolve 0")
	_check_eq(_gs.item_count(&"potion"), 2, "recusas nao alteraram nada")

	# Sinal
	var seen := []
	var on_item := func(id: StringName, count: int) -> void: seen.append([id, count])
	_gs.item_changed.connect(on_item)
	_gs.add_item(&"feather", 1)
	_gs.item_changed.disconnect(on_item)
	_check_eq(seen.size(), 1, "item_changed disparou uma vez")
	_check(
		seen.size() == 1 and seen[0][0] == &"feather" and seen[0][1] == 1,
		"item_changed trouxe id e contagem nova"
	)

	# Usar: com vida cheia, o item e recusado e NAO e consumido.
	_gs.reset()
	_gs.add_item(&"potion", 1)
	_check(_gs.health == _gs.max_health, "vida cheia no inicio")
	_check(not _gs.use_item(&"potion"), "pocao recusada com vida cheia")
	_check_eq(_gs.item_count(&"potion"), 1, "recusa nao gastou o item")

	# Agora com vida ferida: usa, cura e consome.
	_gs.take_damage(60)
	_check(_gs.use_item(&"potion"), "pocao usada com vida ferida")
	_check(_gs.health > _gs.max_health - 60, "vida subiu (%d)" % _gs.health)
	_check_eq(_gs.item_count(&"potion"), 0, "item consumido")

	# Item sem efeito nao e usavel, mas continua no inventario.
	_gs.add_item(&"feather", 1)
	_check(not _gs.use_item(&"feather"), "pena nao tem efeito, nao e usavel")
	_check_eq(_gs.item_count(&"feather"), 1, "pena continua guardada")
	_check(not _gs.use_item(&"nao_existe"), "usar id inexistente falha")

	# Save: ida e volta preserva, e item órfão é descartado.
	_gs.reset()
	_gs.add_item(&"potion", 3)
	_gs.add_item(&"coin_pouch", 1)
	var snapshot: Dictionary = _gs.to_dict()
	_check(snapshot.has("items"), "to_dict inclui items")

	_gs.reset()
	_check_eq(_gs.item_count(&"potion"), 0, "reset limpou o inventario")
	_gs.from_dict(snapshot)
	_check_eq(_gs.item_count(&"potion"), 3, "pocoes voltaram do save")
	_check_eq(_gs.item_count(&"coin_pouch"), 1, "bolsa voltou do save")

	# Save de uma versao futura / conteudo removido.
	_gs.from_dict({"items": {"potion": 1, "item_retirado_do_jogo": 5}})
	_check_eq(_gs.item_count(&"potion"), 1, "item conhecido sobrevive")
	_check_eq(_gs.item_count(&"item_retirado_do_jogo"), 0, "item orfao foi descartado")

	_gs.reset()


## `interact` e a acao de usar item. Ela ja estava no Input Map sem ninguem
## consumindo; o teste garante que continua mapeada e que e usavel.
func _test_use_item_action() -> void:
	_begin("Player: usar item")

	_check(InputMap.has_action(&"interact"), "interact existe no Input Map")

	_gs.reset()
	_gs.take_damage(50)
	_gs.add_item(&"potion", 1)
	var health_before: int = _gs.health

	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(true)
	await arena.settle(10)

	# Input sintetico nao reproduz teclado real neste ambiente (ja sabemos de
	# antes), entao chamamos o caminho que o input dispara.
	arena.player.try_use_item()
	await process_frame

	_check(_gs.item_count(&"potion") == 0, "E consumiu a pocao")
	_check(_gs.health > health_before, "E curou (%d -> %d)" % [health_before, _gs.health])

	# Sem item, nada acontece e o jogador nao perde nada.
	var health_full: int = _gs.health
	_gs.take_damage(20)
	var health_hurt: int = _gs.health
	arena.player.try_use_item()
	await process_frame
	_check(_gs.health == health_hurt, "sem item, nao curou")
	_check(_gs.health != health_full, "mas o dano continua valendo")

	arena.dispose()
	_gs.reset()


## Remapeamento: a parte que quebra o jogo e silenciosa. Perder a tecla de
## pular ou apagar o gamepad junto nao da erro nenhum -- o jogo so fica
## "estranho". Por isso os testes olham o InputMap depois de mexer.
func _test_key_remap() -> void:
	_begin("Settings: remapeamento")

	var settings := root.get_node_or_null(^"Settings")
	_check(settings != null, "autoload Settings ausente")
	if settings == null:
		return

	for action: StringName in Settings.REMAPPABLE:
		_check(InputMap.has_action(action), "acao %s existe" % action)

	# Padrao: toda acao tem alguma tecla.
	for action: StringName in Settings.REMAPPABLE:
		_check(
			settings.binding_text(action) != "--",
			"%s tem binding padrao (%s)" % [action, settings.binding_text(action)]
		)

	var jump_before: String = String(settings.binding_text(&"jump"))

	# Troca para uma tecla和改进: uma tecla quase sem uso.
	var nova := InputEventKey.new()
	nova.physical_keycode = KEY_K
	_check(settings.set_binding(&"jump", nova), "set_binding aceitou a tecla")

	# A troca tem de chegar no InputMap, e nao so no dicionario: e o InputMap
	# que o jogo le.
	var achou := false
	for event in InputMap.action_get_events(&"jump"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_K:
			achou = true
	_check(achou, "InputMap tem a nova tecla de jump")
	_check(settings.binding_text(&"jump") != jump_before, "texto do binding mudou")
	_check(settings.binding_text(&"jump") == "K", "texto mostra K (=%s)" % settings.binding_text(&"jump"))

	# Gamepad sobrevive ao remapeamento de teclado.
	var tem_joypad := false
	for event in InputMap.action_get_events(&"move_left"):
		if event is InputEventJoypadMotion:
			tem_joypad = true
	_check(tem_joypad, "o analógico do gamepad continua em move_left")

	# Persistencia: grava, recarrega e confere.
	settings.save_settings()
	settings.set_binding(&"jump", InputEventKey.new())
	settings.load_settings()
	var voltou := false
	for event in InputMap.action_get_events(&"jump"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_K:
			voltou = true
	_check(voltou, "o remapeamento sobreviveu a save/load")

	# Restaurar padrao volta ao que o jogo realmente usa.
	settings.reset_bindings()
	_check(
		settings.binding_text(&"jump") == jump_before,
		"restaurar devolveu o padrao (%s -> %s)" % [jump_before, settings.binding_text(&"jump")]
	)

	# Recusas. `Settings.quiet_rejections` silencia o `push_error` nestes
	# casos: recusar e o comportamento esperado, e o aviso viraria erro no
	# log do export.
	settings.set(&"quiet_rejections", true)
	_check(not settings.set_binding(&"nao_existe", nova), "acao inexistente recusada")
	_check(not settings.set_binding(&"jump", InputEventJoypadMotion.new()), "joystick recusado")
	settings.set(&"quiet_rejections", false)

	# Conflito: duas acoes com a mesma tecla e erro do jogador, nao do jogo.
	var salto := InputEventKey.new()
	salto.physical_keycode = KEY_SPACE
	settings.set_binding(&"interact", salto)
	# `jump` já usa Espaço por padrão, então o conflito existe mas pode ser
	# reportado em qualquer uma das duas — o que não pode é não ser reportado.
	var conflito: StringName = settings.conflict_with(salto)
	_check(
		conflito == &"jump" or conflito == &"interact",
		"conflito detectado (=%s)" % conflito
	)
	settings.reset_bindings()

	settings.save_settings()


## Acessibilidade: as tres preferencias chegam onde prometem.
func _test_accessibility() -> void:
	_begin("Settings: acessibilidade")

	var settings := root.get_node_or_null(^"Settings")
	_check(settings != null, "autoload Settings ausente")
	if settings == null:
		return

	# Escala de texto: tem de aumentar o fonte E ser reversivel.
	#
	# Testado num `Label` de verdade vindo da HUD, e nao num `Label.new()`: um
	# no criado em codigo tem o override posto aqui mesmo, e passaria mesmo com
	# a escala quebrada. A diferenca entre "funciona" e "funciona na interface
	# que o jogador le" e o que este teste existe para nao perder.
	# Nao instanciamos a HUD aqui. Em modo `--script` os autoloads ainda nao
	# sao identificadores quando o runner compila, e `hud.gd` referencia
	# `GameState` -> `Compile Error` e o runner inteiro se recusa a carregar.
	# Alem disso a propria HUD imprime "Parameter p_child is null" ao ser
	# adicionada fora de uma fase.
	#
	# O que importa e que um `Label` com override de fonte reescale. O
	# `Label` do `player.tscn` nao serve (nao e um `Label`), entao construimos
	# um igual ao que a HUD usa: override explicito, e nao herdado do tema.
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", 20)
	root.add_child(label)

	var base: int = label.get_theme_font_size(&"font_size")
	_check(base == 20, "o rotulo comeca em 20 (=%d)" % base)
	var esperado := int(round(base * 1.5))

	settings.set_ui_scale(1.5)
	Presentation.apply_ui_scale(root, 1.5)
	await process_frame
	var maior: int = label.get_theme_font_size(&"font_size")
	_check(maior == esperado, "fonte %d x 1,5 = %d (=%d)" % [base, esperado, maior])

	# Reaplicar nao pode multiplicar de novo: 1,5 x 1,5 seria 22 em cima de 15.
	Presentation.apply_ui_scale(root, 1.5)
	await process_frame
	_check(
		label.get_theme_font_size(&"font_size") == maior,
		"escala nao acumula (=%d)" % label.get_theme_font_size(&"font_size")
	)

	Presentation.reset_ui_scale(root)
	await process_frame
	_check(label.get_theme_font_size(&"font_size") == base, "reset volta a %d" % base)

	# Um rotulo SEM override precisa ganhar um: a escala alcança todo texto da
	# interface, nao so o que ja vinha com tamanho proprio.
	var sem_override := Label.new()
	root.add_child(sem_override)
	Presentation.apply_ui_scale(root, 1.5)
	await process_frame
	_check(
		sem_override.get_theme_font_size(&"font_size") > 0,
		"rotulo sem override tambem recebe tamanho"
	)
	sem_override.queue_free()

	settings.set_ui_scale(1.0)
	label.queue_free()

	# Limites: a preferencia nao aceita valor absurdo vindo de config editada.
	settings.set_ui_scale(99.0)
	_check(is_equal_approx(settings.ui_scale, Settings.UI_SCALE_MAX), "escala tem teto")
	settings.set_ui_scale(0.01)
	_check(is_equal_approx(settings.ui_scale, Settings.UI_SCALE_MIN), "escala tem piso")
	settings.set_ui_scale(1.0)

	# Contraste.
	var scene := Node2D.new()
	root.add_child(scene)
	Presentation.set_contrast(scene, true)
	_check(Presentation.has_contrast(scene), "contraste adicionou o CanvasModulate")
	var modulate := scene.get_node(^"Contrast") as CanvasModulate
	_check(modulate != null and modulate.color == Presentation.CONTRAST_ON, "contraste ligado")
	Presentation.set_contrast(scene, false)
	_check(modulate.color == Presentation.CONTRAST_OFF, "contraste desligado")
	scene.queue_free()

	# Tremor: com a preferencia em zero, `shake_for` nao pode nem ligar.
	var shake := load("res://src/camera/camera_shake.gd").new() as CameraShake
	root.add_child(shake)
	await process_frame
	settings.set_shake_scale(0.0)
	shake.shake_for(1.0)
	_check(not shake.is_shaking(), "preferencia 0 impede o tremor")
	settings.set_shake_scale(1.0)
	shake.shake_for(1.0)
	_check(shake.is_shaking(), "preferencia 1 liga o tremor")
	shake.stop()
	shake.queue_free()

	settings.save_settings()


func _test_level_reachability() -> void:
	_begin("Fases: layout atravessavel")

	var max_rise := PlayerTuning.max_jump_height()
	_check(max_rise > 200.0, "o pulo sobe %.0f px" % max_rise)
	_check(
		PlayerTuning.jump_reach(max_rise) <= 0.0,
		"pulo nao alcanca a propria altura maxima (%.0f px)" % max_rise
	)

	for level_path: String in LEVELS:
		_test_one_level_is_completable(level_path)


## Uma fase e jogavel se todas as plataformas -- e todas as moedas -- sao
## alcancaveis a partir de onde o jogador nasce.
func _test_one_level_is_completable(level_path: String) -> void:
	var name := level_path.get_file().get_basename()
	var packed := load(level_path) as PackedScene
	_check(packed != null, "%s carregou" % name)
	if packed == null:
		return

	# Nao entra na arvore de proposito: o `_ready` das fases puxa GameState,
	# HUD e musica, e aqui so queremos ler geometria.
	var level := packed.instantiate()
	var platforms_node := level.get_node_or_null(^"Platforms")
	_check(platforms_node != null, "%s tem o no Platforms" % name)
	if platforms_node == null:
		level.free()
		return

	var boxes: Array[Rect2] = []
	for child in platforms_node.get_children():
		var platform := child as Platform
		if platform == null:
			continue
		# `position` e o centro da plataforma; a superficie e o topo.
		boxes.append(Rect2(platform.position - platform.size * 0.5, platform.size))

	_check(boxes.size() >= 2, "%s tem %d plataformas" % [name, boxes.size()])
	if boxes.size() < 2:
		level.free()
		return

	var spawn_x := _spawn_x(level)
	var start := _platform_under(boxes, spawn_x)
	_check(start >= 0, "%s tem chao embaixo do SpawnPoint (x=%.0f)" % [name, spawn_x])
	if start < 0:
		level.free()
		return

	var reachable := _reachable_platforms(boxes, start)

	# Toda plataforma tem de ser alcancavel, nao so a ultima. Uma ilha
	# flutuante que ninguem alcanca e um beco sem saida -- o jogador chega
	# nela (as vezes) e nao sai, ou nunca chega e a fase tem um buraco.
	# Reportar cada uma e melhor que um unico "a fase fecha?", porque ai
	# aparece o nome e a posicao exata do problema.
	var names := _platform_names(platforms_node)
	var islands := 0
	for i in boxes.size():
		if reachable[i] == 1:
			continue
		islands += 1
		_check(
			false,
			"%s: %s e uma ilha (topo %.0f, x de %.0f a %.0f)"
				% [name, names[i], boxes[i].position.y, boxes[i].position.x, boxes[i].end.x]
		)
	if islands == 0:
		_check(true, "%s: todas as %d plataformas ligadas entre si" % [name, boxes.size()])

	var lost := 0
	var coins_node := level.get_node_or_null(^"Coins")
	_check(coins_node != null, "%s tem o no Coins" % name)
	for child in coins_node.get_children() if coins_node != null else []:
		var coin := child as Node2D
		if coin == null:
			continue
		if _coin_is_reachable(coin.position, boxes, reachable):
			continue
		lost += 1
		_check(false, "%s: moeda %s em (%.0f, %.0f) e inalcancavel" % [name, coin.name, coin.position.x, coin.position.y])

	if lost == 0:
		_check(true, "%s: todas as moedas alcancaveis" % name)

	level.free()


## Nome de cada plataforma, na mesma ordem em que [method
## _test_one_level_is_completable] monta os retangulos.
func _platform_names(platforms_node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for child in platforms_node.get_children():
		if child is Platform:
			out.append(child.name)
	return out


## Posicao horizontal de nascimento: SpawnPoint, ou o Player se a fase nao
## declarar o marcador.
func _spawn_x(level: Node) -> float:
	var marker := level.get_node_or_null(^"SpawnPoint") as Node2D
	if marker != null:
		return marker.position.x
	var player := level.get_node_or_null(^"Player") as Node2D
	if player != null:
		return player.position.x
	return 0.0


## Indice da plataforma cujo topo fica logo abaixo de `x`, ou -1.
func _platform_under(boxes: Array[Rect2], x: float) -> int:
	var best := -1
	var best_top := INF
	for i in boxes.size():
		var box := boxes[i]
		if x < box.position.x or x > box.end.x:
			continue
		if box.position.y < best_top:
			best_top = box.position.y
			best = i
	return best


## Fecha o grafo de um pulo a partir de `start` e devolve quais plataformas
## o jogador consegue alcancar.
##
## De `a` chega-se em `b` quando a altura pedida cabe no pulo e o alcance
## horizontal do arco encosta na `b`. O alcance e medido a partir das duas
## bordas de `a`, porque o jogador pode decolar de qualquer ponto dela.
func _reachable_platforms(boxes: Array[Rect2], start: int) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(boxes.size())
	var queue: Array[int] = [start]
	seen[start] = 1

	while not queue.is_empty():
		var i: int = queue.pop_back()
		var a := boxes[i]
		for j in boxes.size():
			if seen[j] == 1:
				continue
			var b := boxes[j]
			# No Godot +y aponta para BAIXO. `rise` aqui e "quantos px a
			# plataforma de destino esta acima da de origem".
			var rise := a.position.y - b.position.y
			var reach := PlayerTuning.jump_reach(rise)
			if reach <= 0.0:
				continue
			# O arco cobre [a.left - reach, a.right + reach]; se isso cruza
			# `b`, existe um ponto de decolagem que chega nela.
			if a.position.x - reach > b.end.x:
				continue
			if a.end.x + reach < b.position.x:
				continue
			seen[j] = 1
			queue.append(j)

	return seen


## Uma moeda e alcancavel se existe uma plataforma visitada logo abaixo
## dela, dentro do alcance lateral do pulo a partir dessa plataforma.
func _coin_is_reachable(pos: Vector2, boxes: Array[Rect2], reachable: PackedByteArray) -> bool:
	for i in boxes.size():
		if reachable[i] == 0:
			continue
		var box := boxes[i]
		if pos.y > box.position.y + 8.0:
			continue
		# Mesma convencao do grafo: +y e para baixo, entao "acima" e subtrair
		# a posicao da moeda da posicao da plataforma.
		var rise := box.position.y - pos.y
		var reach := PlayerTuning.jump_reach(rise)
		if reach <= 0.0:
			continue
		if pos.x >= box.position.x - reach and pos.x <= box.end.x + reach:
			return true
	return false


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


## Escorre: cai e a rede de seguranca o traz de volta.
##
## O caminho de recuperacao (`_guard_offscreen`) so era exercitado por
## knockback forte antes. O escorre exercita-o de proposito: anda ate a borda,
## cai, e volta para casa em vez de morrer em silencio.
func _test_crawler_enemy() -> void:
	_begin("Enemy: escorre (cai e recupera)")

	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(false, CRAWLER_SCENE)
	await process_frame

	var home := arena.enemy.global_position
	# Empurra para baixo do limite de queda.
	arena.enemy.global_position = home + Vector2(0, 400)
	arena.enemy.velocity = Vector2.ZERO

	for _i in 5:
		await physics_frame
	_check(
		arena.enemy.global_position.distance_to(home) < 5.0,
		"rede de seguranca trouxe o escorre de volta (%.1f px)" % arena.enemy.global_position.distance_to(home)
	)

	arena.dispose()
	await process_frame


## Explosivo: ao morrer, danifica o jogador colado.
##
## O dano nao vem de `Hitbox`. E o caminho de dano que nao passa por hitbox,
## e o que o teste existe para provar.
func _test_bomber_explosion() -> void:
	_begin("Enemy: explosivo (dano radial)")

	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(true, BOMBER_SCENE)
	await process_frame

	arena.enemy.global_position = Vector2(0, 0)
	arena.player.global_position = Vector2(40, 0)
	await process_frame

	var health_before: int = int(_gs.get(&"health"))
	arena.enemy.call(&"apply_damage", 99, arena.player, Vector2.RIGHT, 0.0)

	# O hitstop congela o relogio, entao `physics_frame` nao avanca o tempo
	# de jogo. Basta um quadro: o dano e aplicado sincrono em `_die`.
	await physics_frame
	_check(
		int(_gs.get(&"health")) < health_before,
		"jogador colado levou dano radial (%d -> %d)" % [health_before, int(_gs.get(&"health"))]
	)

	# Quem esta longe nao leva.
	var far_arena := EnemyArena.new()
	root.add_child(far_arena)
	far_arena.build(true, BOMBER_SCENE)
	await process_frame
	far_arena.enemy.global_position = Vector2(0, 0)
	far_arena.player.global_position = Vector2(400, 0)
	await process_frame
	var health_far_before: int = int(_gs.get(&"health"))
	far_arena.enemy.call(&"apply_damage", 99, far_arena.player, Vector2.RIGHT, 0.0)
	await physics_frame
	_check(
		int(_gs.get(&"health")) == health_far_before,
		"jogador longe nao levou dano radial"
	)

	arena.dispose()
	far_arena.dispose()
	await process_frame


## Guarda: nao abandona o posto sem jogador por perto.
func _test_guard_stands_post() -> void:
	_begin("Enemy: guarda (fica no posto)")

	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(false, GUARD_SCENE)
	await process_frame

	var start_x: float = arena.enemy.global_position.x
	for _i in 60:
		await physics_frame
	_check(
		absf(arena.enemy.global_position.x - start_x) < 8.0,
		"guarda nao abandona o posto sem jogador (%.1f px)" % absf(arena.enemy.global_position.x - start_x)
	)

	arena.dispose()
	await process_frame
## Stats de sessao: tempo, mortes, moedas e nota.
func _test_session_stats() -> void:
	_begin("SessionStats: estatisticas de tentativa")

	var s := SessionStats.new()
	s.start(&"level_01", 12)
	_check(s.level_id == &"level_01", "guarda o id da fase")
	_check(s.coins_total == 12, "guarda o total de moedas")

	s.record_death()
	s.record_death()
	_check_eq(s.deaths, 2, "conta mortes")

	s.record_coins(5)
	s.record_coins(3)
	_check_eq(s.coins_collected, 8, "acumula moedas")

	s.record_damage_dealt(10)
	s.record_damage_taken(4)
	_check_eq(s.damage_dealt, 10, "dano causado")
	_check_eq(s.damage_taken, 4, "dano recebido")

	# Nota C: derrota sem progresso.
	var sc := SessionStats.new()
	sc.start(&"level_01", 12)
	_check_eq(sc.grade(), "C", "derrota sem progresso = C")

	# Nota B: derrota com progresso.
	s.record_coins(1)
	_check_eq(s.grade(), "B", "derrota com progresso = B")

	# Vitoria com mortes = B.
	s.finish(true)
	_check_eq(s.grade(), "B", "vitoria com 2 mortes = B")

	# S: sem mortes, todas as moedas, dentro do par.
	var s2 := SessionStats.new()
	s2.start(&"level_01", 8)
	s2.record_coins(8)
	s2.finish(true)
	_check_eq(s2.grade(999.0), "S", "vitoria perfeita = S")

	# A: vitoria com 1 morte.
	var s3 := SessionStats.new()
	s3.start(&"level_01", 8)
	s3.record_death()
	s3.record_coins(8)
	s3.finish(true)
	_check_eq(s3.grade(999.0), "A", "vitoria com 1 morte = A")

	# coins_per_second nao divide por zero.
	var s4 := SessionStats.new()
	s4.start(&"x", 0)
	_check(s4.coins_per_second() >= 0.0, "coins_per_second nao quebra com tempo zero")

	# finish e idempotente.
	s2.finish(true)
	_check(s2.victory, "finish de novo nao desfaz a vitoria")


func _test_parry() -> void:
	_begin("Player: parry")

	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(true, SLIME_SCENE)
	await process_frame
	arena.enemy.global_position = Vector2(120, 0)
	arena.player.global_position = Vector2(0, 0)
	await process_frame

	arena.player.call(&"_try_parry")
	var health_before: int = int(_gs.get(&"health"))
	arena.player.call(&"apply_damage", 1, arena.enemy, Vector2.RIGHT, 100.0)
	_check_eq(int(_gs.get(&"health")), health_before, "parry anula o dano")

	arena.dispose()
	await process_frame


func _test_boss() -> void:
	_begin("Enemy: boss")

	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(true, BOSS_SCENE)
	await process_frame
	arena.enemy.global_position = Vector2(0, 0)
	arena.player.global_position = Vector2(200, 0)
	await process_frame

	var boss := arena.enemy
	var health_before: int = boss.health

	# O novo design e sempre hittable.
	boss.call(&"apply_damage", 5, arena.player, Vector2.LEFT, 0.0)
	_check(boss.health < health_before, "boss toma dano")

	# O boss cicla por estados (IDLE -> ATTACK -> VULNERABLE).
	var seen := {}
	for _i in 900:
		await physics_frame
		seen[boss.state_name()] = true
	_check(seen.has("IDLE"), "boss passa por IDLE")
	_check(seen.has("ATTACK"), "boss passa por ATTACK")
	_check(seen.has("VULNERABLE"), "boss passa por VULNERABLE")

	# Fases: com vida cheia e fase 1.
	var phase: int = boss.call(&"_get_phase")
	_check_eq(phase, 1, "fase 1 com vida cheia")

	# Reduzir vida para fase 2 e 3.
	boss.health = boss.max_health / 2
	_check_eq(boss.call(&"_get_phase"), 2, "fase 2 com metade da vida")
	boss.health = boss.max_health / 4
	_check_eq(boss.call(&"_get_phase"), 3, "fase 3 com um quarto da vida")

	arena.dispose()
	await process_frame
func _test_abilities() -> void:
	_begin("GameState: habilidades e niveis")

	_gs.call(&"reset_progress")
	_gs.call(&"reset")
	_check(not _gs.call(&"has_ability", &"double_jump"), "comeca sem habilidades")
	_check(_gs.call(&"unlock_ability", &"double_jump"), "desbloqueia habilidade nova")
	_check(_gs.call(&"has_ability", &"double_jump"), "has_ability apos desbloqueio")
	_check(not _gs.call(&"unlock_ability", &"double_jump"), "nao desbloqueia de novo")
	_check(not _gs.call(&"unlock_ability", &"inexistente"), "id inexistente nao desbloqueia")
	_check_eq(_gs.call(&"all_abilities").size(), 1, "uma habilidade desbloqueada")

	# level unlock
	_check(_gs.call(&"is_level_unlocked", &"level_01"), "level_01 sempre destravado")
	_check(not _gs.call(&"is_level_unlocked", &"level_02"), "level_02 bloqueado sem completar level_01")
	_gs.call(&"complete_level", &"level_01")
	_check(_gs.call(&"is_level_unlocked", &"level_02"), "level_02 destrava apos level_01")
	_check(not _gs.call(&"is_level_unlocked", &"level_03"), "level_03 ainda bloqueado")

	# save roundtrip
	var dict: Dictionary = _gs.call(&"to_dict")
	_gs.call(&"reset")
	_gs.call(&"from_dict", dict)
	_check(_gs.call(&"has_ability", &"double_jump"), "habilidade sobrevive ao save")
	_check(_gs.call(&"is_level_completed", &"level_01"), "nivel completo sobrevive ao save")


func _test_glide() -> void:
	_begin("Player: planagem")

	# Sem a habilidade, a queda nao e limitada.
	_gs.call(&"reset_progress")
	var arena := EnemyArena.new()
	root.add_child(arena)
	arena.build(true, SLIME_SCENE)
	await process_frame
	arena.player.global_position = Vector2(0, -300)
	arena.player.velocity = Vector2(0, 500)
	Input.action_press(&"jump")
	await physics_frame
	await physics_frame
	var fall_speed: float = arena.player.velocity.y
	_check(fall_speed > 500.0, "sem habilidade a queda acelera (%.0f px/s)" % fall_speed)

	# Com a habilidade, segurar o pulo limita a queda.
	_gs.call(&"unlock_ability", &"glide")
	arena.player.global_position = Vector2(0, -300)
	arena.player.velocity = Vector2(0, 500)
	await physics_frame
	await physics_frame
	var glide_speed: float = arena.player.velocity.y
	_check(glide_speed <= 150.0, "com habilidade a queda e limitada (%.0f px/s)" % glide_speed)

	Input.action_release(&"jump")
	arena.dispose()
	await process_frame
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

# ------------------------------------------------- onda 1: sensacao de jogo


## Alvo do dash, em px, bem acima do teto de antecipacao normal. Se a
## antecipacao aumentar durante o dash, ela precisa passar deste valor; senao o
## teste passaria sem provar nada.
const DASH_LOOK_FLOOR := 90.0


## A antecipacao da camera e leitura, nao regra -- mas o *valor* e regra.
## Um instantaneo de tela mostra se o bone esta no centro; nao mostra se a
## camera respondeu a velocidade. Aqui o componente e chamado direto com delta
## fixo e sem fisica: o que se prova e a resposta a velocidade, nao o
## movimento do player.
func _test_camera_look() -> void:
	_begin("Camera: antecipacao")

	var body := CharacterBody2D.new()
	root.add_child(body)
	var cam := CameraLook.new()
	cam.target_path = ^".."
	body.add_child(cam)
	await process_frame

	if cam == null:
		_check(false, "CameraLook instanciou")
		body.free()
		return
	_spawned.append(body)
	_check(cam.get_parent() == body, "CameraLook comeca apontado para o corpo")

	# Correndo para a direita na maxima: tem de saturar o teto.
	_drive_look(cam, body, PlayerTuning.SPEED, 120)
	_check(cam.look_offset() > 60.0, "antecipa para a direita correndo (%.1f px)" % cam.look_offset())
	_check(
		cam.look_offset() <= cam.look_ahead + 0.01,
		"nao passa do teto (%.1f px de %.1f)" % [cam.look_offset(), cam.look_ahead]
	)

	# Para a esquerda: mesmo tamanho, sinal invertido. Uma antecipacao que
	# so funciona num sentido vira um arrasto no outro.
	_drive_look(cam, body, -PlayerTuning.SPEED, 240)
	_check(cam.look_offset() < -60.0, "antecipa para a esquerda correndo (%.1f px)" % cam.look_offset())

	# Parado a camera volta ao centro. E o que impede ela de "descolar" depois
	# de cada corrida -- e e por isso que a volta e mais rapida que a ida.
	_drive_look(cam, body, 0.0, 240)
	_check(absf(cam.look_offset()) < 1.0, "volta ao centro ao parar (%.2f px)" % cam.look_offset())

	# Andando devagar antecipa pouco. Com antecipacao cheia, o bone some atras
	# da parede no fim de um corredor estreito -- que e a fase 2 inteira.
	_drive_look(cam, body, PlayerTuning.SPEED * 0.25, 240)
	_check(
		cam.look_offset() > 0.0 and cam.look_offset() < cam.look_ahead * 0.6,
		"antecipacao proporcional a velocidade (%.1f px de %.1f)" % [cam.look_offset(), cam.look_ahead]
	)

	# Desligar existe para comparar os dois lados na captura, nao por enfeite.
	cam.lookahead_enabled = false
	var parked := cam.look_offset()
	_drive_look(cam, body, PlayerTuning.SPEED, 90)
	_check_eq(cam.look_offset(), parked, "desligado nao move a camera")
	cam.lookahead_enabled = true

	await _test_camera_dash_boost()


## Durante o dash a antecipacao estica, porque o corpo some dentro do rastro e
## a camera precisa mostrar para onde ele vai.
##
## Usa o player de verdade porque `is_dashing()` faz parte do contrato: um
## bone generico nao responde, e um teste que so mede o componente nunca
## prova que o jogo inteiro estica junto.
func _test_camera_dash_boost() -> void:
	var packed := load(PLAYER_SCENE) as PackedScene
	_check(packed != null, "player.tscn carregou para o teste do dash")
	if packed == null:
		return

	var player := packed.instantiate() as CharacterBody2D
	root.add_child(player)
	_spawned.append(player)
	await process_frame

	var cam := player.get_node_or_null(^"Camera2D") as CameraLook
	if cam == null:
		_check(false, "player tem CameraLook no no Camera2D")
		return

	player._start_dash(Vector2.RIGHT)
	_check(player.is_dashing(), "dash comecou")
	if not player.is_dashing():
		return

	# Sem `await` dentro do laco: a fisica do player nao roda e o dash nao
	# expira no meio da medicao.
	for _i in 60:
		cam._process(1.0 / 60.0)

	_check(
		absf(cam.look_offset()) > DASH_LOOK_FLOOR,
		"dash estica a antecipacao (%.1f px, precisa passar de %.0f)" % [absf(cam.look_offset()), DASH_LOOK_FLOOR]
	)
	_check(
		absf(cam.look_offset()) <= cam.look_ahead * cam.dash_boost + 0.01,
		"dash nao passa do teto do boost (%.1f px de %.1f)" % [absf(cam.look_offset()), cam.look_ahead * cam.dash_boost]
	)


## Empurra o componente com velocidade constante. Sem `await` de proposito:
## qualquer quadro automatico aqui mostraria o resultado, e o teste
## viraria medida de ambiente em vez de medida da funcao.
func _drive_look(cam: CameraLook, body: CharacterBody2D, vx: float, frames: int) -> void:
	body.velocity = Vector2(vx, 0.0)
	for _i in frames:
		cam._process(1.0 / 60.0)


## O congelamento e o efeito mais barato que mais pesa no impacto -- e o
## unico item da onda que pode travar o jogo inteiro se der errado.
##
## Nenhum `await` aqui, de proposito: com `Engine.time_scale` em zero, um
## `await physics_frame` nao vence nunca e o runner trava para sempre. O
## ultimo bloco deste teste existe para garantir que o relogio volte.
func _test_hitstop() -> void:
	_begin("Hitstop: congelamento no impacto")

	var hitstop := root.get_node_or_null(^"Hitstop")
	_check(hitstop != null, "autoload Hitstop ausente")
	if hitstop == null:
		return

	hitstop.cancel()
	_check(not hitstop.is_running(), "comeca parado")
	_check_eq(Engine.time_scale, 1.0, "relogio normal antes de comecar")

	hitstop.trigger(2)
	_check(hitstop.is_running(), "trigger congela")
	_check(Engine.time_scale < 1.0, "relogio desacelera (%.2f)" % Engine.time_scale)
	_check(hitstop.remaining() > 0.0, "faltam quadros para voltar")

	# Encadear dois golpes no mesmo quadro. O mais fraco nao pode substituir
	# o mais forte: dois acertos juntos tem de soar como um, nao como o ultimo.
	hitstop.trigger(2, 0.06)
	var forte := Engine.time_scale
	hitstop.trigger(2, 0.9)
	_check_eq(Engine.time_scale, forte, "congelamento fraco nao substitui forte")

	# O contrario precisa funcionar: um golpe grande pesa mais que um pequeno
	# que veio antes, e nao menos.
	hitstop.trigger(6, 0.02)
	_check(Engine.time_scale < forte, "congelamento forte substitui fraco (%.3f)" % Engine.time_scale)

	# Teto absoluto. Sem isto, um par de codigos Asked com 999 quadros trava o
	# jogo em definitivo e o jogador so pode fechar o processo.
	hitstop.cancel()
	hitstop.trigger(999, 1.0)
	_check(
		hitstop.remaining() <= 0.121,
		"congelamento tem teto (%.3f s de 0.120 s)" % hitstop.remaining()
	)

	# Parametro invalido nao pode congelar nada.
	hitstop.cancel()
	hitstop.trigger(0)
	_check(not hitstop.is_running(), "trigger com 0 quadros nao congela")
	_check_eq(Engine.time_scale, 1.0, "relogio intacto apos trigger invalido")

	# Este bloco e o mais importante do arquivo inteiro: sem ele, um congelamento
	# esquecido contaminaria todas as suites seguintes, que rodariam em
	# camera lenta e continuariam dando "PASSARAM".
	hitstop.trigger(4)
	hitstop.cancel()
	_check(not hitstop.is_running(), "cancel encerra o congelamento")
	_check_eq(Engine.time_scale, 1.0, "cancel devolve o relogio")


## Os tres recados do golpe: numero flutuante, tremor que escala com o dano e
## hitstop que dura mais no golpe grande.
##
## O numero em si e leitura de tela. O que se prova aqui e a *ligacao*: que a
## posicao e de mundo, que a cor distingue quem levou o golpe, e que as duas
## intensidades sao derivadas do dano e nao constantes.
func _test_combat_feedback() -> void:
	_begin("Combate: numero, tremor e peso")

	var host := Node2D.new()
	root.add_child(host)
	_spawned.append(host)
	await process_frame

	# --- numero flutuante ---
	var number := FloatingNumber.spawn(host, Vector2(120, -45), 7, Color.RED)
	_check(number != null, "numero de dano criado")
	if number != null:
		# Sem espera antes: o numero ja comeca a subir no primeiro quadro, e
		# medir depois mediria o movimento, nao a origem. A posicao e conferida
		# no mesmo instante em que [method FloatingNumber.spawn] devolve.
		_check(
			number.global_position.distance_to(Vector2(120, -45)) < 0.01,
			"numero nasce no ponto do golpe, em coordenada de mundo"
		)

		# E a prova de que a subida e ancorada ali, e nao num canto qualquer da
		# tela: um tween montado antes da posicao estar definida sobe a partir
		# de (0,0), e o teste acima nao pegaria isso -- ele so veria a origem
		# certa se ela nao fosse sobrescrita um quadro depois.
		var nascimento := number.global_position.y
		await create_timer(0.2).timeout
		_check(
			number.global_position.y < nascimento - 5.0,
			"numero sobe a partir do ponto do golpe (%.0f -> %.0f)" % [nascimento, number.global_position.y]
		)

		var label := number.get_node_or_null(^"Label") as Label
		_check(label != null, "numero tem Label")
		if label != null:
			_check_eq(label.text, "7", "numero mostra o dano que foi dado")
			_check(
				label.get_theme_color(&"font_color") == Color.RED,
				"numero herda a cor de quem levou o golpe"
			)
			_check(
				label.get_theme_constant(&"outline_size") > 0,
				"numero tem contorno (cenario escuro engole o texto sem ele)"
			)

	# --- guarda do chamador nulo ---
	# Este caminho rodava em todo golpe de todo inimigo quando nao havia cena
	# corrente, e derrubava o jogo inteiro -- nao so o numero decorativo.
	_check(FloatingNumber.spawn(null, Vector2.ZERO, 1, Color.RED) == null, "numero com pai nulo nao quebra")

	# --- autoliberação ---
	# Sem isso uma briga longa acumula um no por golpe e a taxa de quadros
	# despenca sem ninguem saber de onde veio.
	var doomed := FloatingNumber.spawn(host, Vector2.ZERO, 1, Color.BLUE)
	_check(doomed != null, "numero de teste criado")
	await create_timer(1.2).timeout
	_check(not is_instance_valid(doomed), "numero se autolibera")

	# --- tremor escalado ---
	# Constante, o tremor mente sobre a diferenca entre tropecar e ser
	# arremessado. Nao da para ver isso num instantaneo de tela: so comparando.
	if _settings != null:
		_settings.shake_scale = 1.0
	var shake := CameraShake.new()
	host.add_child(shake)
	await process_frame

	shake.shake_for(1.0)
	var tremor_max := shake.strength()
	shake.stop()
	shake.shake_for(0.45)
	var tremor_fraco := shake.strength()
	_check(tremor_max > tremor_fraco, "golpe grande treme mais (%.2f > %.2f)" % [tremor_max, tremor_fraco])
	_check_eq(tremor_fraco, 0.45, "intensidade fraca aplicada como pedida")

	# Um tremor ja em curso nunca pode ser rebaixado por um golpe fraco: o
	# jogador sentiria a tela "pular" de menos para mais.
	shake.shake_for(1.0)
	shake.shake_for(0.2)
	_check_eq(shake.strength(), 1.0, "tremor fraco nao rebaixa tremor forte em curso")
	shake.stop()

	# --- hitstop ligado ao dano ---
	await _test_damage_scales_hitstop(host)


## O golpe no inimigo tem de congelar mais quanto maior o dano. Dois slimes
## porque o segundo golpe mata e `_die` libera o corpo -- o hitstop e pedido
## antes disso, e e exatamente a leitura que importa: o golpe que mata e o
## golpe que mais tem que pesar.
func _test_damage_scales_hitstop(host: Node) -> void:
	var hitstop := root.get_node_or_null(^"Hitstop")
	var packed := load(SLIME_SCENE) as PackedScene
	if hitstop == null or packed == null:
		_check(false, "hitstop e slime disponiveis para o teste de escala")
		return

	var weak := packed.instantiate()
	host.add_child(weak)
	var strong := packed.instantiate()
	host.add_child(strong)
	await process_frame

	hitstop.cancel()
	weak.call(&"apply_damage", 2, null, Vector2.RIGHT, 0.0)
	_check(hitstop.is_running(), "golpe no inimigo congela o relogio")
	var fraco: float = hitstop.remaining()
	hitstop.cancel()

	strong.call(&"apply_damage", 3, null, Vector2.RIGHT, 0.0)
	_check(hitstop.is_running(), "golpe que mata tambem congela")
	var forte: float = hitstop.remaining()
	hitstop.cancel()

	_check(
		forte > fraco,
		"dano maior congela mais tempo (%.3f s > %.3f s)" % [forte, fraco]
	)
	_check_eq(Engine.time_scale, 1.0, "relogio devolvido ao fim do teste de combate")


## Os quatro presets, mais a guarda de quem os chama.
##
## O que se verifica e configuracao, nao aparencia: aparencia e captura de
## tela. O que *dá* para provar em teste e que nenhum preset fica ligado sem
## querer, que nenhum deixa a particula sumir de um quadro para o outro, e
## que os presets nao quebram quem chama com pai invalido -- caminho que rodou
## em todo golpe de todo inimigo quando ainda nao havia cena corrente.
func _test_particle_presets() -> void:
	_begin("Particulas: presets")

	var dust := ParticlePreset.dust(CPUParticles2D.new())
	var splash := ParticlePreset.splash(CPUParticles2D.new())
	var trail := ParticlePreset.trail(CPUParticles2D.new())
	var burst := ParticlePreset.burst(CPUParticles2D.new(), Color.ORANGE)

	_check(not dust.emitting, "poeira nao emite sozinha (so quando o corpo corre)")
	_check(not dust.local_coords, "poeira fica no mundo em vez de andar com o corpo")
	_check(dust.amount > 0 and dust.lifetime > 0.0, "poeira tem quantidade e duracao")

	_check(splash.one_shot, "respingo e um disparo so")
	_check(splash.explosiveness >= 0.9, "respingo sai todo de uma vez")

	_check(trail.scale_amount_curve != null, "rastro encolhe ao longo da vida")
	if trail.scale_amount_curve != null:
		_check_eq(trail.scale_amount_curve.point_count, 3, "curva do rastro tem 3 pontos")
	_check(not trail.emitting, "rastro so emite durante o dash")

	_check(burst.one_shot, "estouro e um disparo so")
	_check(burst.spread >= 179.0, "estouro sai radial, nao para um lado")

	# Todo emissor precisa de rampa de alpha. Sem ela a particula salta de 100%
	# para 0% no ultimo quadro e pisca -- bem visivel numa captura pequena.
	var named := {"poeira": dust, "respingo": splash, "rastro": trail, "estouro": burst}
	for label: String in named:
		var node := named[label] as CPUParticles2D
		_check(node.color_ramp != null, "%s tem rampa de alpha" % label)
		_check(node.color.is_equal_approx(Color.WHITE), "%s deixa a cor para a rampa" % label)

	for label: String in named:
		(named[label] as CPUParticles2D).free()

	_check(
		ParticlePreset.spawn_burst(null, Vector2.ZERO, Color.RED) == null,
		"estouro com pai nulo nao quebra"
	)
	var host := Node2D.new()
	root.add_child(host)
	_spawned.append(host)
	await process_frame
	var live := ParticlePreset.spawn_burst(host, Vector2(50, 60), Color.RED, 6)
	_check(live != null, "estouro criado com pai valido")
	if live != null:
		_check(live.one_shot, "estouro criado ja e um disparo so")
		_check_eq(live.amount, 6, "estouro respeita a quantidade pedida")
		_check(live.global_position.distance_to(Vector2(50, 60)) < 0.01, "estouro nasce no ponto pedido")
	# Um no solto, nunca liberado, e a origem do aviso de "ObjectDB instances
	# leaked at exit" que ja existe no fim do runner.
	live.queue_free()
	await process_frame
