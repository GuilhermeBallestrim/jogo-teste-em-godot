extends SceneTree
## Captura de tela da interface, para conferir o que o jogador ve.
## Nao faz parte do jogo.
##
##   godot --path . --resolution 1280x720 --script res://tools/capture_ui.gd
##
## Roda COM janela (sem `--headless`): o renderizador headless e um dummio e
## a imagem sai vazia. O PNG tem uma verificação de conteúdo — uma imagem em
## branco "salva" sem erro nenhum, e um relatório de captura que mente e pior
## do que nenhum relatório.
##
## Uso para uma coisa: nenhum problema de layout ou de contraste se resolve
## lendo o código.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const OPTIONS_PANEL := "res://scenes/ui/options_panel.tscn"
const LEVEL := "res://scenes/levels/level_01.tscn"

const OUT_DIR := "user://capturas"
const SETTLE_FRAMES := 8
## A fase é a ultima do roteiro e roda o jogo de verdade por alguns segundos:
## 8 quadros não bastam para a câmera assentar, o bone cair no chão e os
## inimigos começarem a andar. Por isso ela fica fora do laço de 8 quadros.
const LEVEL_SETTLE_FRAMES := 150

var _frames := 0
var _shots: Array = []
var _index := 0
## Nome da imagem a salvar no próximo quadro. Vazio = nada pendente.
var _pending: StringName = &""
## A cena viva de cada tiro. Fica referenciada de proposito: se o unico forte
## dela for o `root`, o no e liberado no fim do quadro e o `get_texture()` vem
## com o que estava em cena antes — uma tela em branco que salva sem erro.
var _live: Array[Node] = []


func _initialize() -> void:
	# Uma cena por tiro. `04` foi deprecado: a fase só tem 66 cores distintas
	# numa imagem de 720p, porque o bone tem uns 30 px de altura — a 6x ele
	# seria verificado, mas a captura da fase inteira é a que serve para
	# conferir layout, bordas e contraste. Para o bone, use
	# `tools/capture_rig.gd`.
	_shots = [
		["01_menu", func() -> void: _instantiate(MAIN_MENU)],
		["02_opcoes_geral", func() -> void: _instantiate_options(0)],
		["03_opcoes_acessibilidade", func() -> void: _instantiate_options(1)],
		["04_opcoes_controles", func() -> void: _instantiate_options(2)],
		["05_fase", func() -> void: _instantiate(LEVEL)],
		["06_fase_texto_grande", func() -> void: _instantiate(LEVEL, 0.0, 1.5)],
		["07_fase_contraste", func() -> void: _instantiate(LEVEL, 0.0, 1.0, true)],
	]
	_problems.clear()


## @param ui_scale Escala de texto a aplicar depois de montar a cena.
## @param contrast Contraste alto ligado.
func _instantiate(
	path: String,
	rig_zoom: float = 0.0,
	ui_scale: float = 1.0,
	contrast: bool = false
) -> void:
	_clear()
	# Resetado a cada tiro: o anterior sujaria o seguinte, e uma captura que
	# mostra o efeito da preferencia precisa partir do estado neutro.
	_settings().call(&"set_ui_scale", ui_scale)
	_settings().call(&"set_high_contrast", contrast)
	_settings().call(&"reset_bindings")

	var packed := load(path) as PackedScene
	if packed == null:
		push_error("captura: cena nao carregou -> %s" % path)
		return
	var node := packed.instantiate()
	root.add_child(node)
	_live.append(node)

	# A escala e o contraste valem para a cena inteira, e nao so para a HUD: a
	# HUD e o que o jogador le, mas um efeito de apresentacao que so-afeta a
	# interface esconderia metade do que ele faz.
	if ui_scale != 1.0:
		Presentation.apply_ui_scale(node, ui_scale)
	if contrast:
		Presentation.set_contrast(node, true)
	if rig_zoom > 0.0:
		_zoom_player(rig_zoom)


## Abre o painel de opcoes numa aba especifica.
##
## As tres abas precisam de uma foto cada: um painel que abre na "Geral" e
## passa no teste de "carregou" pode ter a aba de acessibilidade inteira
## quebrada, e nenhuma verificacao estrutural veria isso.
func _instantiate_options(tab: int) -> void:
	_instantiate(OPTIONS_PANEL)
	var panel := _live[0] if not _live.is_empty() else null
	var tabs := panel.get_node_or_null(^"Center/Panel/Margin/Column/Tabs") as TabContainer
	if tabs != null:
		tabs.current_tab = tab
	# A foto seguinte precisa ver a aba ja trocada.
	_settle_bonus = 20


