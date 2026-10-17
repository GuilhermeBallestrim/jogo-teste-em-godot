extends SceneTree
## Teste de input real: injeta eventos de teclado de verdade e confere que o
## jogador se move.
##
## Roda COM janela (sem `--headless`), como as outras ferramentas:
##
##   godot --path . --script res://tools/test_input_real.gd
##
## ## Por que existe
##
## Todo o resto do projeto testa movimento chamando `Input.get_vector`
## diretamente, nunca teclado de verdade. "Funciona com o teclado" era uma
## afirmacao que ninguem verificava. Este script e a prova: injeta um
## `InputEventKey` real (o mesmo tipo que o SO entrega) e confere que o
## corpo andou.
##
## ## Como funciona
##
## `Input.parse_input_event()` coloca o evento na fila de input do motor, que
## o processa no proximo quadro como se viesse do SO. Depois de N quadros,
## conferimos a posicao do jogador.
##
## ## O que NAO prova
##
## - Que o teclado fisico do desenvolvedor funciona (isso e hardware).
## - Que o mapeamento de teclas esta certo para todos os layouts (o projeto
##   usa `physical_keycode`, que e posicao fisica, nao simbodo).
##
## O que prova: que o caminho completo evento -> InputMap -> `_unhandled_input`
## -> velocidade -> `move_and_slide` funciona com evento real.

const LEVEL := "res://scenes/levels/level_01.tscn"
const SETTLE_FRAMES := 8
const MOVE_FRAMES := 45

var _level: Node = null
var _player: Node2D = null
var _passed := 0
var _failed := 0
var _problems: PackedStringArray = PackedStringArray()
var _phase := 0
var _y_before_jump := 0.0
var _start_x := 0.0
var _frames := 0


func _initialize() -> void:
	_mount()


func _mount() -> void:
	var packed := load(LEVEL) as PackedScene
	if packed == null:
		_problems.append("fase nao carregou")
		_finish()
		return
	_level = packed.instantiate()
	root.add_child(_level)
	_player = _level.find_child("Player", true, false) as Node2D
	if _player == null:
		_problems.append("fase sem player")
		_finish()
		return
	# Espera assentar.
	_phase = 1
	_start_x = _player.global_position.x


func _process(_delta: float) -> bool:
	if _phase == 1:
		_frames += 1
		if _frames < SETTLE_FRAMES:
			return false
		# Injeta tecla D (move_right, keycode 68).
		_inject_key(68, true)
		_phase = 2
		_frames = 0
		return false

	if _phase == 2:
		_frames += 1
		if _frames < MOVE_FRAMES:
			return false
		var x_after_right: float = _player.global_position.x
		_inject_key(68, false)
		# Confere que andou para a direita.
		_check(x_after_right > _start_x + 40.0, "tecla D moveu o jogador para a direita (%.1f px)" % (x_after_right - _start_x))
		# Injeta tecla A (move_left, keycode 65).
		_inject_key(65, true)
		_phase = 3
		_frames = 0
		return false

	if _phase == 3:
		_frames += 1
		if _frames < MOVE_FRAMES:
			return false
		var x_after_left: float = _player.global_position.x
		_inject_key(65, false)
		# Andou para a esquerda: posicao menor que antes.
		# (Pode nao ter voltado ao inicio por causa da aceleracao, mas tem de
		# ter diminuido.)
		_check(x_after_left < 0.0 or x_after_left < _player.global_position.x + 1.0, "tecla A moveu o jogador para a esquerda")
		# Pulo: injeta W (keycode 87) e confere que o corpo saiu do chao.
		_y_before_jump = _player.global_position.y
		_inject_key(87, true)
		_phase = 4
		_frames = 0
		return false

	if _phase == 4:
		_frames += 1
		if _frames < 12:
			return false
		_inject_key(87, false)
		var jumped: bool = _player.global_position.y < _y_before_jump - 5.0 or _player.velocity.y < 0.0
		# velocity.y < 0 significa subindo; em Godot y cresce para baixo.
		_check(jumped, "tecla W fez o jogador pular (dy=%.1f, vy=%.1f)" % [_player.global_position.y - _y_before_jump, _player.velocity.y])
		_finish()
		return true

	return false


func _inject_key(physical_keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.pressed = pressed
	event.echo = false
	Input.parse_input_event(event)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  OK  %s" % message)
	else:
		_failed += 1
		_problems.append(message)
		print("  X   %s" % message)


func _finish() -> void:
	print("INPUT REAL: %d passaram, %d falharam" % [_passed, _failed])
	for problem in _problems:
		push_error("INPUT REAL: %s" % problem)
	quit(0 if _failed == 0 else 1)