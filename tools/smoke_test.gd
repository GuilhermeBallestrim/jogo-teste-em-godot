extends SceneTree
## Verificacao rapida do projeto, pensada para rodar em CI:
##
##   godot --headless --path . --script res://tools/smoke_test.gd
##
## Sai com codigo 0 se estiver tudo verde, 1 se algo falhar.

const MAIN_SCENE := "res://scenes/main/main.tscn"

const REQUIRED_ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "dash", "interact", "attack", "pause", "restart",
]

const REQUIRED_AUTOLOADS: PackedStringArray = [
	"GameState", "Save", "Audio", "SceneRouter",
]

var _failures: PackedStringArray = []
var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run_checks()
	if _failures.is_empty():
		print("  OK  - %d acoes, %d autoloads, cena principal carregada." % [
			REQUIRED_ACTIONS.size(), REQUIRED_AUTOLOADS.size()
		])
		print("SMOKE TEST: PASSOU")
		return true

	for failure in _failures:
		printerr("  X   %s" % failure)
	print("SMOKE TEST: FALHOU (%d)" % _failures.size())
	quit(1)
	return true


func _run_checks() -> void:
	print("== Smoke test ==")
	_check_input_map()
	_check_autoloads()
	_check_main_scene()
	_check_game_state()
	_check_save_roundtrip()


## @return[StringName] o slot temporario usado no teste.
func _check_save_roundtrip() -> String:
	var save := root.get_node_or_null(^"Save")
	var game_state := root.get_node_or_null(^"GameState")
	if save == null or game_state == null:
		_fail("Save indisponivel para o teste de persistencia")
		return &""

	var slot := &"__smoke_test__"
	save.erase_save(slot)

	game_state.coins = 42
	game_state.score = 1337
	if not save.save_game(slot):
		_fail("Save.save_game retornou false")
		return slot

	game_state.coins = 0
	game_state.score = 0
	if not save.load_game(slot):
		_fail("Save.load_game retornou false")
		save.erase_save(slot)
		return slot

	if game_state.coins != 42 or game_state.score != 1337:
		_fail("Save nao restaurou o estado (%d moedas, %d pontos)" % [game_state.coins, game_state.score])

	save.erase_save(slot)
	if save.has_save(slot):
		_fail("Save.erase_save nao removeu o arquivo")

	game_state.reset()
	return slot


func _check_input_map() -> void:
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			_fail("acao ausente no Input Map: %s" % action)
		elif InputMap.action_get_events(action).is_empty():
			_fail("acao sem eventos: %s" % action)


func _check_autoloads() -> void:
	for singleton in REQUIRED_AUTOLOADS:
		if root.get_node_or_null(NodePath(singleton)) == null:
			_fail("autoload ausente: %s" % singleton)


func _check_main_scene() -> void:
	if not ResourceLoader.exists(MAIN_SCENE):
		_fail("cena principal nao existe: %s" % MAIN_SCENE)
		return
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("cena principal nao carrega: %s" % MAIN_SCENE)
		return
	if not packed.can_instantiate():
		_fail("cena principal nao pode ser instanciada: %s" % MAIN_SCENE)


func _check_game_state() -> void:
	var game_state := root.get_node_or_null(^"GameState")
	if game_state == null:
		return

	var saw_health_signal := [false]
	game_state.health_changed.connect(func(_c: int, _m: int) -> void: saw_health_signal[0] = true)

	game_state.take_damage(10)
	if not saw_health_signal[0]:
		_fail("GameState.take_damage nao emitiu health_changed")
	if game_state.health != 90:
		_fail("GameState.take_damage nao aplicou o dano (vida = %d)" % game_state.health)

	game_state.heal(999)
	if game_state.health != game_state.max_health:
		_fail("GameState.heal nao respeitou max_health")

	game_state.set_flag(&"test", true)
	if not game_state.get_flag(&"test", false):
		_fail("GameState flags nao persistem")

	game_state.reset()
	if game_state.health != game_state.max_health or game_state.coins != 0:
		_fail("GameState.reset nao restaurou o estado inicial")
	if game_state.get_flag(&"test", false):
		_fail("GameState.reset nao limpou as flags")


func _fail(message: String) -> void:
	_failures.append(message)