var _settle_bonus := 0


func _clear() -> void:
	_settle_bonus = 0
	for node in _live:
		if is_instance_valid(node):
			node.queue_free()
	_live.clear()
	_settings().call(&"set_ui_scale", 1.0)
	_settings().call(&"set_high_contrast", false)


## O autoload por nó, e não pelo identificador: este script é compilado antes
## dos autoloads existirem como identificador, e `Settings` direto dá
## "Identifier not found".
func _settings() -> Node:
	return root.get_node_or_null(^"Settings")


## Acha o jogador e amplia o bone. A câmera da fase está limitada e encolheria
## o bone de qualquer jeito; sem mexer na câmera, o zoom é só no rig.
func _zoom_player(amount: float) -> void:
	for node in root.get_tree().get_nodes_in_group(&"player"):
		var rig := (node as Node2D).get_node_or_null(^"Rig") as Node2D
		if rig == null:
			continue
		rig.set_meta(&"zoom_capture", amount)
		rig.scale = Vector2(amount, amount)
		var label := Label.new()
		label.text = "PlayerRig x%.0f" % amount
		label.position = Vector2(60, 40)
		label.add_theme_font_size_override(&"font_size", 22)
		# Fora do CanvasLayer da HUD, para nao ficar escondido atras.
		var layer := CanvasLayer.new()
		layer.layer = 90
		layer.add_child(label)
		root.add_child(layer)


## Cada tiro espera a cena assentar e então salva. O fluxo é: cria a cena,
## conta quadros, tira a foto. Instanciar e fotografar no mesmo passo produz
## uma imagem da cena anterior — foi o que aconteceu na primeira versão.
func _process(_delta: float) -> bool:
	# Primeiro: a foto que ficou pendente do quadro anterior.
	if _pending != &"":
		_save(_pending)
		_pending = &""
		_frames = 0
		return false

	# A condicao de "terminou" e `_saved < _shots.size()`, e nao
	# `_index >= size()`. O indice avanca no momento em que a cena e montada,
	# mas a imagem so existe depois de salva -- usar o indice aqui encerrava o
	# roteiro um quadro antes da ultima foto, sem erro nenhum.
	if _saved >= _shots.size():
		print("CAPTURA: %d imagem(ns) em %s" % [
			_saved,
			ProjectSettings.globalize_path(OUT_DIR),
		])
		for problem in _problems:
			push_error("CAPTURA: %s" % problem)
		return _problems.is_empty()

	if _frames == 0:
		var shot: Array = _shots[_index]
		_index += 1
		(shot[1] as Callable).call()
		# Conta o proprio quadro: sem isto `_frames` continua 0 e o `if` acima
		# remonta a mesma cena todo quadro, para sempre.
		_frames = 1
		return false

	_frames += 1
	# A fase precisa de muito mais quadros que um menu: a camera assenta, o
	# bone cai no chao e os inimigos comecam a andar.
	var needed: int = LEVEL_SETTLE_FRAMES if _index >= 5 else SETTLE_FRAMES
	if _frames < needed:
		return false

	_pending = StringName(String((_shots[_index - 1] as Array)[0]))
	return false


func _current_name() -> String:
	if _index <= 0:
		return ""
	return String((_shots[_index - 1] as Array)[0])


var _saved := 0
## Problemas detectados sem olhar a imagem. Uma captura que "funciona" e mostra
## uma tela vazia e o pior tipo de mentira, entao o proprio script diz quando
## alguma coisa nao inicializou.
var _problems: PackedStringArray = []


func _save(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var image := root.get_texture().get_image()
	if image == null:
		print("CAPTURA: sem imagem (rode SEM --headless)")
		return

	var path := "%s/%s.png" % [OUT_DIR, name]
	var err := image.save_png(path)
	if err != OK:
		print("CAPTURA: '%s' falhou (%d)" % [name, err])
		return

	# Contar cores distintas é a prova de que a imagem tem conteúdo. Uma tela
	# de menu preta "salva" sem reclamar, e só uma verificação assim conta.
	var distinct := {}
	for y in range(0, image.get_height(), 6):
		for x in range(0, image.get_width(), 6):
			distinct[image.get_pixel(x, y).to_rgba32()] = true
	_saved += 1
	var empty: bool = distinct.size() < 8
	if empty:
		_problems.append("%s saiu praticamente vazia (%d cores)" % [name, distinct.size()])
	print("  %s -> %d cores distintas%s" % [
		name, distinct.size(), "  <-- VAZIA" if empty else ""
	])